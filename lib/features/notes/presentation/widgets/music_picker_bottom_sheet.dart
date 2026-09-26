import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/features/notes/services/ritune_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MusicPickerBottomSheet extends ConsumerStatefulWidget {
  const MusicPickerBottomSheet({super.key});

  static Future<RiTuneTrack?> show(BuildContext context) {
    return showModalBottomSheet<RiTuneTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPickerBottomSheet(),
    );
  }

  @override
  ConsumerState<MusicPickerBottomSheet> createState() => _MusicPickerBottomSheetState();
}

class _MusicPickerBottomSheetState extends ConsumerState<MusicPickerBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<RiTuneTrack> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchResults = RiTuneService.getTrendingHits();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = RiTuneService.getTrendingHits();
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await RiTuneService.search(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _pickLocalSong() async {
    final track = await RiTuneService.pickLocalSong();
    if (track != null && mounted) {
      Navigator.of(context).pop(track);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(ritunePlaybackProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00FFCC), Color(0xFF00B0FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Music for Note',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          const Text(
                            'Powered by RiTune',
                            style: TextStyle(fontSize: 12, color: Color(0xFF00FFCC), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: RiTuneService.launchRiTuneWeb,
                            child: const Text(
                              '• Open Web Player ↗',
                              style: TextStyle(fontSize: 11, color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    ref.read(ritunePlaybackProvider.notifier).stop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          // Tabs: RiTune Catalog vs Local Storage
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF00FFCC),
            labelColor: const Color(0xFF00FFCC),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.travel_explore_rounded, size: 18), text: 'RiTune Hits & Search'),
              Tab(icon: Icon(Icons.folder_open_rounded, size: 18), text: 'Local Device Music'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: RiTune Catalog & Search
                Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search songs, artists, hits on RiTune...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    if (_isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
                        ),
                      )
                    else if (_searchResults.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No songs found. Try another search!'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final track = _searchResults[index];
                            final isPlaying = playbackState.playingTrackId == track.id && playbackState.isPlaying;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1E2B) : const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(12),
                                border: isPlaying
                                    ? Border.all(color: const Color(0xFF00FFCC), width: 1.5)
                                    : null,
                              ),
                              child: ListTile(
                                leading: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: track.artwork,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                    if (isPlaying)
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.equalizer_rounded, color: Color(0xFF00FFCC), size: 24),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isPlaying ? const Color(0xFF00FFCC) : null,
                                  ),
                                ),
                                subtitle: Text(
                                  track.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                        color: const Color(0xFF00FFCC),
                                        size: 32,
                                      ),
                                      onPressed: () {
                                        ref.read(ritunePlaybackProvider.notifier).togglePlay(track);
                                      },
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00FFCC),
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () {
                                        ref.read(ritunePlaybackProvider.notifier).stop();
                                        Navigator.of(context).pop(track);
                                      },
                                      child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),

                // Tab 2: Local Device Music
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFCC).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.audio_file_rounded,
                          size: 54,
                          color: Color(0xFF00FFCC),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Attach a Local Song from Device',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pick any MP3, M4A, WAV, or audio recording from your phone. Friends will hear your chosen track attached directly to your Note!',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.file_upload_rounded),
                        label: const Text(
                          'Choose Local Audio File',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _pickLocalSong,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
