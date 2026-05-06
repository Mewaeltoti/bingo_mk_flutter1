import 'dart:async';
import 'package:flutter/material.dart';
import '../../blocs/game_cubit.dart';

class SessionCardWidget extends StatefulWidget {
  final GameLoaded state;

  const SessionCardWidget({super.key, required this.state});

  @override
  State<SessionCardWidget> createState() => _SessionCardWidgetState();
}

class _SessionCardWidgetState extends State<SessionCardWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime() {
    if (widget.state.startTime == null) return "00:00";
    final h = widget.state.startTime!.hour.toString().padLeft(2, '0');
    final m = widget.state.startTime!.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Widget _buildInfoRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pattern info
          Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFF1E88E5), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "GAME: ${state.gamePattern.toUpperCase().replaceAll('_', ' ')}",
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ID, Time, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoRow(
                Icons.qr_code,
                Colors.grey,
                "ID:",
                state.sessionId.substring(
                  0,
                  state.sessionId.length.clamp(0, 8),
                ),
                const Color(0xFF334155),
              ),
              _buildInfoRow(
                Icons.schedule,
                Colors.grey,
                "TIME:",
                _formatTime(),
                const Color(0xFF334155),
              ),
              _buildInfoRow(
                Icons.radio_button_checked,
                Colors.green,
                "LIVE:",
                state.statusStr,
                Colors.green,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Price, Players, Prize
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoRow(
                Icons.attach_money,
                Colors.green,
                "PRICE:",
                "${state.gamePrice.toInt()} ETB",
                Colors.green,
              ),
              _buildInfoRow(
                Icons.group,
                Colors.blue,
                "PLAYERS:",
                "${state.playerCount}",
                Colors.blue,
              ),
              _buildInfoRow(
                Icons.emoji_events,
                Colors.orange,
                "PRIZE:",
                "${state.prizePool.toInt()} ETB",
                Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
