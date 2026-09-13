import 'package:calcx/core/models/call.dart';

import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:calcx/features/calls/presentation/call_history_page.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calcx/core/services/supabase_service.dart';

class CallsPage extends ConsumerStatefulWidget {
  const CallsPage({super.key});

  @override
  ConsumerState<CallsPage> createState() => _CallsPageState();
}

class _CallsPageState extends ConsumerState<CallsPage> {
  late Future<List<Call>> _callHistoryFuture;

  @override
  void initState() {
    super.initState();
    _refreshCallHistory();
  }

  void _refreshCallHistory() {
    setState(() {
      _callHistoryFuture = ref.read(callRepositoryProvider).getCallHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final subColor = isLight ? Colors.black54 : Colors.white70;

    return RefreshIndicator(
      onRefresh: () async {
        _refreshCallHistory();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calls',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'LiveKit call history, missed calls, and quick actions.',
                      style: TextStyle(color: subColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Clear All Call History',
                icon: const Icon(Icons.delete_sweep_rounded),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear All Call History'),
                      content: const Text('Are you sure you want to delete all call logs? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear All', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(callRepositoryProvider).clearAllCallHistory();
                    _refreshCallHistory();
                  }
                },
              ),
              IconButton.filled(
                tooltip: 'Call History',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CallHistoryPage(),
                    ),
                  ).then((_) => _refreshCallHistory());
                },
                icon: const Icon(Icons.history),
              ),
            ],
          ),
          const SizedBox(height: 18),
          
          // Show real call history
          if (SupabaseService.clientOrNull == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Supabase not configured',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Realtime voice and video calling require a connected database.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            FutureBuilder<List<Call>>(
              future: _callHistoryFuture,
              builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final calls = snapshot.data ?? [];
              
              if (calls.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.call_end_rounded,
                          size: 64,
                           color: isLight ? Colors.black38 : Colors.white30,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No call history yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start calling your friends to see your call history here!',
                          style: TextStyle(
                             color: subColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Show real calls (limited to 5 recent)
              return Column(
                children: calls.take(5).map((call) {
                  final myId = ref.read(callRepositoryProvider).supabase?.auth.currentUser?.id;
                  final isOutgoing = call.callerId == myId;
                  final otherUser = isOutgoing ? call.receiverProfile : call.callerProfile;
                  final otherUserName = otherUser?['display_name'] ?? 'Unknown';
                  
                  String status;
                  if (call.isMissed) {
                    status = 'Missed';
                  } else if (call.isRejected) {
                    status = 'Declined';
                  } else if (call.isBusy) {
                    status = 'Busy';
                  } else if (call.duration != null) {
                    final minutes = call.duration! ~/ 60;
                    status = '${minutes}m';
                  } else {
                    status = call.status;
                  }

                  return Dismissible(
                    key: Key(call.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) async {
                      await ref.read(callRepositoryProvider).deleteCall(call.id);
                      _refreshCallHistory();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF1F1F4) : const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.light ? Colors.black12 : Colors.white10,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            call.isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherUserName,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '${call.callType} - $status',
                                  style: TextStyle(
                                    color: subColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Call',
                            onPressed: () async {
                              final activeSession = ref.read(activeCallSessionProvider);
                              if (activeSession != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You are already in an active call.')),
                                );
                                return;
                              }
                              try {
                                final newCall = await ref.read(callRepositoryProvider).initiateCall(
                                  receiverId: isOutgoing ? call.receiverId : call.callerId,
                                  callType: 'audio',
                                );
                                if (context.mounted) {
                                  ref.read(isCallScreenShowingProvider.notifier).state = true;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ActiveCallPage(call: newCall),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: const Text('Something went wrong. Please try again.')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.call_rounded),
                          ),
                          IconButton(
                            tooltip: 'Video',
                            onPressed: () async {
                              final activeSession = ref.read(activeCallSessionProvider);
                              if (activeSession != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('You are already in an active call.')),
                                );
                                return;
                              }
                              try {
                                final newCall = await ref.read(callRepositoryProvider).initiateCall(
                                  receiverId: isOutgoing ? call.receiverId : call.callerId,
                                  callType: 'video',
                                );
                                if (context.mounted) {
                                  ref.read(isCallScreenShowingProvider.notifier).state = true;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ActiveCallPage(call: newCall),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: const Text('Something went wrong. Please try again.')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.videocam_rounded),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                            onPressed: () async {
                              await ref.read(callRepositoryProvider).deleteCall(call.id);
                              _refreshCallHistory();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
