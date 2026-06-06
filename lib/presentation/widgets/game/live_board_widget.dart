import 'package:flutter/material.dart';
import 'package:bingo_mk/presentation/blocs/settings_cubit.dart';
import 'package:animate_do/animate_do.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';

class _C {
  static bool get _l => SettingsCubit.isLightModeGlobal;

  static Color get surface     => _l ? const Color(0xFFFFFFFF) : const Color(0xFF161B2A);
  static Color get surfaceHigh => _l ? const Color(0xFFF9FAFB) : const Color(0xFF1A1F2E);
  static Color get divider     => _l ? const Color(0xFFEAECF0) : const Color(0xFF303444);
  static const gold        = Color(0xFFF1C100);
  static Color get textHigh => _l ? const Color(0xFF101828) : const Color(0xFFDEE2F6);
  static Color get textLow  => _l ? const Color(0xFF667085) : const Color(0xFF9A9078);

  static const b = Color(0xFF4FC3F7); // Blue
  static const i = Color(0xFFE57373); // Red-pink
  static const n = Color(0xFF81C784); // Green
  static const g = Color(0xFFBA68C8); // Purple
  static const o = Color(0xFFF1C100); // Gold
}

class LiveBoardWidget extends StatelessWidget {
  final List<int> drawnNumbers;
  const LiveBoardWidget({super.key, required this.drawnNumbers});

  static const _letters = ['B', 'I', 'N', 'G', 'O'];
  static const _colors  = [_C.b, _C.i, _C.n, _C.g, _C.o];

  @override
  Widget build(BuildContext context) {
    final drawnSet = drawnNumbers.toSet();
    final lastDrawn = drawnNumbers.isNotEmpty ? drawnNumbers.last : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.grid_3x3_rounded, size: 14, color: _C.textLow),
          const SizedBox(width: 6),
          Text(
            'DRAWN: ${drawnNumbers.length} / 75',
            style: TextStyle(
              fontFamily: 'Outfit',
              color: _C.textLow,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          if (lastDrawn != null) ...[
            const SizedBox(width: 12),
            Text('·', style: TextStyle(color: _C.textLow)),
            const SizedBox(width: 12),
            Text(S.last,
                style: TextStyle(
                    fontFamily: 'Outfit', color: _C.textLow, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            Pulse(
              infinite: true,
              duration: const Duration(milliseconds: 900),
              child: Text(
                '$lastDrawn',
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _C.gold,
                ),
              ),
            ),
          ],
        ]),

        const SizedBox(height: 10),
        Container(height: 0.5, color: _C.divider),
        const SizedBox(height: 10),

        // Board rows
        ...List.generate(5, (row) {
          final letter = _letters[row];
          final color  = _colors[row];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              // Letter badge
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Text(letter,
                    style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              // Number cells
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(15, (i) {
                    final num    = row * 15 + i + 1;
                    final isDrawn = drawnSet.contains(num);
                    final isLast  = num == lastDrawn;

                    Widget cell = AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      alignment: Alignment.center,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height: 24,
                      decoration: BoxDecoration(
                        color: isLast
                            ? color
                            : isDrawn
                                ? color.withOpacity(0.25)
                                : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(5),
                        border: isLast
                            ? Border.all(color: Colors.white.withOpacity(0.5), width: 1)
                            : isDrawn
                                ? Border.all(color: color.withOpacity(0.4))
                                : null,
                        boxShadow: isLast
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
                            : [],
                      ),
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Text(
                            '$num',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isLast
                                  ? Colors.black
                                  : isDrawn
                                      ? color
                                      : Colors.white.withOpacity(0.18),
                            ),
                          ),
                        ),
                      ),
                    );

                    return Expanded(
                      child: isLast
                          ? Pulse(infinite: true, duration: const Duration(milliseconds: 800),
                              child: cell)
                          : cell,
                    );
                  }),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}