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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg     = isDark ? AppColors.darkCard   : Colors.white;
    final cardBorder = isDark ? Colors.white10        : AppColors.border;
    final labelColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final valueColor = isDark ? Colors.white          : AppColors.textPrimary;

    // Status badge
    final isPaused   = state.status == GameStatus.paused;
    final statusColor = isPaused ? AppColors.danger : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: pattern name + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined,
                      color: AppColors.secondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    state.gamePattern.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              _StatusBadge(label: state.statusStr, color: statusColor),
            ],
          ),

          // Countdown banners
          if (state.status == GameStatus.buying && state.startTime != null) ...[
            const SizedBox(height: 12),
            _CountdownBanner(
              deadline: state.startTime!.toLocal().add(const Duration(minutes: 2)),
              icon: Icons.shopping_bag_outlined,
              prefix: 'BUYING ENDS IN',
              dangerThreshold: 15,
            ),
          ],
          if (state.status == GameStatus.paused && state.claimDeadline != null) ...[
            const SizedBox(height: 12),
            _CountdownBanner(
              deadline: state.claimDeadline!,
              icon: Icons.timer_outlined,
              prefix: 'CLAIM WINDOW',
              dangerThreshold: 5,
            ),
          ],

          // Status message
          if (state.statusMessage != null && state.statusMessage!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              state.statusMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],

          const SizedBox(height: 14),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 14),

          // Stats — single column
          _StatRow(
            icon: Icons.confirmation_number_outlined,
            iconColor: labelColor,
            label: 'Session ID',
            value: state.sessionId
                .substring(0, state.sessionId.length.clamp(0, 8))
                .toUpperCase(),
            valueColor: valueColor,
            labelColor: labelColor,
          ),
          const SizedBox(height: 10),
          _StatRow(
            icon: Icons.attach_money_rounded,
            iconColor: AppColors.success,
            label: 'Card Price',
            value: '${state.gamePrice.toInt()} ETB',
            valueColor: AppColors.success,
            labelColor: labelColor,
          ),
          const SizedBox(height: 10),
          // Prize pool highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: _StatRow(
              icon: Icons.emoji_events_rounded,
              iconColor: AppColors.secondary,
              label: 'Prize Pool',
              value: '${state.prizePool.toInt()} ETB',
              valueColor: AppColors.secondary,
              labelColor: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 7),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  final DateTime deadline;
  final IconData icon;
  final String prefix;
  final int dangerThreshold;

  const _CountdownBanner({
    required this.deadline,
    required this.icon,
    required this.prefix,
    required this.dangerThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = deadline.difference(DateTime.now()).inSeconds;
    final secs = remaining > 0 ? remaining : 0;
    final color = secs > dangerThreshold ? AppColors.success : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '$prefix: ${secs}s',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}