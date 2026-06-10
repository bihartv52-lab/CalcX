import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';

class ScribbleGameWidget extends ConsumerStatefulWidget {
  const ScribbleGameWidget({
    super.key,
    required this.roomId,
    required this.session,
    required this.onExit,
  });

  final String roomId;
  final Map<String, dynamic> session;
  final VoidCallback onExit;

  @override
  ConsumerState<ScribbleGameWidget> createState() => _ScribbleGameWidgetState();
}

class _ScribbleGameWidgetState extends ConsumerState<ScribbleGameWidget> {
  // Dictionary word pool
  static const List<String> wordPool = [
    'APPLE', 'BANANA', 'HOUSE', 'CHAIR', 'TABLE', 'FLOWER', 'SUNGLASSES', 'AIRPLANE',
    'TRAIN', 'ROCKET', 'PIZZA', 'GUITAR', 'FOOTBALL', 'CAT', 'DOG', 'MONSTER',
    'SPIDER', 'COWBOY', 'PIRATE', 'CASTLE', 'ROBOT', 'DRAGON', 'SNOWMAN', 'ICECREAM',
    'BIRTHDAY', 'PENCIL', 'HAMBURGER', 'RAINBOW', 'BUTTERFLY', 'BREAD', 'CLOCK',
    'MONKEY', 'OCTOPUS', 'HELICOPTER', 'TELEPHONE', 'COMPUTER', 'CAMERA', 'CUPCAKE',
  ];

  // Local drawing states
  List<_ScribbleStroke> _drawingStrokes = [];
  List<Offset> _currentPoints = [];
  Color _selectedColor = Colors.white;
  double _selectedWidth = 4.0;
  bool _isEraserSelected = false;

  // Timers and controllers
  Timer? _gameTimer;
  final _guessController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _chatSubscription;

  @override
  void initState() {
    super.initState();
    _listenToRoomChat();
    _startMasterTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ScribbleGameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync strokes locally when stream updates
    final state = widget.session['game_state'] as Map<String, dynamic>? ?? {};
    final strokesRaw = state['strokes'] as List<dynamic>? ?? [];
    _drawingStrokes = strokesRaw.map((s) => _ScribbleStroke.fromMap(s as Map<String, dynamic>)).toList();
    _startMasterTimerIfNeeded();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _chatSubscription?.cancel();
    _guessController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Parse state details
  Map<String, dynamic> get gameState => widget.session['game_state'] as Map<String, dynamic>? ?? {};
  List<dynamic> get players => gameState['players'] as List<dynamic>? ?? [];
  String get drawerId => gameState['drawer_id'] as String? ?? '';
  String get targetWord => gameState['target_word'] as String? ?? '';
  List<dynamic> get wordOptions => gameState['word_options'] as List<dynamic>? ?? [];
  List<dynamic> get guessedCorrectly => gameState['guessed_correctly'] as List<dynamic>? ?? [];
  Map<String, dynamic> get scores => gameState['scores'] as Map<String, dynamic>? ?? {};
  int get timerSeconds => gameState['timer_seconds'] as int? ?? 60;
  String get gameStatus => gameState['game_status'] as String? ?? 'lobby'; // 'lobby', 'word_select', 'drawing', 'ended'
  int get round => gameState['round'] as int? ?? 1;
  int get wager => gameState['wager'] as int? ?? 10;

  // DB Sync
  Future<void> _updateGameState(Map<String, dynamic> newState) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    try {
      await client
          .from('game_sessions')
          .update({'game_state': newState})
          .eq('id', widget.session['id']);
    } catch (e) {
      debugPrint('Error updating Scribble state: $e');
    }
  }

  // Deduct/Reward credits
  Future<bool> _placeBet(String userId, int amount) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return false;
    try {
      return await client.rpc('place_bet', params: {
        'player_id': userId,
        'bet_amount': amount,
      }) as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _rewardWinner(String winnerId, int amount) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    try {
      await client.rpc('reward_winner', params: {
        'player_id': winnerId,
        'reward_amount': amount,
        'game_name': 'Scribble Real-Time',
      });
      await client
          .from('game_sessions')
          .update({'status': 'finished', 'winner_id': winnerId})
          .eq('id', widget.session['id']);
    } catch (_) {}
  }

  // Lobby actions
  Future<void> _joinLobby() async {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id;
    if (myId == null) return;

    if (players.contains(myId)) return;
    if (players.length >= 6) return;

    final updatedPlayers = List<String>.from(players)..add(myId);
    final newState = Map<String, dynamic>.from(gameState)..['players'] = updatedPlayers;
    await _updateGameState(newState);
  }

  Future<void> _startGame() async {
    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players to start!')),
      );
      return;
    }

    // Deduct stakes
    for (final uid in players) {
      final ok = await _placeBet(uid, wager);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User $uid does not have enough credits!')),
        );
        return;
      }
    }

    // Pick drawer and word options
    final initialScores = {for (var uid in players) uid: 0};
    _startRound(1, players.first as String, initialScores);
  }

  void _startRound(int roundNum, String nextDrawerId, Map<String, int> currentScores) {
    // Pick 3 random words
    final rand = Random();
    final options = <String>[];
    while (options.length < 3) {
      final w = wordPool[rand.nextInt(wordPool.length)];
      if (!options.contains(w)) options.add(w);
    }

    final roundState = {
      'players': players,
      'drawer_id': nextDrawerId,
      'target_word': '',
      'word_options': options,
      'guessed_correctly': [],
      'scores': currentScores,
      'timer_seconds': 45,
      'game_status': 'word_select',
      'round': roundNum,
      'strokes': [],
      'wager': wager,
    };

    _updateGameState(roundState);
  }

  // Select Word (Drawer only)
  Future<void> _selectWord(String word) async {
    final newState = Map<String, dynamic>.from(gameState)
      ..['target_word'] = word
      ..['game_status'] = 'drawing'
      ..['timer_seconds'] = 60;
    await _updateGameState(newState);
  }

  // Master Timer: Run exclusively on the Drawer client to sync clock tick updates
  void _startMasterTimerIfNeeded() {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id;
    if (myId == null || myId != drawerId || gameStatus == 'lobby' || gameStatus == 'ended') {
      _gameTimer?.cancel();
      _gameTimer = null;
      return;
    }

    if (_gameTimer != null) return;

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerSeconds <= 0) {
        _endTurn();
      } else {
        final newState = Map<String, dynamic>.from(gameState)..['timer_seconds'] = timerSeconds - 1;
        _updateGameState(newState);
      }
    });
  }

  // Check correct guesses in room chat messages
  void _listenToRoomChat() {
    _chatSubscription = ref.read(chatRepositoryProvider).watchRoomMessages(widget.roomId).listen((messages) {
      final client = SupabaseService.clientOrNull;
      final myId = client?.auth.currentUser?.id;
      if (myId == null || gameStatus != 'drawing' || myId == drawerId) return;

      if (messages.isEmpty) return;
      final latest = messages.last;

      // Ensure we only parse fresh messages from other players
      if (latest.senderId == myId && 
          latest.content.toUpperCase().trim() == targetWord && 
          !guessedCorrectly.contains(myId)) {
        _submitCorrectGuess(myId);
      }
    });
  }

  // Submit guess locally via widget text input
  void _submitLocalGuess() {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id;
    if (myId == null || gameStatus != 'drawing' || myId == drawerId) return;

    final val = _guessController.text.toUpperCase().trim();
    _guessController.clear();
    
    if (val == targetWord && !guessedCorrectly.contains(myId)) {
      _submitCorrectGuess(myId);
    } else {
      // Send regular chat message
      ref.read(chatRepositoryProvider).sendMessage(
        receiverId: null,
        content: val.toLowerCase(),
        roomId: widget.roomId,
      );
    }
  }

  // Award points on correct guess
  Future<void> _submitCorrectGuess(String userId) async {
    final updatedWinners = List<String>.from(guessedCorrectly)..add(userId);
    
    // Calculate dynamic scores: faster guesses get more points (Max 100, Min 30)
    final pointsEarned = max(30, 100 - (guessedCorrectly.length * 15));
    final updatedScores = Map<String, int>.from(scores);
    updatedScores[userId] = (updatedScores[userId] ?? 0) + pointsEarned;
    
    // Drawer gets a bonus for hosting a successfully guessed word
    updatedScores[drawerId] = (updatedScores[drawerId] ?? 0) + 15;

    final newState = Map<String, dynamic>.from(gameState)
      ..['guessed_correctly'] = updatedWinners
      ..['scores'] = updatedScores;

    await _updateGameState(newState);

    // Send a system message to hide the word in the chat log
    await ref.read(chatRepositoryProvider).sendMessage(
      receiverId: null,
      content: 'Guessed the word! 🎉',
      roomId: widget.roomId,
    );

    // If everyone guessed, end the turn early
    final guessersCount = players.length - 1;
    if (updatedWinners.length >= guessersCount) {
      _endTurn();
    }
  }

  // End active drawing turn and rotate round / end game
  Future<void> _endTurn() async {
    _gameTimer?.cancel();
    _gameTimer = null;

    final currentScores = Map<String, int>.from(scores);
    final currentDrawerIdx = players.indexOf(drawerId);
    final nextDrawerIdx = currentDrawerIdx + 1;

    if (nextDrawerIdx < players.length) {
      // Next player in this round draws
      _startRound(round, players[nextDrawerIdx] as String, currentScores);
    } else if (round < 3) {
      // Advance to next round (play up to 3 rounds)
      _startRound(round + 1, players.first as String, currentScores);
    } else {
      // End game and reward player with highest score
      String? topPlayerId;
      int maxScore = -1;
      currentScores.forEach((uid, val) {
        if (val > maxScore) {
          maxScore = val;
          topPlayerId = uid;
        }
      });

      if (topPlayerId != null) {
        final pot = wager * players.length;
        final commission = (pot * 0.05).round();
        final finalPayout = pot - commission;
        
        await _rewardWinner(topPlayerId!, finalPayout);
        
        final newState = Map<String, dynamic>.from(gameState)
          ..['game_status'] = 'ended'
          ..['winner_id'] = topPlayerId;
        await _updateGameState(newState);
      }
    }
  }

  // Generate obfuscated hint (e.g., Apple -> A _ _ _ E)
  String _getObfuscatedWord() {
    if (targetWord.isEmpty) return '';
    final buffer = StringBuffer();
    for (int i = 0; i < targetWord.length; i++) {
      if (i == 0 || i == targetWord.length - 1) {
        buffer.write('${targetWord[i]} ');
      } else {
        buffer.write('_ ');
      }
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id ?? '';
    final isMyTurn = myId == drawerId;

    if (gameStatus == 'lobby') {
      return _buildLobbyScreen(myId);
    }
    if (gameStatus == 'ended') {
      return _buildEndScreen(myId);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header Stats panel
          _buildHeaderPanel(isMyTurn),
          const SizedBox(height: 10),
          
          // Main drawing canvas
          Expanded(
            child: Row(
              children: [
                // Scoreboard list
                _buildScoreboard(myId),
                const SizedBox(width: 10),
                
                // Canvas board
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: gameStatus == 'word_select'
                        ? _buildWordSelectArea(isMyTurn)
                        : _buildCanvasArea(isMyTurn),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Guess field / Controls
          if (gameStatus == 'drawing') _buildControlsFooter(myId, isMyTurn),
        ],
      ),
    );
  }

  Widget _buildHeaderPanel(bool isMyTurn) {
    final hint = isMyTurn ? targetWord : _getObfuscatedWord();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filled(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onExit,
            tooltip: 'Exit Game',
            style: IconButton.styleFrom(backgroundColor: Colors.white10),
          ),
          Column(
            children: [
              Text(
                gameStatus == 'word_select' ? 'Selecting Word...' : hint,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
              ),
              Text(
                isMyTurn ? 'YOU are drawing' : 'Guess the word!',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          // Timer circle
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: timerSeconds < 10 ? Colors.redAccent : Colors.indigoAccent, width: 2),
            ),
            child: Text(
              timerSeconds.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: timerSeconds < 10 ? Colors.redAccent : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard(String myId) {
    return Container(
      width: 96,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemCount: players.length,
        itemBuilder: (context, idx) {
          final uid = players[idx] as String;
          final score = scores[uid] as int? ?? 0;
          final isPlayerDrawer = uid == drawerId;
          final didGuess = guessedCorrectly.contains(uid);

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isPlayerDrawer
                  ? Colors.indigoAccent.withOpacity(0.2)
                  : didGuess
                      ? Colors.greenAccent.withOpacity(0.12)
                      : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPlayerDrawer
                    ? Colors.indigoAccent
                    : didGuess
                        ? Colors.greenAccent
                        : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uid == myId ? 'You' : 'Player ${idx + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$score pts',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordSelectArea(bool isMyTurn) {
    if (isMyTurn) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Choose a word to draw:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: wordOptions.map((word) {
                return ElevatedButton(
                  onPressed: () => _selectWord(word as String),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(word as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF1E1E1E),
      child: const Center(
        child: Text(
          'Waiting for drawer to select a word...',
          style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  Widget _buildCanvasArea(bool isMyTurn) {
    final canvasBg = const Color(0xFF1E1E1E);
    final currentColor = _isEraserSelected ? canvasBg : _selectedColor;

    return Stack(
      children: [
        GestureDetector(
          onPanStart: isMyTurn
              ? (details) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final localPoint = renderBox.globalToLocal(details.globalPosition);
                  setState(() {
                    _currentPoints = [localPoint];
                  });
                }
              : null,
          onPanUpdate: isMyTurn
              ? (details) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final localPoint = renderBox.globalToLocal(details.globalPosition);
                  setState(() {
                    _currentPoints.add(localPoint);
                  });
                }
              : null,
          onPanEnd: isMyTurn
              ? (details) {
                  if (_currentPoints.isNotEmpty) {
                    final newStroke = _ScribbleStroke(
                      points: List<Offset>.from(_currentPoints),
                      color: currentColor,
                      width: _selectedWidth,
                    );
                    final updatedStrokes = List<_ScribbleStroke>.from(_drawingStrokes)..add(newStroke);
                    
                    final newState = Map<String, dynamic>.from(gameState)
                      ..['strokes'] = updatedStrokes.map((s) => s.toMap()).toList();

                    _updateGameState(newState);
                    
                    setState(() {
                      _drawingStrokes = updatedStrokes;
                      _currentPoints = [];
                    });
                  }
                }
              : null,
          child: Container(
            color: canvasBg,
            width: double.infinity,
            height: double.infinity,
            child: CustomPaint(
              painter: _ScribblePainter(
                completedStrokes: _drawingStrokes,
                currentPoints: _currentPoints,
                currentColor: currentColor,
                currentWidth: _selectedWidth,
              ),
            ),
          ),
        ),
        
        // Drawing tools overlay (Drawer only)
        if (isMyTurn)
          Positioned(
            left: 10,
            bottom: 10,
            child: _buildDrawingToolbar(),
          ),
      ],
    );
  }

  Widget _buildDrawingToolbar() {
    final colors = [Colors.white, Colors.redAccent, Colors.yellowAccent, Colors.greenAccent, Colors.blueAccent, Colors.purpleAccent];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit, color: !_isEraserSelected ? Colors.indigoAccent : Colors.white60, size: 18),
            onPressed: () => setState(() => _isEraserSelected = false),
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services, color: _isEraserSelected ? Colors.indigoAccent : Colors.white60, size: 18),
            onPressed: () => setState(() => _isEraserSelected = true),
          ),
          const SizedBox(width: 8),
          ...colors.map((c) => GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: _selectedColor == c && !_isEraserSelected ? Colors.white : Colors.transparent, width: 1.5),
                  ),
                ),
              )),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
            onPressed: () {
              final newState = Map<String, dynamic>.from(gameState)..['strokes'] = [];
              _updateGameState(newState);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlsFooter(String myId, bool isMyTurn) {
    final didGuess = guessedCorrectly.contains(myId);

    if (isMyTurn) {
      return Container(
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: const Text('Draw the word clearly so others can guess it!', style: TextStyle(color: Colors.white70, fontSize: 13)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _guessController,
              enabled: !didGuess,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: didGuess ? 'Guessed correctly! Waiting for round end...' : 'Type your guess here...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _submitLocalGuess(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.check),
            onPressed: didGuess ? null : _submitLocalGuess,
            style: IconButton.styleFrom(backgroundColor: Colors.greenAccent, disabledBackgroundColor: Colors.white12),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyScreen(String myId) {
    final hostId = widget.session['host_id'] as String? ?? '';
    final isHost = myId == hostId;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.brush, size: 64, color: Colors.amberAccent),
                const SizedBox(height: 16),
                const Text('Scribble Game Lobby', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 8),
                Text('Required Wager: $wager Credits', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 24),
                
                const Text('Joined Players:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: players.length,
                  itemBuilder: (context, idx) {
                    final uid = players[idx] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.amberAccent),
                          const SizedBox(width: 12),
                          Text(uid == myId ? 'You' : 'Player ${idx + 1}'),
                          const Spacer(),
                          if (uid == hostId) const Text('HOST', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                if (!players.contains(myId) && players.length < 6)
                  FilledButton(onPressed: _joinLobby, child: const Text('Join Lobby'))
                else if (isHost)
                  FilledButton(onPressed: players.length >= 2 ? _startGame : null, child: const Text('Start Game'))
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndScreen(String myId) {
    final winId = gameState['winner_id'] as String? ?? '';
    final isWinnerMe = myId == winId;
    return Center(
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 72, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text('Game Finished! 🏁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              const SizedBox(height: 12),
              Text(
                isWinnerMe ? 'You won the pot! 🎉' : 'Player Won!',
                style: const TextStyle(fontSize: 18, color: Colors.greenAccent),
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: widget.onExit, child: const Text('Return to Lobby')),
            ],
          ),
        ),
      ),
    );
  }
}

// Drawing Stroke representation for Scribble database sync
class _ScribbleStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _ScribbleStroke({required this.points, required this.color, required this.width});

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => [p.dx, p.dy]).toList(),
      'color': color.value,
      'width': width,
    };
  }

  factory _ScribbleStroke.fromMap(Map<String, dynamic> map) {
    final pointsList = map['points'] as List<dynamic>? ?? [];
    final pts = pointsList.map((p) {
      final list = p as List<dynamic>;
      return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
    }).toList();
    return _ScribbleStroke(
      points: pts,
      color: Color(map['color'] as int? ?? Colors.white.value),
      width: (map['width'] as num? ?? 4.0).toDouble(),
    );
  }
}

// Drawing painter for Scribble game board
class _ScribblePainter extends CustomPainter {
  final List<_ScribbleStroke> completedStrokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  _ScribblePainter({
    required this.completedStrokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in completedStrokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.isEmpty) continue;
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentPoints.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentPoints.first.dx, currentPoints.first.dy);
      for (var i = 1; i < currentPoints.length; i++) {
        path.lineTo(currentPoints[i].dx, currentPoints[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScribblePainter oldDelegate) {
    return oldDelegate.completedStrokes != completedStrokes || oldDelegate.currentPoints != currentPoints;
  }
}
