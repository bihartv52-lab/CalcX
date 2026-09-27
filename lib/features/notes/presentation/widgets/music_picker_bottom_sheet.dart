import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/features/notes/presentation/widgets/song_hook_trimmer_sheet.dart';
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
  String _selectedCategory = 'All';

  final List<Map<String, String>> _categories = [
    {'label': '🔥 All Trending', 'query': ''},
    {'label': '🇮🇳 Bollywood', 'query': 'Bollywood Hits Hindi'},
    {'label': '⚡ Punjabi', 'query': 'Punjabi Top Hits Karan Aujla Diljit'},
    {'label': '✨ Arijit Singh', 'query': 'Arijit Singh'},
    {'label': '👑 Diljit Dosanjh', 'query': 'Diljit Dosanjh'},
    {'label': '🎸 Karan Aujla', 'query': 'Karan Aujla'},
    {'label': '❤️ Romantic Lo-Fi', 'query': 'Hindi Romantic Lo-Fi'},
    {'label': '🎧 Honey Singh', 'query': 'Yo Yo Honey Singh'},
    {'label': '🌟 Shreya Ghoshal', 'query': 'Shreya Ghoshal'},
    {'label': '🔥 AP Dhillon', 'query': 'AP Dhillon'},
  ];

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

  void _onCategorySelected(String label, String query) {
    setState(() {
      _selectedCategory = label;
      _searchController.text = query.isEmpty ? '' : label.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    });

    if (query.isEmpty) {
      setState(() {
        _searchResults = RiTuneService.getTrendingHits();
        _isLoading = false;
      });
      return;
    }

    _performSearch(query);
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
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final results = await RiTuneService.search(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _onTrackSelected(RiTuneTrack track) async {
    // Open Hook Trimmer to allow user to trim snippet, chorus or full track
    final trimmedTrack = await SongHookTrimmerSheet.show(context, track);
    if (trimmedTrack != null && mounted) {
      ref.read(ritunePlaybackProvider.notifier).stop();
      Navigator.of(context).pop(trimmedTrack);
    }
  }

  void _onAttachFullSong(RiTuneTrack track) {
    ref.read(ritunePlaybackProvider.notifier).stop();
    // snippetDurationSeconds 0 represents full length song
    final fullTrack = track.copyWith(
      snippetStartSeconds: 0,
      snippetDurationSeconds: 0,
    );
    Navigator.of(context).pop(fullTrack);
  }

  Future<void> _pickLocalSong({bool trimHook = false}) async {
    final track = await RiTuneService.pickLocalSong();
    if (track != null && mounted) {
      if (trimHook) {
        final trimmedTrack = await SongHookTrimmerSheet.show(context, track);
        if (trimmedTrack != null && mounted) {
          ref.read(ritunePlaybackProvider.notifier).stop();
          Navigator.of(context).pop(trimmedTrack);
        } else if (mounted) {
          ref.read(ritunePlaybackProvider.notifier).stop();
          Navigator.of(context).pop(track.copyWith(snippetStartSeconds: 0, snippetDurationSeconds: 0));
        }
      } else {
        ref.read(ritunePlaybackProvider.notifier).stop();
        Navigator.of(context).pop(track.copyWith(snippetStartSeconds: 0, snippetDurationSeconds: 0));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(ritunePlaybackProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4AF37).withOpacity(0.35),
            width: 1.5,
          ),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 25, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.4),
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
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFE5C07B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.music_note_rounded, color: Colors.black87, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Music & Hook',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Row(
                        children: [
                          const Text(
                            'RiTune Classic Luxe',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: RiTuneService.launchRiTuneWeb,
                            child: const Text(
                              '• Web Player ↗',
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
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 3,
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(Icons.travel_explore_rounded, size: 18), text: 'Trending & Search'),
              Tab(icon: Icon(Icons.folder_open_rounded, size: 18), text: 'Device Audio'),
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
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search Bollywood, Punjabi, Arijit, Honey...',
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

                    // Quick Indian Music Chips
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final cat = _categories[idx];
                          final isSelected = _selectedCategory == cat['label'];
                          return ActionChip(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            label: Text(
                              cat['label']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? Colors.black
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                            backgroundColor: isSelected
                                ? const Color(0xFFD4AF37)
                                : (isDark ? const Color(0xFF1B2030) : const Color(0xFFEAEFF5)),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                            ),
                            onPressed: () => _onCategorySelected(cat['label']!, cat['query']!),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),

                    if (_isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                        ),
                      )
                    else if (_searchResults.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No songs found. Try another search or select a chip!'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = _searchResults[index];
                            final isPlaying =
                                playbackState.playingTrackId == track.id && playbackState.isPlaying;

                            return Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF171B26) : const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPlaying
                                      ? const Color(0xFFD4AF37)
                                      : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                                  width: isPlaying ? 1.5 : 1.0,
                                ),
                              ),
                              child: ListTile(
                                onTap: () => _onTrackSelected(track),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: track.artwork,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[850],
                                          child: const Icon(Icons.music_note_rounded, color: Color(0xFFD4AF37)),
                                        ),
                                      ),
                                    ),
                                    if (isPlaying)
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.equalizer_rounded, color: Color(0xFFD4AF37), size: 24),
                                      ),
                                  ],
                                ),
                                title: Text(
                                  track.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isPlaying ? const Color(0xFFD4AF37) : null,
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
                                      tooltip: isPlaying ? 'Pause preview' : 'Play preview',
                                      icon: Icon(
                                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                        color: const Color(0xFFD4AF37),
                                        size: 30,
                                      ),
                                      onPressed: () {
                                        ref.read(ritunePlaybackProvider.notifier).togglePlay(track);
                                      },
                                    ),
                                    // Quick Full Song option
                                    IconButton(
                                      tooltip: 'Attach Full Song (no trim)',
                                      icon: const Icon(
                                        Icons.all_inclusive_rounded,
                                        color: Color(0xFFE5C07B),
                                        size: 20,
                                      ),
                                      onPressed: () => _onAttachFullSong(track),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFD4AF37),
                                        foregroundColor: Colors.black87,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      icon: const Icon(Icons.content_cut_rounded, size: 13),
                                      label: const Text('Hook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () => _onTrackSelected(track),
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
                          color: const Color(0xFFD4AF37).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.audio_file_rounded,
                          size: 52,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Attach Song from Device',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Pick any MP3, M4A, or WAV file. You can attach the full length song or trim a 15-30s hook for your note!',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFD4AF37),
                                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                              label: const Text(
                                'Full Song',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: () => _pickLocalSong(trimHook: false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4AF37),
                                foregroundColor: Colors.black87,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.content_cut_rounded, size: 18),
                              label: const Text(
                                'Trim Hook',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              onPressed: () => _pickLocalSong(trimHook: true),
                            ),
                          ),
                        ],
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
