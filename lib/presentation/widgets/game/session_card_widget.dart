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
// PATTERN HELP DIALOG
// Draws a visual 5x5 bingo card with the winning pattern highlighted.
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a 5x5 grid of booleans: true = highlighted cell.
List<List<bool>> _patternGrid(String rawPattern) {
  final p = rawPattern.toLowerCase().replaceAll(' ', '_');

  // Full house: all cells
  if (p.contains('full') || p.contains('house')) {
    return List.generate(5, (_) => List.filled(5, true));
  }
  // Single line — highlight ALL rows (any row wins)
  if (p.contains('single') || p == 'line' || p == 'one_line') {
  return List.generate(5, (r) => List.generate(5, (c) => r == 2));
}
  // Two lines / double line — FIX: must be BEFORE the T check
  if (p.contains('two') || p.contains('double')) {
    // Highlight rows 0+2+4 as representative; all combos of any 2 rows win
    return List.generate(5, (r) => List.generate(5, (c) => r == 1 || r == 3));
  }
  // T shape — FIX: use exact match / contains('t_shape'), not startsWith('t')
  if (p == 't_shape' || p.contains('t_shape')) {
    return List.generate(5, (r) => List.generate(5, (c) => r == 0 || c == 2));
  }
  // L shape — FIX: use exact match, not startsWith('l')
  if (p == 'l_shape' || p.contains('l_shape')) {
    return List.generate(5, (r) => List.generate(5, (c) => c == 0 || r == 4));
  }
  // X (diagonal cross)
  if (p == 'x' || p.contains('diagonal')) {
    return List.generate(5, (r) => List.generate(5, (c) => r == c || r + c == 4));
  }
  // Plus / cross
  if (p.contains('plus') || p.contains('cross') || p.contains('+')) {
    return List.generate(5, (r) => List.generate(5, (c) => r == 2 || c == 2));
  }
  // Corners
  if (p.contains('corner')) {
    return List.generate(5, (r) => List.generate(5, (c) =>
        (r == 0 || r == 4) && (c == 0 || c == 4)));
  }
  // Frame / border
  if (p.contains('frame') || p.contains('border')) {
    return List.generate(5, (r) => List.generate(5, (c) =>
        r == 0 || r == 4 || c == 0 || c == 4));
  }
  // Default fallback
  return List.generate(5, (r) => List.generate(5, (c) => r == 2));
}

String _patternDescription(String rawPattern) {
  final p = rawPattern.toLowerCase().replaceAll(' ', '_');
  if (p.contains('full') || p.contains('house')) {
    return 'Mark ALL 25 numbers on your card to win.';
  }
  if (p.contains('single') || p == 'line' || p == 'one_line') {
  return 'Mark any 1 complete horizontal row to win. (Any row counts!)';
}
  // FIX: two/double before T
  if (p.contains('two') || p.contains('double')) {
    return 'Mark any 2 complete horizontal rows to win.';
  }
  // FIX: exact match for T and L
  if (p == 't_shape' || p.contains('t_shape')) {
    return 'Mark the top row + middle column to form a T shape.';
  }
  if (p == 'l_shape' || p.contains('l_shape')) {
    return 'Mark the left column + bottom row to form an L shape.';
  }
  if (p == 'x' || p.contains('diagonal')) {
    return 'Mark both diagonals (corner to corner) to form an X.';
  }
  if (p.contains('plus') || p.contains('cross') || p.contains('+')) {
    return 'Mark the middle row + middle column to form a Plus (+).';
  }
  if (p.contains('corner')) {
    return 'Mark all 4 corner cells of your card to win.';
  }
  if (p.contains('frame') || p.contains('border')) {
    return 'Mark all cells on the outer edge of your card.';
  }
  return 'Mark the highlighted cells on your card to win.';
}
void _showPatternHelpDialog(BuildContext context, String gamePattern) {
  final grid = _patternGrid(gamePattern);
  final desc = _patternDescription(gamePattern);
  final label = gamePattern.toUpperCase().replaceAll('_', ' ');

  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B2A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.goldBorder),
          boxShadow: [
            BoxShadow(color: _C.gold.withOpacity(0.08), blurRadius: 32, spreadRadius: 2),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: _C.surfaceHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _C.goldFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.goldBorder),
                ),
                child: const Icon(Icons.help_outline_rounded, color: _C.gold, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('HOW TO WIN', style: _T.label(size: 10, color: _C.textLow, spacing: 1.2)),
                Text(label, style: _T.label(size: 14, color: _C.goldLight, spacing: 0.8,
                    weight: FontWeight.w900)),
              ])),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: _C.textLow, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // 5x5 grid diagram
              AspectRatio(
                aspectRatio: 1,
                child: _PatternGrid(grid: grid),
              ),
              const SizedBox(height: 16),
              // Legend row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _LegendDot(color: _C.gold, label: 'Win cells'),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFF252A39), label: 'Other cells', outlined: true),
              ]),
              const SizedBox(height: 16),
              // Description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.goldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.goldBorder),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: _C.gold, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(desc,
                      style: _T.body(size: 12, color: _C.goldLight, weight: FontWeight.w500))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

// ─── Pattern grid painter ─────────────────────────────────────────────────────
class _PatternGrid extends StatelessWidget {
  final List<List<bool>> grid;
  const _PatternGrid({required this.grid});

  static const _headers = ['B', 'I', 'N', 'G', 'O'];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Column headers
      Row(children: [
        for (int c = 0; c < 5; c++)
          Expanded(
            child: Center(
              child: Text(_headers[c],
                  style: _T.label(size: 13, color: _C.gold, spacing: 1.0,
                      weight: FontWeight.w900)),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Expanded(
        child: Column(children: [
          for (int r = 0; r < 5; r++)
            Expanded(
              child: Row(children: [
                for (int c = 0; c < 5; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: _GridCell(
                        highlighted: grid[r][c],
                        isFreeSpace: r == 2 && c == 2,
                      ),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _GridCell extends StatelessWidget {
  final bool highlighted;
  final bool isFreeSpace;
  const _GridCell({required this.highlighted, this.isFreeSpace = false});

  @override
  Widget build(BuildContext context) {
    if (isFreeSpace) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF1C100), Color(0xFFFFE060)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: _C.gold.withOpacity(0.5), blurRadius: 8),
          ],
        ),
        child: const Center(
          child: Icon(Icons.star_rounded, color: Colors.black, size: 16),
        ),
      );
    }
    if (highlighted) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.gold.withOpacity(0.9), _C.gold.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(color: _C.gold.withOpacity(0.35), blurRadius: 6),
          ],
        ),
        child: Center(
          child: Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A39),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;
  const _LegendDot({required this.color, required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: outlined ? _C.divider : color.withOpacity(0.6)),
      ),
    ),
    const SizedBox(width: 6),
    Text(label, style: _T.label(size: 10, color: _C.textLow, spacing: 0.3)),
  ]);
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
            // Help / pattern button
            GestureDetector(
              onTap: () => _showPatternHelpDialog(context, s.gamePattern),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _C.goldFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.goldBorder),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.help_outline_rounded, color: _C.gold, size: 13),
                  const SizedBox(width: 4),
                  Text('HOW TO WIN',
                      style: _T.label(size: 9, color: _C.gold, spacing: 0.5)),
                ]),
              ),
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
