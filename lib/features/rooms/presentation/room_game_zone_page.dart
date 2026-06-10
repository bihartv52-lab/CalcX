import 'dart:async';
import 'dart:math';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/rooms/presentation/widgets/room_chat_sidebar.dart';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:calcx/features/rooms/presentation/widgets/ludo_game_widget.dart';
import 'package:calcx/features/rooms/presentation/widgets/scribble_game_widget.dart';

class RoomGameZonePage extends ConsumerStatefulWidget {
  const RoomGameZonePage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  ConsumerState<RoomGameZonePage> createState() => _RoomGameZonePageState();
}

class _RoomGameZonePageState extends ConsumerState<RoomGameZonePage> {
  String _sidePanelType = 'none'; // 'none', 'chat', 'vc', 'call', 'moderation'
  String? _activeGameType; // null, 'xo', 'ludo', 'skribbl'
  Map<String, dynamic>? _activeSession;
  StreamSubscription? _sessionSubscription;

  // Web controllers
  InAppWebViewController? _webViewController;
  final _lobbyUrlController = TextEditingController();

  // Tic-Tac-Toe state
  List<String> _xoBoard = List.filled(9, '');
  String _xoTurn = '';
  String _xoPlayerX = '';
  String _xoPlayerO = '';
  String _xoWinner = '';

  // Drawing Canvas State
  List<_DrawingStroke> _drawingStrokes = [];
  Color _selectedColor = Colors.white;
  double _selectedWidth = 4.0;
  List<Offset> _currentPoints = [];
  bool _isEraserSelected = false;

  Timer? _drawMasterTimer;

  static const List<String> _drawWords = [
    'CAT', 'DOG', 'LION', 'ELEPHANT', 'MONKEY', 'GIRAFFE', 'PIRATE', 'CASTLE',
    'ROBOT', 'DRAGON', 'SNOWMAN', 'ICECREAM', 'SPIDER', 'BUTTERFLY', 'HOUSE',
    'TREE', 'CAR', 'AIRPLANE', 'ROCKET', 'GUITAR', 'PIZZA', 'APPLE', 'BANANA',
    'SUNGLASSES', 'HAMBURGER', 'RAINBOW', 'CLOCK', 'OCTOPUS', 'HELICOPTER',
    'TELEPHONE', 'COMPUTER', 'CAMERA', 'CUPCAKE', 'FISH', 'PENGUIN', 'TURTLE'
  ];

  Map<String, dynamic> get _drawGameState => _activeSession?['game_state'] as Map<String, dynamic>? ?? {};
  List<dynamic> get _drawPlayers => _drawGameState['players'] as List<dynamic>? ?? [];
  String get _drawCanvasMode => _drawGameState['canvas_mode'] as String? ?? 'one_board';
  String get _drawGameStatus => _drawGameState['game_status'] as String? ?? 'playing';
  String get _drawTargetWord => _drawGameState['target_word'] as String? ?? '';
  int get _drawTimerSeconds => _drawGameState['timer_seconds'] as int? ?? 60;
  String get _drawCurrentTurn => _drawGameState['current_turn'] as String? ?? '';
  Map<String, dynamic> get _drawDrawings => _drawGameState['drawings'] as Map<String, dynamic>? ?? {};
  int get _drawCurrentRatingIndex => _drawGameState['current_rating_index'] as int? ?? 0;
  Map<String, dynamic> get _drawRatings => _drawGameState['ratings'] as Map<String, dynamic>? ?? {};

  @override
  void initState() {
    super.initState();
    _subscribeToGameSession();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _drawMasterTimer?.cancel();
    _lobbyUrlController.dispose();
    super.dispose();
  }

  void _subscribeToGameSession() {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;

    // Listen to game_sessions for this room
    _sessionSubscription = client
        .from('game_sessions')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .map((sessions) => sessions.where((s) => s['status'] == 'active').toList())
        .listen((sessions) {
      if (sessions.isEmpty) {
        if (mounted) {
          setState(() {
            _activeSession = null;
            _activeGameType = null;
            _xoBoard = List.filled(9, '');
            _xoWinner = '';
            _xoPlayerX = '';
            _xoPlayerO = '';
          });
          _drawMasterTimer?.cancel();
          _drawMasterTimer = null;
        }
        return;
      }

      final session = sessions.first;
      final gameType = session['game_type'] as String;
      final state = session['game_state'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          _activeSession = session;
          _activeGameType = gameType;

          if (gameType == 'xo') {
            final boardRaw = state['board'] as List<dynamic>?;
            _xoBoard = boardRaw?.map((e) => e.toString()).toList() ?? List.filled(9, '');
            _xoTurn = state['turn'] as String? ?? '';
            _xoPlayerX = state['playerX'] as String? ?? '';
            _xoPlayerO = state['playerO'] as String? ?? '';
            _xoWinner = state['winner'] as String? ?? '';
          } else if (gameType == 'ludo' || gameType == 'skribbl') {
            final lobbyUrl = state['lobbyUrl'] as String?;
            if (lobbyUrl != null && lobbyUrl.isNotEmpty && lobbyUrl != _lobbyUrlController.text) {
              _lobbyUrlController.text = lobbyUrl;
              _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(lobbyUrl)));
            }
          } else if (gameType == 'draw') {
            final mode = state['canvas_mode'] as String? ?? 'one_board';
            final status = state['game_status'] as String? ?? 'playing';
            
            if (mode == 'competition') {
              if (status == 'rating') {
                final players = state['players'] as List? ?? [];
                final ratingIdx = state['current_rating_index'] as int? ?? 0;
                final ratedPlayerId = ratingIdx < players.length ? players[ratingIdx] as String? : null;
                if (ratedPlayerId != null) {
                  final drawingsMap = state['drawings'] as Map? ?? {};
                  final strokesRaw = drawingsMap[ratedPlayerId] as List? ?? [];
                  _drawingStrokes = strokesRaw
                      .map((s) => _DrawingStroke.fromMap(s as Map<String, dynamic>))
                      .toList();
                } else {
                  _drawingStrokes = [];
                }
              } else if (status == 'drawing') {
                if (_currentPoints.isEmpty) {
                  final myId = client.auth.currentUser?.id;
                  final drawingsMap = state['drawings'] as Map? ?? {};
                  final strokesRaw = drawingsMap[myId] as List? ?? [];
                  _drawingStrokes = strokesRaw
                      .map((s) => _DrawingStroke.fromMap(s as Map<String, dynamic>))
                      .toList();
                }
              } else {
                _drawingStrokes = [];
              }
            } else {
              final strokesRaw = state['strokes'] as List<dynamic>? ?? [];
              _drawingStrokes = strokesRaw
                  .map((s) => _DrawingStroke.fromMap(s as Map<String, dynamic>))
                  .toList();
            }
          }
        });

        if (gameType == 'draw') {
          _startDrawMasterTimerIfNeeded();
        } else {
          _drawMasterTimer?.cancel();
          _drawMasterTimer = null;
        }
      }
    });
  }

  Future<int?> _showWagerDialog() async {
    int selectedWager = 10;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Set Entry Wager', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose the entry wager (credits) that each player must pay to join.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: [10, 20, 50, 100, 200].map((amount) {
                    return ChoiceChip(
                      label: Text('$amount Credits'),
                      selected: selectedWager == amount,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            selectedWager = amount;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(selectedWager),
                child: const Text('Confirm', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<String?> _showDrawModeDialog() async {
    String selectedMode = 'one_board';
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text('Select Drawing Mode', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('One Board Mode', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Everyone draws simultaneously on a shared canvas.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  value: 'one_board',
                  groupValue: selectedMode,
                  onChanged: (val) => setState(() => selectedMode = val!),
                ),
                RadioListTile<String>(
                  title: const Text('Competition Mode', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Draw a random thing/animal privately under a timer, then rate each other\'s drawings!', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  value: 'competition',
                  groupValue: selectedMode,
                  onChanged: (val) => setState(() => selectedMode = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(selectedMode),
                child: const Text('Confirm', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _startDrawMasterTimerIfNeeded() {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id;
    final hostId = _activeSession?['host_id'] as String? ?? '';
    final gameType = _activeSession?['game_type'] as String?;

    if (myId == null || myId != hostId || gameType != 'draw' || _drawCanvasMode != 'competition' || _drawGameStatus == 'lobby' || _drawGameStatus == 'ended') {
      _drawMasterTimer?.cancel();
      _drawMasterTimer = null;
      return;
    }

    if (_drawMasterTimer != null) return;

    _drawMasterTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_drawTimerSeconds <= 0) {
        await _advanceDrawGamePhase();
      } else {
        final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
        state['timer_seconds'] = _drawTimerSeconds - 1;
        await _updateGameState(state);
      }
    });
  }

  Future<void> _advanceDrawGamePhase() async {
    if (_activeSession == null) return;
    final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
    final players = List<String>.from(state['players'] as List? ?? []);
    if (players.isEmpty) return;

    final currentStatus = state['game_status'] as String? ?? 'lobby';

    if (currentStatus == 'drawing') {
      state['game_status'] = 'rating';
      state['current_rating_index'] = 0;
      state['timer_seconds'] = 15;
      
      final ratingsMap = <String, Map<String, dynamic>>{};
      for (final uid in players) {
        ratingsMap[uid] = <String, dynamic>{};
      }
      state['ratings'] = ratingsMap;
      
      await _updateGameState(state);
    } else if (currentStatus == 'rating') {
      final currentRatingIdx = state['current_rating_index'] as int? ?? 0;
      if (currentRatingIdx < players.length - 1) {
        state['current_rating_index'] = currentRatingIdx + 1;
        state['timer_seconds'] = 15;
        await _updateGameState(state);
      } else {
        // Calculate winner
        final ratings = state['ratings'] as Map? ?? {};
        final scoresMap = <String, double>{};
        
        for (final uid in players) {
          final playerRatings = (ratings[uid] as Map?) ?? {};
          double sum = 0.0;
          int count = 0;
          playerRatings.forEach((voterId, val) {
            sum += (val as num).toDouble();
            count++;
          });
          scoresMap[uid] = count > 0 ? sum / count : 0.0;
        }

        String? winnerId;
        double maxScore = -1.0;
        scoresMap.forEach((uid, score) {
          if (score > maxScore) {
            maxScore = score;
            winnerId = uid;
          }
        });

        state['game_status'] = 'ended';
        state['winner_id'] = winnerId;
        state['scores'] = scoresMap;
        
        await _updateGameState(state);

        // Award reward to winner
        if (winnerId != null) {
          final wager = state['wager'] as int? ?? 10;
          final pot = wager * players.length;
          final commission = (pot * 0.05).round();
          final finalPayout = pot - commission;
          await _rewardWinner(winnerId!, finalPayout);
        }
      }
    }
  }

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
    if (client == null || _activeSession == null) return;
    try {
      await client.rpc('reward_winner', params: {
        'player_id': winnerId,
        'reward_amount': amount,
        'game_name': 'Drawing Canvas',
      });
      await client
          .from('game_sessions')
          .update({'status': 'finished', 'winner_id': winnerId})
          .eq('id', _activeSession!['id']);
    } catch (_) {}
  }

  Future<void> _joinDrawLobby() async {
    final client = SupabaseService.clientOrNull;
    if (client == null || _activeSession == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null) return;

    final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
    final players = List<String>.from(state['players'] as List? ?? []);

    if (players.contains(myId)) return;
    players.add(myId);

    state['players'] = players;
    await _updateGameState(state);
  }

  Future<void> _startDrawGame() async {
    final client = SupabaseService.clientOrNull;
    if (client == null || _activeSession == null) return;

    final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
    final players = List<String>.from(state['players'] as List? ?? []);

    if (players.isEmpty) return;

    final wager = state['wager'] as int? ?? 10;
    
    // Deduct wager from each player
    for (final uid in players) {
      final ok = await _placeBet(uid, wager);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('A player does not have enough credits to join!')),
          );
        }
        return;
      }
    }

    // Select random word
    final rand = Random();
    final targetWord = _drawWords[rand.nextInt(_drawWords.length)];

    state['game_status'] = 'drawing';
    state['target_word'] = targetWord;
    state['timer_seconds'] = 60;
    state['drawings'] = {for (var uid in players) uid: []};
    state['ratings'] = {for (var uid in players) uid: {}};
    state['scores'] = {for (var uid in players) uid: 0.0};

    await _updateGameState(state);
  }

  Future<void> _startNewGame(String gameType) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null) return;

    int wagerAmount = 10;
    if (gameType == 'ludo' || gameType == 'skribbl') {
      final selectedWager = await _showWagerDialog();
      if (selectedWager == null) return; // Host cancelled
      wagerAmount = selectedWager;
    }

    // Close any previous active game sessions first
    try {
      await client
          .from('game_sessions')
          .update({'status': 'finished'})
          .eq('room_id', widget.roomId)
          .eq('status', 'active');
    } catch (_) {}

    Map<String, dynamic> initialState = {};
    if (gameType == 'xo') {
      initialState = {
        'board': List.filled(9, ''),
        'turn': myId,
        'playerX': myId,
        'playerO': '',
        'winner': '',
      };
    } else if (gameType == 'skribbl') {
      initialState = {
        'players': [myId],
        'drawer_id': '',
        'target_word': '',
        'word_options': [],
        'guessed_correctly': [],
        'scores': {},
        'timer_seconds': 45,
        'game_status': 'lobby',
        'round': 1,
        'strokes': [],
        'wager': wagerAmount,
      };
    } else if (gameType == 'ludo') {
      initialState = {
        'players': [myId],
        'token_positions': {myId: [-1, -1, -1, -1]},
        'current_turn': '',
        'dice_value': 0,
        'has_rolled': false,
        'game_status': 'lobby',
        'winner_id': '',
        'wager': wagerAmount,
      };
    } else if (gameType == 'draw') {
      final selectedMode = await _showDrawModeDialog();
      if (selectedMode == null) return; // Host cancelled

      int wagerAmount = 10;
      if (selectedMode == 'competition') {
        final selectedWager = await _showWagerDialog();
        if (selectedWager == null) return; // Host cancelled
        wagerAmount = selectedWager;
      }

      initialState = {
        'strokes': [],
        'canvas_mode': selectedMode,
        'players': [myId],
        'current_turn': myId,
        'game_status': selectedMode == 'competition' ? 'lobby' : 'playing',
        'wager': wagerAmount,
        'timer_seconds': 60,
        'drawings': {},
        'ratings': {},
        'scores': {},
      };
    }

    try {
      await client.from('game_sessions').insert({
        'room_id': widget.roomId,
        'game_type': gameType,
        'game_state': initialState,
        'status': 'active',
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start game: $e')),
        );
      }
    }
  }

  Future<void> _updateGameState(Map<String, dynamic> newState) async {
    final client = SupabaseService.clientOrNull;
    if (client == null || _activeSession == null) return;

    try {
      await client
          .from('game_sessions')
          .update({'game_state': newState})
          .eq('id', _activeSession!['id']);
    } catch (e) {
      debugPrint('Error updating game state: $e');
    }
  }

  Future<void> _exitGame() async {
    final client = SupabaseService.clientOrNull;
    if (client == null || _activeSession == null) return;

    try {
      await client
          .from('game_sessions')
          .update({'status': 'finished'})
          .eq('id', _activeSession!['id']);
    } catch (e) {
      debugPrint('Error exiting game: $e');
    }
  }

  // Tic-Tac-Toe Move
  void _makeXOMove(int index) {
    final client = SupabaseService.clientOrNull;
    if (client == null || _activeSession == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null) return;

    // Check if it's my turn
    if (_xoTurn != myId) return;
    if (_xoBoard[index].isNotEmpty) return;
    if (_xoWinner.isNotEmpty) return;

    final mySymbol = (myId == _xoPlayerX) ? 'X' : 'O';
    final newBoard = List<String>.from(_xoBoard);
    newBoard[index] = mySymbol;

    // Determine next turn & check winner
    final nextTurn = (myId == _xoPlayerX) ? _xoPlayerO : _xoPlayerX;
    final winner = _checkXOWinner(newBoard);

    final newState = {
      'board': newBoard,
      'turn': (winner.isNotEmpty) ? '' : nextTurn,
      'playerX': _xoPlayerX,
      'playerO': _xoPlayerO,
      'winner': winner,
    };

    _updateGameState(newState);
  }

  String _checkXOWinner(List<String> board) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
      [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
      [0, 4, 8], [2, 4, 6]             // diagonals
    ];

    for (final line in lines) {
      if (board[line[0]].isNotEmpty &&
          board[line[0]] == board[line[1]] &&
          board[line[0]] == board[line[2]]) {
        return board[line[0]];
      }
    }

    if (board.every((cell) => cell.isNotEmpty)) {
      return 'draw';
    }

    return '';
  }

  void _joinAsPlayerO() {
    final client = SupabaseService.clientOrNull;
    if (client == null || _activeSession == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null) return;

    if (_xoPlayerO.isNotEmpty) return;

    final newState = {
      'board': _xoBoard,
      'turn': _xoTurn.isEmpty ? _xoPlayerX : _xoTurn,
      'playerX': _xoPlayerX,
      'playerO': myId,
      'winner': _xoWinner,
    };

    _updateGameState(newState);
  }

  // Web Lobby Sync
  void _syncWebLobby() {
    final lobbyUrl = _lobbyUrlController.text.trim();
    if (lobbyUrl.isEmpty) return;

    final newState = {
      'lobbyUrl': lobbyUrl,
    };
    _updateGameState(newState);
  }

  Widget _buildGameArea() {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id ?? '';

    if (_activeGameType == null) {
      return _buildGameSelectionMenu();
    }

    switch (_activeGameType) {
      case 'xo':
        return _buildXOBoard();
      case 'draw':
        if (_activeSession != null) {
          if (_drawCanvasMode == 'competition' && _drawGameStatus == 'lobby') {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF131313),
                  child: Row(
                    children: [
                      IconButton.filled(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: _exitGame,
                        tooltip: 'Exit Game',
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Drawing Canvas 🎨',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildDrawLobbyScreen(myId)),
              ],
            );
          }
          return _buildDrawingBoard();
        }
        return const Center(child: CircularProgressIndicator());
      case 'skribbl':
        if (_activeSession != null) {
          return ScribbleGameWidget(
            roomId: widget.roomId,
            session: _activeSession!,
            onExit: _exitGame,
          );
        }
        return const Center(child: CircularProgressIndicator());
      case 'ludo':
        if (_activeSession != null) {
          return LudoGameWidget(
            roomId: widget.roomId,
            session: _activeSession!,
            onExit: _exitGame,
          );
        }
        return const Center(child: CircularProgressIndicator());
      default:
        return const Center(child: Text('Unknown Game Type'));
    }
  }

  Widget _buildGameSelectionMenu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Text(
            'Welcome to the Game Zone 🎮',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Play native multiplayer games or jump into private web lobbies with your friends!',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 700 ? 2 : 1;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.25,
                ),
                children: [
                  _GameCard(
                    title: 'Tic-Tac-Toe (XO)',
                    subtitle: 'Native Real-Time Sync',
                    icon: Icons.grid_3x3_rounded,
                    color: Colors.purpleAccent,
                    onTap: () => _startNewGame('xo'),
                  ),
                  _GameCard(
                    title: 'Drawing Canvas',
                    subtitle: 'Real-Time Shared Board',
                    icon: Icons.palette_rounded,
                    color: Colors.pinkAccent,
                    onTap: () => _startNewGame('draw'),
                  ),
                  _GameCard(
                    title: 'Skribbl.io',
                    subtitle: 'Synced Drawing & Guessing',
                    icon: Icons.brush_rounded,
                    color: Colors.orangeAccent,
                    onTap: () => _startNewGame('skribbl'),
                  ),
                  _GameCard(
                    title: 'Ludo Multiplayer',
                    subtitle: 'Synced Board Game Lobbies',
                    icon: Icons.casino_rounded,
                    color: Colors.greenAccent,
                    onTap: () => _startNewGame('ludo'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildXOBoard() {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id;
    final isPlayerX = myId == _xoPlayerX;
    final isPlayerO = myId == _xoPlayerO;
    final isPlayer = isPlayerX || isPlayerO;
    final isMyTurn = _xoTurn == myId && _xoTurn.isNotEmpty;

    String statusText = '';
    if (_xoWinner.isNotEmpty) {
      if (_xoWinner == 'draw') {
        statusText = 'It\'s a Draw! 🤝';
      } else {
        statusText = 'Player $_xoWinner Wins! 🎉';
      }
    } else if (_xoPlayerO.isEmpty) {
      statusText = 'Waiting for Player O to join...';
    } else {
      statusText = isMyTurn ? 'Your Turn!' : 'Waiting for opponent...';
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _exitGame,
                tooltip: 'Exit Game',
              ),
              Text(
                'Tic-Tac-Toe (XO)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton.filled(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _startNewGame('xo'),
                tooltip: 'Restart Game',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isMyTurn ? Theme.of(context).colorScheme.primary : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Player info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Chip(
                avatar: const Icon(Icons.person, size: 16, color: Colors.purpleAccent),
                label: Text(isPlayerX ? 'You (Player X)' : 'Player X', style: const TextStyle(fontSize: 12)),
              ),
              Chip(
                avatar: const Icon(Icons.person, size: 16, color: Colors.greenAccent),
                label: Text(
                  _xoPlayerO.isEmpty
                      ? 'No opponent'
                      : (isPlayerO ? 'You (Player O)' : 'Player O'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Grid
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, index) {
                    final val = _xoBoard[index];
                    return GestureDetector(
                      onTap: () => _makeXOMove(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: val == 'X'
                                ? Colors.purpleAccent.withOpacity(0.4)
                                : val == 'O'
                                    ? Colors.greenAccent.withOpacity(0.4)
                                    : Colors.white10,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            val,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: val == 'X' ? Colors.purpleAccent : Colors.greenAccent,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (!isPlayer && _xoPlayerO.isEmpty && _xoWinner.isEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _joinAsPlayerO,
              icon: const Icon(Icons.sports_esports_rounded),
              label: const Text('Join as Player O'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWebGameFrame() {

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton.filled(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _exitGame,
                tooltip: 'Exit Game',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lobbyUrlController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Game Lobby URL...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _syncWebLobby,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Sync Link', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_lobbyUrlController.text.isNotEmpty
                ? _lobbyUrlController.text
                : (_activeGameType == 'ludo'
                    ? 'https://www.gamezop.com/g/SkhljT2fdgb'
                    : 'https://skribbl.io/'))),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              allowsInlineMediaPlayback: true,
              useHybridComposition: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              mediaPlaybackRequiresUserGesture: false,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              if (url != null) {
                final urlStr = url.toString();
                if (urlStr.contains('?room=') || 
                    urlStr.contains('&room=') || 
                    urlStr.contains('skribbl.io/?') ||
                    urlStr.contains('gamezop.com/')) {
                  if (urlStr != _lobbyUrlController.text) {
                    _lobbyUrlController.text = urlStr;
                    _syncWebLobby();
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final showSidebar = _sidePanelType != 'none';
    final sidebarWidth = screenWidth > 760 ? 300.0 : screenWidth * 0.45;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            // Left main game area
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildGameArea()),
                  // Game controls / side panel selector at the bottom
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black87,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.roomName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        // Side panel options selector
                        Container(
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                          child: IconButton(
                            icon: Icon(
                              _sidePanelType == 'chat'
                                  ? Icons.chat_bubble_rounded
                                  : _sidePanelType == 'vc'
                                      ? Icons.videocam_rounded
                                      : _sidePanelType == 'call'
                                          ? Icons.call_rounded
                                          : _sidePanelType == 'moderation'
                                              ? Icons.people_rounded
                                              : Icons.view_sidebar_rounded,
                              color: _sidePanelType == 'none' ? Colors.white : Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              showMenu(
                                context: context,
                                position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width, 56, 0, 0),
                                items: [
                                  const PopupMenuItem(value: 'none', child: Text('No Side Panel')),
                                  const PopupMenuItem(value: 'chat', child: Text('Chat Sidebar')),
                                  const PopupMenuItem(value: 'vc', child: Text('Video Call Sidebar')),
                                  const PopupMenuItem(value: 'call', child: Text('Voice Call Sidebar')),
                                  const PopupMenuItem(value: 'moderation', child: Text('Participants & Moderation')),
                                ],
                              ).then((value) {
                                if (value != null) {
                                  setState(() {
                                    _sidePanelType = value;
                                  });
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right sidebar
            if (showSidebar)
              Container(
                width: sidebarWidth,
                color: const Color(0xFF131313),
                child: RoomSideChatPanel(
                  roomId: widget.roomId,
                  roomName: widget.roomName,
                  roomType: 'game',
                  sidePanelType: _sidePanelType,
                  onPanelTypeChanged: (newType) {
                    setState(() {
                      _sidePanelType = newType;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
  Widget _buildDrawingBoard() {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id ?? '';

    if (_drawGameStatus == 'ended') {
      return _buildDrawEndedScreen(myId);
    }

    final colors = [
      Colors.white,
      Colors.grey,
      Colors.redAccent,
      Colors.pinkAccent,
      Colors.orangeAccent,
      Colors.yellowAccent,
      Colors.greenAccent,
      Colors.tealAccent,
      Colors.cyanAccent,
      Colors.blueAccent,
      Colors.indigoAccent,
      Colors.purpleAccent,
      Colors.deepOrangeAccent,
      Colors.amberAccent,
    ];

    final strokeWidths = [2.0, 4.0, 8.0, 12.0, 18.0, 24.0, 32.0];
    final canvasBg = const Color(0xFF1E1E1E);
    final currentColor = _isEraserSelected ? canvasBg : _selectedColor;

    final isDrawingAllowed = (_drawCanvasMode == 'one_board') || 
                             (_drawCanvasMode == 'competition' && _drawGameStatus == 'drawing');

    return Column(
      children: [
        // Title bar with exit, undo, and clear buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF131313),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _exitGame,
                tooltip: 'Exit Game',
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    _drawCanvasMode == 'competition'
                        ? (_drawGameStatus == 'drawing'
                            ? 'Draw: $_drawTargetWord'
                            : 'Rating Drawings')
                        : 'Drawing Canvas 🎨',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_drawCanvasMode == 'one_board')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: _drawingStrokes.isEmpty ? null : () {
                        final updatedStrokes = List<_DrawingStroke>.from(_drawingStrokes)..removeLast();
                        final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
                        state['strokes'] = updatedStrokes.map((s) => s.toMap()).toList();
                        setState(() {
                          _drawingStrokes = updatedStrokes;
                        });
                        _updateGameState(state);
                      },
                      tooltip: 'Undo',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        disabledBackgroundColor: Colors.blueAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.delete_sweep_rounded),
                      onPressed: () {
                        final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
                        state['strokes'] = [];
                        setState(() {
                          _drawingStrokes = [];
                        });
                        _updateGameState(state);
                      },
                      tooltip: 'Clear Canvas',
                      style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
                    ),
                  ],
                )
              else if (_drawGameStatus == 'drawing')
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: _drawingStrokes.isEmpty ? null : () {
                        final updatedStrokes = List<_DrawingStroke>.from(_drawingStrokes)..removeLast();
                        final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
                        final drawingsMap = Map<String, dynamic>.from(state['drawings'] as Map? ?? {});
                        drawingsMap[myId] = updatedStrokes.map((s) => s.toMap()).toList();
                        state['drawings'] = drawingsMap;
                        setState(() {
                          _drawingStrokes = updatedStrokes;
                        });
                        _updateGameState(state);
                      },
                      tooltip: 'Undo Last Stroke',
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.pinkAccent, width: 1),
                      ),
                      child: Text(
                        '⌛ $_drawTimerSeconds s',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pinkAccent, fontSize: 13),
                      ),
                    ),
                  ],
                )
              else if (_drawGameStatus == 'rating')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent, width: 1),
                  ),
                  child: Text(
                    '⌛ $_drawTimerSeconds s',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        
        // Canvas area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: isDrawingAllowed
                    ? (details) {
                        final renderBox = context.findRenderObject() as RenderBox;
                        final localPoint = renderBox.globalToLocal(details.globalPosition);
                        setState(() {
                          _currentPoints = [localPoint];
                        });
                      }
                    : null,
                onPanUpdate: isDrawingAllowed
                    ? (details) {
                        final renderBox = context.findRenderObject() as RenderBox;
                        final localPoint = renderBox.globalToLocal(details.globalPosition);
                        
                        // Clamp points to stay within the canvas bounds
                        if (localPoint.dx >= 0 && 
                            localPoint.dx <= constraints.maxWidth && 
                            localPoint.dy >= 0 && 
                            localPoint.dy <= constraints.maxHeight) {
                          setState(() {
                            _currentPoints.add(localPoint);
                          });
                        }
                      }
                    : null,
                onPanEnd: isDrawingAllowed
                    ? (details) {
                        if (_currentPoints.isNotEmpty) {
                          final newStroke = _DrawingStroke(
                            points: List<Offset>.from(_currentPoints),
                            color: currentColor,
                            width: _selectedWidth,
                          );

                          final updatedStrokes = List<_DrawingStroke>.from(_drawingStrokes)..add(newStroke);
                          
                          setState(() {
                            _drawingStrokes = updatedStrokes;
                            _currentPoints = [];
                          });

                          // Push updated strokes to database
                          final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
                          if (_drawCanvasMode == 'competition') {
                            final drawingsMap = Map<String, dynamic>.from(state['drawings'] as Map? ?? {});
                            drawingsMap[myId] = updatedStrokes.map((s) => s.toMap()).toList();
                            state['drawings'] = drawingsMap;
                          } else {
                            state['strokes'] = updatedStrokes.map((s) => s.toMap()).toList();
                          }

                          _updateGameState(state);
                        }
                      }
                    : null,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: canvasBg,
                  child: CustomPaint(
                    painter: _DrawingPainter(
                      completedStrokes: _drawingStrokes,
                      currentPoints: _currentPoints,
                      currentColor: currentColor,
                      currentWidth: _selectedWidth,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Toolbar: Mode, Colors, Stroke widths
        if (_drawCanvasMode == 'one_board' || _drawGameStatus == 'drawing')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF131313),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Tool Mode Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                      label: const Text('Pen', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      selected: !_isEraserSelected,
                      selectedColor: Colors.blueAccent,
                      backgroundColor: Colors.grey[900],
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isEraserSelected = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      avatar: const Icon(Icons.cleaning_services_rounded, size: 16, color: Colors.white),
                      label: const Text('Eraser', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      selected: _isEraserSelected,
                      selectedColor: Colors.blueAccent,
                      backgroundColor: Colors.grey[900],
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _isEraserSelected = true;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Colors Row (Disabled / faded when Eraser is selected)
                Opacity(
                  opacity: _isEraserSelected ? 0.4 : 1.0,
                  child: IgnorePointer(
                    ignoring: _isEraserSelected,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: colors.map((color) {
                          final isSelected = _selectedColor == color && !_isEraserSelected;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : Colors.white24,
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // 3. Stroke Width Presets Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Size:  ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: strokeWidths.map((width) {
                          final isSelected = _selectedWidth == width;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedWidth = width;
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blueAccent : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Container(
                                  width: width.clamp(2.0, 18.0),
                                  height: width.clamp(2.0, 18.0),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else if (_drawGameStatus == 'rating')
          _buildRatingToolbar(myId),
      ],
    );
  }

  Widget _buildRatingToolbar(String myId) {
    final ratedPlayerId = _drawPlayers[_drawCurrentRatingIndex] as String;
    final isOwnDrawing = ratedPlayerId == myId;
    final currentRatings = _drawRatings[ratedPlayerId] as Map? ?? {};
    final existingRating = currentRatings[myId] as int?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: const Color(0xFF131313),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOwnDrawing 
                ? 'Showing your drawing of $_drawTargetWord'
                : 'Rate Player ${_drawCurrentRatingIndex + 1}\'s drawing of $_drawTargetWord:',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (isOwnDrawing)
            const Text(
              'Waiting for other players to rate your masterpiece...',
              style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
            )
          else if (existingRating != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Your Rating: ', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ...List.generate(5, (idx) {
                  return Icon(
                    idx < existingRating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amberAccent,
                    size: 28,
                  );
                }),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (idx) {
                final starsCount = idx + 1;
                return IconButton(
                  icon: const Icon(Icons.star_outline_rounded, size: 36),
                  color: Colors.amberAccent,
                  onPressed: () async {
                    final state = Map<String, dynamic>.from(_activeSession!['game_state'] as Map? ?? {});
                    final ratingsMap = Map<String, dynamic>.from(state['ratings'] as Map? ?? {});
                    final playerRatings = Map<String, dynamic>.from(ratingsMap[ratedPlayerId] as Map? ?? {});
                    playerRatings[myId] = starsCount;
                    ratingsMap[ratedPlayerId] = playerRatings;
                    state['ratings'] = ratingsMap;
                    await _updateGameState(state);
                  },
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawLobbyScreen(String myId) {
    final hostId = _activeSession?['host_id'] as String? ?? '';
    final isHost = myId == hostId;
    final wager = _drawGameState['wager'] as int? ?? 10;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.palette_rounded, size: 64, color: Colors.pinkAccent),
                const SizedBox(height: 16),
                const Text('Drawing Canvas Lobby', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Required Wager: $wager Credits', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                const Text(
                  'Competition Mode: Draw the random thing/animal privately within 60 seconds, then rate everyone else\'s drawings!',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                const Text('Joined Players:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _drawPlayers.length,
                  itemBuilder: (context, idx) {
                    final uid = _drawPlayers[idx] as String;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.pinkAccent),
                          const SizedBox(width: 12),
                          Text(uid == myId ? 'You' : 'Player ${idx + 1}', style: const TextStyle(color: Colors.white)),
                          const Spacer(),
                          if (uid == hostId) const Text('HOST', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                if (!_drawPlayers.contains(myId) && _drawPlayers.length < 6)
                  FilledButton(
                    onPressed: _joinDrawLobby,
                    style: FilledButton.styleFrom(backgroundColor: Colors.pinkAccent),
                    child: const Text('Join Lobby'),
                  )
                else if (isHost)
                  FilledButton(
                    onPressed: _drawPlayers.isNotEmpty ? _startDrawGame : null,
                    style: FilledButton.styleFrom(backgroundColor: Colors.pinkAccent),
                    child: const Text('Start Game'),
                  )
                else
                  Column(
                    children: [
                      const CircularProgressIndicator(color: Colors.pinkAccent),
                      const SizedBox(height: 8),
                      const Text('Waiting for host to start...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawEndedScreen(String myId) {
    final winId = _drawGameState['winner_id'] as String? ?? '';
    final isWinnerMe = myId == winId;
    final scoresMap = _drawGameState['scores'] as Map? ?? {};
    
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, size: 80, color: Colors.amberAccent),
                const SizedBox(height: 16),
                const Text('Game Finished! 🏁', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
                const SizedBox(height: 12),
                Text(
                  isWinnerMe ? 'Congratulations! You won the pot! 🎉' : 'Winner: Player ${_drawPlayers.indexOf(winId) + 1}',
                  style: const TextStyle(fontSize: 18, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text('Leaderboard:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 12),
                ...List.generate(_drawPlayers.length, (idx) {
                  final uid = _drawPlayers[idx] as String;
                  final avgScore = (scoresMap[uid] as num? ?? 0.0).toDouble();
                  final isMe = uid == myId;
                  final isPlayerWinner = uid == winId;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isPlayerWinner 
                          ? Colors.amberAccent.withOpacity(0.1) 
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlayerWinner ? Colors.amberAccent : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${isPlayerWinner ? "👑 " : ""}${isMe ? "You" : "Player ${idx + 1}"}',
                          style: TextStyle(
                            fontWeight: isPlayerWinner ? FontWeight.bold : FontWeight.normal,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              avgScore.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 16),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _exitGame,
                  style: FilledButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  child: const Text('Return to Lobby'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;

  _DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
  });

  Map<String, dynamic> toMap() {
    return {
      'points': points.map((p) => [p.dx, p.dy]).toList(),
      'color': color.value,
      'width': width,
    };
  }

  factory _DrawingStroke.fromMap(Map<String, dynamic> map) {
    final pointsList = map['points'] as List<dynamic>? ?? [];
    final pts = pointsList.map((p) {
      final list = p as List<dynamic>;
      return Offset((list[0] as num).toDouble(), (list[1] as num).toDouble());
    }).toList();
    return _DrawingStroke(
      points: pts,
      color: Color(map['color'] as int? ?? Colors.white.value),
      width: (map['width'] as num? ?? 4.0).toDouble(),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<_DrawingStroke> completedStrokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;

  _DrawingPainter({
    required this.completedStrokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw completed strokes
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

    // 2. Draw current active stroke
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
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.completedStrokes != completedStrokes ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentWidth != currentWidth;
  }
}
