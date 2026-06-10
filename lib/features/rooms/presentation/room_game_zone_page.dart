import 'dart:async';
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

  @override
  void initState() {
    super.initState();
    _subscribeToGameSession();
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
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
            final strokesRaw = state['strokes'] as List<dynamic>? ?? [];
            _drawingStrokes = strokesRaw
                .map((s) => _DrawingStroke.fromMap(s as Map<String, dynamic>))
                .toList();
          }
        });
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
      initialState = {
        'strokes': [],
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
    if (_activeGameType == null) {
      return _buildGameSelectionMenu();
    }

    switch (_activeGameType) {
      case 'xo':
        return _buildXOBoard();
      case 'draw':
        return _buildDrawingBoard();
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
    );
  }

  Widget _buildDrawingBoard() {
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
              const Text(
                'Drawing Canvas 🎨',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    icon: const Icon(Icons.undo_rounded),
                    onPressed: _drawingStrokes.isEmpty ? null : () {
                      final updatedStrokes = List<_DrawingStroke>.from(_drawingStrokes)..removeLast();
                      final newState = {
                        'strokes': updatedStrokes.map((s) => s.toMap()).toList(),
                      };
                      setState(() {
                        _drawingStrokes = updatedStrokes;
                      });
                      _updateGameState(newState);
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
                      final newState = {
                        'strokes': [],
                      };
                      setState(() {
                        _drawingStrokes = [];
                      });
                      _updateGameState(newState);
                    },
                    tooltip: 'Clear Canvas',
                    style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Canvas area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanStart: (details) {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final localPoint = renderBox.globalToLocal(details.globalPosition);
                  setState(() {
                    _currentPoints = [localPoint];
                  });
                },
                onPanUpdate: (details) {
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
                },
                onPanEnd: (details) {
                  if (_currentPoints.isNotEmpty) {
                    final newStroke = _DrawingStroke(
                      points: List<Offset>.from(_currentPoints),
                      color: currentColor,
                      width: _selectedWidth,
                    );

                    final updatedStrokes = List<_DrawingStroke>.from(_drawingStrokes)..add(newStroke);
                    
                    // Push updated strokes to database
                    final newState = {
                      'strokes': updatedStrokes.map((s) => s.toMap()).toList(),
                    };
                    
                    setState(() {
                      _drawingStrokes = updatedStrokes;
                      _currentPoints = [];
                    });

                    _updateGameState(newState);
                  }
                },
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
        ),
      ],
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
