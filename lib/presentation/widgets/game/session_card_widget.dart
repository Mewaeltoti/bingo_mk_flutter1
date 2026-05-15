import 'dart:async';
import 'package:flutter/material.dart';
import '../../blocs/game_cubit.dart';
import '../../../core/theme/app_theme.dart';

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
    if (widget.state.startTime == null) return "00:00:00";
    final h = widget.state.startTime!.hour.toString().padLeft(2, '0');
    final m = widget.state.startTime!.minute.toString().padLeft(2, '0');
    final s = widget.state.startTime!.second.toString().padLeft(2, '0');
    return "$h:$m:$s";
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
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.hub, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "GAME: ${state.gamePattern.toUpperCase().replaceAll('_', ' ')}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  final isPaused = state.status == GameStatus.paused;
                  final color = isPaused ? AppColors.danger : AppColors.success;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle, color: color, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          state.statusStr,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          if (state.status == GameStatus.paused && state.claimDeadline != null)
             _buildCountdownSection(state.claimDeadline!),
          if (state.statusMessage != null && state.statusMessage!.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(bottom: 16),
               child: Center(
                 child: Text(
                   state.statusMessage!,
                   textAlign: TextAlign.center,
                   style: const TextStyle(
                     color: AppColors.secondary,
                     fontWeight: FontWeight.bold,
                     fontSize: 12,
                   ),
                 ),
               ),
             ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoRow(
                Icons.qr_code,
                AppColors.textSecondary,
                "ID",
                state.sessionId.substring(0, state.sessionId.length.clamp(0, 6)).toUpperCase(),
                Colors.white,
              ),
              _buildInfoRow(
                Icons.schedule,
                AppColors.textSecondary,
                "START TIME",
                _formatTime(),
                Colors.white,
              ),
              _buildInfoRow(
                Icons.attach_money,
                AppColors.success,
                "PRICE",
                "${state.gamePrice.toInt()} ETB",
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoRow(
                Icons.group,
                AppColors.accent,
                "PLAYERS",
                "${state.playerCount}",
                AppColors.accent,
              ),
              _buildInfoRow(
                Icons.emoji_events,
                AppColors.secondary,
                "PRIZE POOL",
                "${state.prizePool.toInt()} ETB",
                AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownSection(DateTime deadline) {
    final now = DateTime.now();
    final remaining = deadline.difference(now).inSeconds;
    final displaySeconds = remaining > 0 ? remaining : 0;
    final color = displaySeconds > 5 ? AppColors.secondary : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            "CLAIM WINDOW: ${displaySeconds}s",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
