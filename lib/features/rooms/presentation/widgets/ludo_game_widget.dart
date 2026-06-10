import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/widgets/glass_card.dart';

// Player colors definition
enum LudoColor { red, green, yellow, blue }

class LudoGameWidget extends ConsumerStatefulWidget {
  const LudoGameWidget({
    super.key,
    required this.roomId,
    required this.session,
    required this.onExit,
  });

  final String roomId;
  final Map<String, dynamic> session;
  final VoidCallback onExit;

  @override
  ConsumerState<LudoGameWidget> createState() => _LudoGameWidgetState();
}

class _LudoGameWidgetState extends ConsumerState<LudoGameWidget> with SingleTickerProviderStateMixin {
  // Ludo coordinates (row, col) mapped for 15x15 grid layout
  static const List<Point<int>> trackPath = [
    Point(6, 1), Point(6, 2), Point(6, 3), Point(6, 4), Point(6, 5), // Red top lane going right
    Point(5, 6), Point(4, 6), Point(3, 6), Point(2, 6), Point(1, 6), Point(0, 6), // Going up left
    Point(0, 7), // Cap top
    Point(0, 8), Point(1, 8), Point(2, 8), Point(3, 8), Point(4, 8), Point(5, 8), // Going down right
    Point(6, 9), Point(6, 10), Point(6, 11), Point(6, 12), Point(6, 13), Point(6, 14), // Going right top
    Point(7, 14), // Cap right
    Point(8, 14), Point(8, 13), Point(8, 12), Point(8, 11), Point(8, 10), Point(8, 9), // Going left bottom
    Point(9, 8), Point(10, 8), Point(11, 8), Point(12, 8), Point(13, 8), Point(14, 8), // Going down left
    Point(14, 7), // Cap bottom
    Point(14, 6), Point(13, 6), Point(12, 6), Point(11, 6), Point(10, 6), Point(9, 6), // Going up left
    Point(8, 5), Point(8, 4), Point(8, 3), Point(8, 2), Point(8, 1), Point(8, 0), // Going left bottom
    Point(7, 0), // Cap left
    Point(6, 0), // Entrance corner
  ];

  // Star safe spots on board (coordinates)
  static final Set<Point<int>> safeSpots = {
    const Point(6, 1), // Red start
    const Point(8, 2),
    const Point(2, 6),
    const Point(1, 8), // Green start
    const Point(6, 12),
    const Point(8, 13), // Yellow start
    const Point(12, 8),
    const Point(13, 6), // Blue start
  };

  // Home stretch coordinate paths for each color
  static const Map<LudoColor, List<Point<int>>> homeStretches = {
    LudoColor.red: [Point(7, 1), Point(7, 2), Point(7, 3), Point(7, 4), Point(7, 5)],
    LudoColor.green: [Point(1, 7), Point(2, 7), Point(3, 7), Point(4, 7), Point(5, 7)],
    LudoColor.yellow: [Point(7, 13), Point(7, 12), Point(7, 11), Point(7, 10), Point(7, 9)],
    LudoColor.blue: [Point(13, 7), Point(12, 7), Point(11, 7), Point(10, 7), Point(9, 7)],
  };

  // Base yard offsets for 4 tokens inside the starting houses
  static const Map<LudoColor, List<Point<int>>> baseYardOffsets = {
    LudoColor.red: [Point(2, 2), Point(2, 3), Point(3, 2), Point(3, 3)],
    LudoColor.green: [Point(2, 11), Point(2, 12), Point(3, 11), Point(3, 12)],
    LudoColor.yellow: [Point(11, 11), Point(11, 12), Point(12, 11), Point(12, 12)],
    LudoColor.blue: [Point(11, 2), Point(11, 3), Point(12, 2), Point(12, 3)],
  };

  // Player color starts on the common track path (index values)
  static const Map<LudoColor, int> playerStartTrackIndices = {
    LudoColor.red: 0,     // (6, 1)
    LudoColor.green: 13,   // (1, 8)
    LudoColor.yellow: 26,  // (8, 13)
    LudoColor.blue: 39,    // (13, 6)
  };

  // Dice rolling animation variables
  late AnimationController _diceAnimationController;
  int _localDiceValue = 1;
  bool _isDiceRollingLocal = false;

  @override
  void initState() {
    super.initState();
    _diceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _diceAnimationController.dispose();
    super.dispose();
  }

  // Parse state helper from JSONB database representation
  Map<String, dynamic> get gameState => widget.session['game_state'] as Map<String, dynamic>? ?? {};

  List<dynamic> get players => gameState['players'] as List<dynamic>? ?? [];
  Map<String, dynamic> get tokenPositions => gameState['token_positions'] as Map<String, dynamic>? ?? {};
  String get currentTurn => gameState['current_turn'] as String? ?? '';
  int get diceValue => gameState['dice_value'] as int? ?? 0;
  bool get hasRolled => gameState['has_rolled'] as bool? ?? false;
  String get gameStatus => gameState['game_status'] as String? ?? 'lobby';
  String get winnerId => gameState['winner_id'] as String? ?? '';
  int get wager => gameState['wager'] as int? ?? 10;

  // Map user ID to player index/color
  LudoColor _getPlayerColor(String userId) {
    final idx = players.indexOf(userId);
    if (idx == 0) return LudoColor.red;
    if (idx == 1) return LudoColor.green;
    if (idx == 2) return LudoColor.yellow;
    return LudoColor.blue;
  }

  Color _getLudoUiColor(LudoColor color) {
    switch (color) {
      case LudoColor.red: return Colors.redAccent;
      case LudoColor.green: return Colors.greenAccent;
      case LudoColor.yellow: return Colors.amberAccent;
      case LudoColor.blue: return Colors.blueAccent;
    }
  }

  // Push new state to database
  Future<void> _updateGameState(Map<String, dynamic> newState) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    try {
      await client
          .from('game_sessions')
          .update({'game_state': newState})
          .eq('id', widget.session['id']);
    } catch (e) {
      debugPrint('Error updating Ludo state: $e');
    }
  }

  // Trigger payout for winners safely via database RPC function
  Future<void> _payoutWinner(String winnerId, int potAmount) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    try {
      await client.rpc('reward_winner', params: {
        'player_id': winnerId,
        'reward_amount': potAmount,
        'game_name': 'Ludo Real-Time',
      });
      // Mark game session as finished
      await client
          .from('game_sessions')
          .update({'status': 'finished', 'winner_id': winnerId})
          .eq('id', widget.session['id']);
    } catch (e) {
      debugPrint('Error rewarding Ludo winner: $e');
    }
  }

  // Check if player has enough credit and place bet
  Future<bool> _placePlayerBet(String userId, int amount) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return false;
    try {
      final res = await client.rpc('place_bet', params: {
        'player_id': userId,
        'bet_amount': amount,
      }) as bool?;
      return res ?? false;
    } catch (e) {
      debugPrint('Error placing Ludo bet: $e');
      return false;
    }
  }

  // Start the Ludo Game (locks wagers and starts turn)
  Future<void> _startGame() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;

    if (players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need at least 2 players to start!')),
      );
      return;
    }

    // Deduct entry bets from all users
    for (final userId in players) {
      final betSuccess = await _placePlayerBet(userId, wager);
      if (!betSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deduct bet for user: $userId (Insufficient credits)')),
        );
        return;
      }
    }

    // Initialize tokens to home yard positions (-1, -1, -1, -1)
    final initialTokens = <String, List<int>>{};
    for (final userId in players) {
      initialTokens[userId] = [-1, -1, -1, -1];
    }

    final startState = {
      'players': players,
      'token_positions': initialTokens,
      'current_turn': players.first,
      'dice_value': 0,
      'has_rolled': false,
      'game_status': 'playing',
      'winner_id': '',
      'wager': wager,
    };

    await _updateGameState(startState);
  }

  // Join lobby
  Future<void> _joinLobby() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null) return;

    if (players.contains(myId)) return;
    if (players.length >= 4) return;

    final updatedPlayers = List<String>.from(players)..add(myId);
    final newState = Map<String, dynamic>.from(gameState)..['players'] = updatedPlayers;
    await _updateGameState(newState);
  }

  // Roll Dice
  Future<void> _rollDice() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null || myId != currentTurn || hasRolled || _isDiceRollingLocal) return;

    setState(() {
      _isDiceRollingLocal = true;
    });

    _diceAnimationController.forward(from: 0.0);
    
    // Simulate dice rolling sound / delays locally
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (mounted) {
        setState(() {
          _localDiceValue = Random().nextInt(6) + 1;
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _isDiceRollingLocal = false;
    });

    final rolledVal = _localDiceValue;
    
    // Determine if player has any legal moves. If not, automatically pass turn!
    final myTokens = List<int>.from(tokenPositions[myId] as List<dynamic>? ?? [-1, -1, -1, -1]);
    bool hasLegalMove = false;
    for (int i = 0; i < 4; i++) {
      final pos = myTokens[i];
      if (pos == -1 && rolledVal == 6) {
        hasLegalMove = true;
        break;
      }
      if (pos >= 0 && pos + rolledVal <= 57) {
        hasLegalMove = true;
        break;
      }
    }

    final nextTurnUser = _getNextTurnUserId();
    
    if (hasLegalMove) {
      final newState = Map<String, dynamic>.from(gameState)
        ..['dice_value'] = rolledVal
        ..['has_rolled'] = true;
      await _updateGameState(newState);
    } else {
      // Pass turn directly
      final newState = Map<String, dynamic>.from(gameState)
        ..['dice_value'] = rolledVal
        ..['has_rolled'] = false;
      await _updateGameState(newState);
      
      // Delay briefly to let user see their rolled value before passing turn
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final passState = Map<String, dynamic>.from(gameState)
        ..['current_turn'] = nextTurnUser
        ..['dice_value'] = 0
        ..['has_rolled'] = false;
      await _updateGameState(passState);
    }
  }

  // Get next player's Turn ID
  String _getNextTurnUserId() {
    final currentIdx = players.indexOf(currentTurn);
    final nextIdx = (currentIdx + 1) % players.length;
    return players[nextIdx] as String;
  }

  // Move Token
  Future<void> _moveToken(int tokenIdx) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    final myId = client.auth.currentUser?.id;
    if (myId == null || myId != currentTurn || !hasRolled) return;

    final myTokens = List<int>.from(tokenPositions[myId] as List<dynamic>? ?? [-1, -1, -1, -1]);
    final curPos = myTokens[tokenIdx];

    // Legal move checks
    if (curPos == -1 && diceValue != 6) return; // Need 6 to exit home yard
    if (curPos >= 0 && curPos + diceValue > 57) return; // Cannot overshoot home pocket

    // Execute move
    int newPos = curPos == -1 ? 0 : curPos + diceValue;
    myTokens[tokenIdx] = newPos;

    // Check if landing spot kills/captures an opponent token
    final updatedTokenPositions = Map<String, dynamic>.from(tokenPositions);
    updatedTokenPositions[myId] = myTokens;

    if (newPos >= 0 && newPos < 51) {
      final myGridSpot = _getGridCoordinate(_getPlayerColor(myId), newPos);
      if (!safeSpots.contains(myGridSpot)) {
        // Star tiles are safe zones. If not star, check other players
        for (final oppId in players) {
          if (oppId == myId) continue;
          final oppTokens = List<int>.from(tokenPositions[oppId] as List<dynamic>? ?? [-1, -1, -1, -1]);
          bool oppKilled = false;
          for (int i = 0; i < 4; i++) {
            if (oppTokens[i] >= 0 && oppTokens[i] < 51) {
              final oppGridSpot = _getGridCoordinate(_getPlayerColor(oppId), oppTokens[i]);
              if (oppGridSpot == myGridSpot) {
                // Opponent token is captured! Send back to yard (-1)
                oppTokens[i] = -1;
                oppKilled = true;
              }
            }
          }
          if (oppKilled) {
            updatedTokenPositions[oppId] = oppTokens;
          }
        }
      }
    }

    // Check if player won (all 4 tokens in pocket index 57)
    bool isWinner = myTokens.every((pos) => pos == 57);

    if (isWinner) {
      final potAmount = wager * players.length;
      final houseComission = (potAmount * 0.05).round(); // 5% app commision
      final reward = potAmount - houseComission;
      
      await _payoutWinner(myId, reward);
    } else {
      // Pass turn to next player (player gets another roll on a 6)
      final nextTurn = (diceValue == 6) ? myId : _getNextTurnUserId();
      final newState = Map<String, dynamic>.from(gameState)
        ..['token_positions'] = updatedTokenPositions
        ..['current_turn'] = nextTurn
        ..['dice_value'] = 0
        ..['has_rolled'] = false;
      await _updateGameState(newState);
    }
  }

  // Math helper mapping token step index to absolute (row, col) coordinates on board grid
  Point<int> _getGridCoordinate(LudoColor color, int step) {
    if (step == -1) {
      return baseYardOffsets[color]![0]; // Yard default (will draw stacked tokens appropriately)
    }
    if (step == 57) {
      return const Point(7, 7); // Center home pocket
    }
    if (step >= 51 && step <= 56) {
      return homeStretches[color]![step - 51];
    }
    
    // Map index along standard 52 cell circular track
    final startIdx = playerStartTrackIndices[color]!;
    final absoluteIndex = (startIdx + step) % 52;
    return trackPath[absoluteIndex];
  }

  @override
  Widget build(BuildContext context) {
    final client = SupabaseService.clientOrNull;
    final myId = client?.auth.currentUser?.id ?? '';
    final isMyTurn = myId == currentTurn && currentTurn.isNotEmpty;

    if (gameStatus == 'lobby') {
      return _buildLobbyScreen(myId);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filled(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onExit,
                tooltip: 'Leave Game',
                style: IconButton.styleFrom(backgroundColor: Colors.white10),
              ),
              Column(
                children: [
                  const Text('Ludo Real-Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Pot: ${wager * players.length} Credits', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              const SizedBox(width: 48), // spacer
            ],
          ),
          const SizedBox(height: 12),
          
          // Ludo Board Panel
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 2),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 15,
                  ),
                  itemCount: 225, // 15x15
                  itemBuilder: (context, index) {
                    final row = index ~/ 15;
                    final col = index % 15;
                    final gridPt = Point(row, col);
                    
                    return _buildGridCell(row, col, gridPt, myId);
                  },
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Controls / Player Turn Dashboard
          _buildDashboard(myId, isMyTurn),
        ],
      ),
    );
  }

  // Draw board grid cell widgets based on coordinate mapping
  Widget _buildGridCell(int row, int col, Point<int> pt, String myId) {
    // 1. Determine base houses
    if (row < 6 && col < 6) return _buildHouse(LudoColor.red, pt);
    if (row < 6 && col > 8) return _buildHouse(LudoColor.green, pt);
    if (row > 8 && col < 6) return _buildHouse(LudoColor.blue, pt);
    if (row > 8 && col > 8) return _buildHouse(LudoColor.yellow, pt);

    // 2. Home pockets center (7,7)
    if (row >= 6 && row <= 8 && col >= 6 && col <= 8) {
      if (row == 7 && col == 7) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.rectangle,
          ),
          child: const Center(child: Icon(Icons.stars, size: 12, color: Colors.white)),
        );
      }
      // Home pocket triangles
      Color triColor = Colors.white10;
      if (row == 6 && col == 7) triColor = Colors.greenAccent;
      if (row == 8 && col == 7) triColor = Colors.blueAccent;
      if (row == 7 && col == 6) triColor = Colors.redAccent;
      if (row == 7 && col == 8) triColor = Colors.amberAccent;
      
      return Container(color: triColor.withOpacity(0.4));
    }

    // 3. Home stretches
    LudoColor? stretchColor;
    if (row == 7 && col >= 1 && col <= 5) stretchColor = LudoColor.red;
    if (col == 7 && row >= 1 && row <= 5) stretchColor = LudoColor.green;
    if (row == 7 && col >= 9 && col <= 13) stretchColor = LudoColor.yellow;
    if (col == 7 && row >= 9 && row <= 13) stretchColor = LudoColor.blue;

    if (stretchColor != null) {
      return Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _getLudoUiColor(stretchColor).withOpacity(0.8),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    // 4. Common tracks and Safe slots
    final isSafe = safeSpots.contains(pt);
    Color cellBg = Colors.grey[900]!;
    Widget? starIcon;

    if (isSafe) {
      cellBg = Colors.white10;
      starIcon = const Icon(Icons.star, size: 10, color: Colors.white54);
      if (pt == Point(6, 1)) cellBg = Colors.redAccent.withOpacity(0.3);
      if (pt == Point(1, 8)) cellBg = Colors.greenAccent.withOpacity(0.3);
      if (pt == Point(8, 13)) cellBg = Colors.amberAccent.withOpacity(0.3);
      if (pt == Point(13, 6)) cellBg = Colors.blueAccent.withOpacity(0.3);
    }

    // Find if there are tokens in this cell
    final cellTokens = <Widget>[];
    tokenPositions.forEach((userId, tokens) {
      final pColor = _getPlayerColor(userId);
      final list = tokens as List<dynamic>;
      for (int i = 0; i < 4; i++) {
        final step = list[i] as int;
        if (step >= 0 && _getGridCoordinate(pColor, step) == pt) {
          cellTokens.add(_buildTokenIndicator(userId, pColor, i, myId));
        }
      }
    });

    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: cellBg,
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (starIcon != null) starIcon,
          if (cellTokens.isNotEmpty)
            cellTokens.length == 1
                ? cellTokens.first
                : Wrap(spacing: 1, runSpacing: 1, children: cellTokens),
        ],
      ),
    );
  }

  // Draw houses yard
  Widget _buildHouse(LudoColor color, Point<int> pt) {
    // Yards borders
    final isBorder = pt.x == 0 || pt.x == 5 || pt.y == 0 || pt.y == 5 ||
        pt.x == 9 || pt.x == 14 || pt.y == 9 || pt.y == 14;
    
    // Check if tokens are in yard (-1)
    final yardTokens = <Widget>[];
    tokenPositions.forEach((userId, tokens) {
      final pColor = _getPlayerColor(userId);
      if (pColor != color) return;
      final list = tokens as List<dynamic>;
      
      // Map offsets inside the house for 4 tokens
      final yardPositions = baseYardOffsets[color]!;
      for (int i = 0; i < 4; i++) {
        if (list[i] == -1 && yardPositions[i] == pt) {
          yardTokens.add(_buildTokenIndicator(userId, pColor, i, null));
        }
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: isBorder ? _getLudoUiColor(color).withOpacity(0.2) : _getLudoUiColor(color).withOpacity(0.6),
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: yardTokens.isNotEmpty ? Center(child: yardTokens.first) : null,
    );
  }

  // Draw Token Chip
  Widget _buildTokenIndicator(String userId, LudoColor color, int tokenIdx, String? currentUserId) {
    final isClickable = currentUserId != null &&
        userId == currentUserId &&
        currentTurn == currentUserId &&
        hasRolled &&
        (_isValidMove(tokenIdx));

    return GestureDetector(
      onTap: isClickable ? () => _moveToken(tokenIdx) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: _getLudoUiColor(color),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: isClickable ? 2.0 : 1.0),
          boxShadow: isClickable
              ? [BoxShadow(color: _getLudoUiColor(color), blurRadius: 8, spreadRadius: 2)]
              : null,
        ),
        child: Center(
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  bool _isValidMove(int tokenIdx) {
    final myTokens = List<int>.from(tokenPositions[currentTurn] as List<dynamic>? ?? [-1, -1, -1, -1]);
    final pos = myTokens[tokenIdx];
    if (pos == -1 && diceValue != 6) return false;
    if (pos >= 0 && pos + diceValue > 57) return false;
    return true;
  }

  // Lobby/Bet startup selection screen
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
                const Icon(Icons.casino, size: 64, color: Colors.greenAccent),
                const SizedBox(height: 16),
                const Text(
                  'Ludo Real-Time Lobby',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Required Entry wager: $wager Credits',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
                
                // Joined players lists
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 8,
                            backgroundColor: _getLudoUiColor(_getPlayerColor(uid)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(uid == myId ? 'You' : 'Player ${idx + 1}', style: const TextStyle(fontSize: 14))),
                          if (uid == hostId)
                            const Text('HOST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                        ],
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Actions
                if (!players.contains(myId) && players.length < 4)
                  FilledButton.icon(
                    onPressed: _joinLobby,
                    icon: const Icon(Icons.login),
                    label: const Text('Join Game'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                  )
                else if (isHost)
                  FilledButton.icon(
                    onPressed: players.length >= 2 ? _startGame : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Game'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  )
                else
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white38)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Dashboard showing active dice rolls and player list
  Widget _buildDashboard(String myId, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Players turns indicator
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: players.map((uid) {
                final color = _getPlayerColor(uid as String);
                final isCurrent = uid == currentTurn;
                return Chip(
                  avatar: CircleAvatar(backgroundColor: _getLudoUiColor(color), radius: 6),
                  label: Text(
                    uid == myId ? 'You' : 'Opponent',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? Colors.black : Colors.white70
                    ),
                  ),
                  backgroundColor: isCurrent ? Colors.white : Colors.white10,
                );
              }).toList(),
            ),
          ),
          
          // 2. Interactive Dice rolling area
          GestureDetector(
            onTap: isMyTurn && !hasRolled ? _rollDice : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isMyTurn && !hasRolled ? Colors.indigoAccent : Colors.grey[800],
                borderRadius: BorderRadius.circular(12),
                boxShadow: isMyTurn && !hasRolled
                    ? [const BoxShadow(color: Colors.indigoAccent, blurRadius: 10, spreadRadius: 1)]
                    : null,
              ),
              child: Center(
                child: _isDiceRollingLocal
                    ? RotationTransition(turns: _diceAnimationController, child: const Icon(Icons.casino, size: 28, color: Colors.white))
                    : Text(
                        diceValue > 0 ? diceValue.toString() : 'Roll',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
