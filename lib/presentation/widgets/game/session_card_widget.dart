import 'dart:async';
import 'package:flutter/material.dart';
import '../../blocs/game_cubit.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';

// ─── Design tokens (local, matches game_page) ─────────────────────────────────
class _C {
  static const bg          = Color(0xFF0E1321);
  static const surface     = Color(0xFF161B2A);
  static const surfaceHigh = Color(0xFF1A1F2E);
  static const surfaceTop  = Color(0xFF252A39);
  static const divider     = Color(0xFF303444);

  static const gold        = Color(0xFFF1C100);
  static const goldLight   = Color(0xFFFFE8AE);
  static const goldFill    = Color(0x1AF1C100);
  static const goldBorder  = Color(0x40F1C100);

  static const blueLight   = Color(0xFFADC6FF);
  static const blueFill    = Color(0x1A006BE3);

  static const success     = Color(0xFF2A9D8F);
  static const danger      = Color(0xFFE63946);
  static const warning     = Color(0xFFF59E0B);

  static const textHigh    = Color(0xFFDEE2F6);
  static const textMid     = Color(0xFFD1C5AB);
  static const textLow     = Color(0xFF9A9078);
}

class _T {
  static const display = TextStyle(fontFamily: 'Orbitron', color: _C.textHigh);
  static TextStyle label({double size = 11, Color? color, double spacing = 0.8, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, letterSpacing: spacing, color: color ?? _C.textMid);
  static TextStyle body({double size = 13, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, color: color ?? _C.textHigh);
}

// ─────────────────────────────────────────────────────────────────────────────
class SessionCardWidget extends StatefulWidget {
  final GameLoaded state;
  const SessionCardWidget({super.key, required this.state});
  @override State<SessionCardWidget> createState() => _SessionCardWidgetState();
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
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final isPaused = s.status == GameStatus.paused;
    final isBuying = s.status == GameStatus.buying;
    final statusColor = isPaused ? _C.danger : (isBuying ? _C.warning : _C.success);
    final statusLabel = s.statusStr.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _C.surfaceHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: Row(children: [
            // Pattern icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.goldFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.goldBorder),
              ),
              child: const Icon(Icons.grid_view_rounded, color: _C.gold, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  s.gamePattern.toUpperCase().replaceAll('_', ' '),
                  style: _T.label(size: 13, color: _C.goldLight, spacing: 1.0,
                      weight: FontWeight.w900),
                ),
                Text('Session · ${s.sessionId.substring(0, s.sessionId.length.clamp(0, 8)).toUpperCase()}',
                    style: _T.label(size: 10, color: _C.textLow, spacing: 0.3)),
              ]),
            ),
            // Status badge
            _StatusBadge(label: statusLabel, color: statusColor),
          ]),
        ),

        // Stats grid
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.attach_money_rounded,
                  iconColor: _C.success,
                  label: S.cardPrice,
                  value: '${s.gamePrice.toInt()} ETB',
                  valueColor: _C.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.style_rounded,
                  iconColor: _C.blueLight,
                  label: S.yourCards,
                  value: '${s.userCards.length}',
                  valueColor: _C.blueLight,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            // Prize pool highlight
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _C.gold.withOpacity(0.08),
                    _C.gold.withOpacity(0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.goldBorder),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_events_rounded, color: _C.gold, size: 20),
                const SizedBox(width: 10),
                Text(S.prizePool,
                    style: _T.label(size: 11, color: _C.gold.withOpacity(0.7), spacing: 1.0)),
                const Spacer(),
                Text(
                  '${s.prizePool.toInt()} ETB',
                  style: _T.display.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _C.gold,
                  ),
                ),
              ]),
            ),

            // Countdown banners
            if (isBuying && s.startTime != null) ...[
              const SizedBox(height: 10),
              _CountdownBanner(
                deadline: s.startTime!.toLocal().add(const Duration(minutes: 2)),
                icon: Icons.shopping_bag_outlined,
                label: S.buyingEndsIn,
                dangerThreshold: 15,
              ),
            ],
            if (isPaused && s.claimDeadline != null) ...[
              const SizedBox(height: 10),
              _CountdownBanner(
                deadline: s.claimDeadline!,
                icon: Icons.timer_outlined,
                label: S.claimWindowLabel,
                dangerThreshold: 5,
              ),
            ],

            // Status message
            if (s.statusMessage != null && s.statusMessage!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _C.blueFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  s.statusMessage!,
                  textAlign: TextAlign.center,
                  style: _T.body(size: 12, color: _C.blueLight),
                ),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, valueColor;
  final String label, value;
  const _StatTile({
    required this.icon, required this.iconColor,
    required this.label, required this.value, required this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _C.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(children: [
      Icon(icon, color: iconColor, size: 16),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: _T.label(size: 9, color: _C.textLow, spacing: 0.8)),
        const SizedBox(height: 2),
        Text(value, style: _T.body(size: 14, weight: FontWeight.w800, color: valueColor)),
      ]),
    ]),
  );
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4)),
      boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)],
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: _T.label(size: 10, color: color, spacing: 0.5)),
    ]),
  );
}

class _CountdownBanner extends StatelessWidget {
  final DateTime deadline;
  final IconData icon;
  final String label;
  final int dangerThreshold;
  const _CountdownBanner({
    required this.deadline, required this.icon,
    required this.label, required this.dangerThreshold,
  });
  @override
  Widget build(BuildContext context) {
    final secs = deadline.difference(DateTime.now()).inSeconds.clamp(0, 999);
    final color = secs > dangerThreshold ? _C.success : _C.danger;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text('$label:  ',
            style: _T.label(size: 11, color: color.withOpacity(0.8), spacing: 0.8)),
        Text('${secs}s',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            )),
      ]),
    );
  }
}