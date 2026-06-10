import 'package:calcx/core/models/call.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/presentation/incoming_call_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final callHistoryProvider = FutureProvider<List<Call>>((ref) async {
  final repository = ref.watch(callRepositoryProvider);
  return repository.getCallHistory();
});

class CallHistoryPage extends ConsumerWidget {
  const CallHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(callHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(callHistoryProvider);
        },
        child: historyAsync.when(
          data: (calls) {
            if (calls.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No call history',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final call = calls[index];
                return _CallHistoryTile(call: call);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading history: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(callHistoryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallHistoryTile extends ConsumerWidget {
  const _CallHistoryTile({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(callRepositoryProvider);
    final myId = repository.supabase?.auth.currentUser?.id;
    
    // Determine if I was the caller or receiver
    final isOutgoing = call.callerId == myId;
    final otherUser = isOutgoing ? call.receiverProfile : call.callerProfile;
    final otherUserName = otherUser?['display_name'] ?? 'Unknown';
    final otherUserAvatar = otherUser?['avatar_url'] as String?;

    // Call status icon and color
    IconData statusIcon;
    Color statusColor;
    
    if (call.isMissed) {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
      statusColor = Colors.red;
    } else if (call.isRejected) {
      statusIcon = Icons.call_end;
      statusColor = Colors.orange;
    } else if (call.isEnded) {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
      statusColor = Colors.green;
    } else {
      statusIcon = Icons.call;
      statusColor = Colors.grey;
    }

    return Dismissible(
      key: Key(call.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Call'),
            content: const Text('Remove this call from history?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await repository.deleteCall(call.id);
        ref.invalidate(callHistoryProvider);
      },
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundImage: otherUserAvatar != null
                  ? NetworkImage(otherUserAvatar)
                  : null,
              child: otherUserAvatar == null
                  ? Text(otherUserName[0].toUpperCase())
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  call.isVideo ? Icons.videocam : Icons.call,
                  size: 12,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        title: Text(otherUserName),
        subtitle: Row(
          children: [
            Icon(statusIcon, size: 16, color: statusColor),
            const SizedBox(width: 4),
            Text(
              _getCallStatusText(call, isOutgoing),
              style: TextStyle(color: statusColor),
            ),
            if (call.duration != null) ...[
              const Text(' • '),
              Text(_formatDuration(call.duration!)),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatTime(call.startedAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            IconButton(
              icon: Icon(
                call.isVideo ? Icons.videocam : Icons.call,
                color: Theme.of(context).primaryColor,
              ),
              onPressed: () async {
                // Initiate new call
                try {
                  final newCall = await repository.initiateCall(
                    receiverId: isOutgoing ? call.receiverId : call.callerId,
                    callType: call.callType,
                  );

                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IncomingCallPage(call: newCall),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error initiating call: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getCallStatusText(Call call, bool isOutgoing) {
    if (call.isMissed) {
      return isOutgoing ? 'No answer' : 'Missed';
    } else if (call.isRejected) {
      return 'Declined';
    } else if (call.isEnded) {
      return isOutgoing ? 'Outgoing' : 'Incoming';
    } else {
      return call.status;
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final secs = duration.inSeconds.remainder(60);
    return '${minutes}m ${secs}s';
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}
