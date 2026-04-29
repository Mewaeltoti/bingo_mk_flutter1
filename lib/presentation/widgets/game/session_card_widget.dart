import 'package:flutter/material.dart';
import '../../blocs/game_cubit.dart';

class SessionCardWidget extends StatelessWidget {
  final GameLoaded state;

  const SessionCardWidget({super.key, required this.state});

  String _safeId(String id) {
    if (id.isEmpty) return "N/A";
    return id; // Image shows plain number: 92947138
  }

  String _formatTime() {
    if (state.startTime == null) return "N/A";
    final h = state.startTime!.hour.toString().padLeft(2, '0');
    final m = state.startTime!.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Widget _buildIconText(
    IconData icon,
    Color iconColor,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Row 1: Game
          Row(
            children: [
              const Icon(Icons.games, color: Colors.blue, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Game: ",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  state.gamePattern.toUpperCase().replaceAll('_', ' '),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: ID, Time, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconText(
                Icons.qr_code_scanner,
                Colors.grey,
                "ID:",
                _safeId(state.sessionId),
              ),
              _buildIconText(
                Icons.access_time,
                Colors.grey,
                "Time:",
                _formatTime(),
              ),
              _buildIconText(
                Icons.info_outline,
                Colors.grey,
                "Status:",
                state.statusStr,
                valueColor: Colors.green,
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),

          // Row 3: Price, Games, Prize
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconText(
                Icons.attach_money,
                Colors.green,
                "Price:",
                "\$${state.gamePrice.toInt()}",
                valueColor: Colors.green,
              ),
              _buildIconText(
                Icons.games,
                Colors.blue,
                "Games:",
                "1",
                valueColor: Colors.blue,
              ), // Hardcoded 1 games as per image
              _buildIconText(
                Icons.emoji_events,
                Colors.orange,
                "Prize:",
                "\$${state.prizePool.toInt()}",
                valueColor: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
