import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/game_cubit.dart';
import '../../core/services/audio_service.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import '../blocs/settings_cubit.dart';

class _C {
  static bool get _l => SettingsCubit.isLightModeGlobal;

  static Color get bg          => _l ? const Color(0xFFF2F4F7) : const Color(0xFF090E1C);
  static Color get surface     => _l ? const Color(0xFFFFFFFF) : const Color(0xFF161B2A);
  static Color get surfaceHigh => _l ? const Color(0xFFF9FAFB) : const Color(0xFF1A1F2E);
  static Color get divider     => _l ? const Color(0xFFEAECF0) : const Color(0xFF303444);

  static const gold        = Color(0xFFF1C100);
  static const goldFill    = Color(0x1AF1C100);
  static const goldBorder  = Color(0x40F1C100);

  static const danger      = Color(0xFFE63946);
  static const dangerFill  = Color(0x1AE63946);
  static const dangerBorder= Color(0x40E63946);

  static Color get textHigh => _l ? const Color(0xFF101828) : const Color(0xFFDEE2F6);
  static Color get textMid  => _l ? const Color(0xFF475467) : const Color(0xFFD1C5AB);
  static Color get textLow  => _l ? const Color(0xFF667085) : const Color(0xFF9A9078);
}

class _T {
  static TextStyle label({double size = 11, Color? color, double spacing = 0.8, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, letterSpacing: spacing, color: color ?? _C.textMid);
  static TextStyle body({double size = 13, Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'Outfit', fontSize: size, fontWeight: weight, color: color ?? _C.textHigh);
}

class SettingsDrawer extends StatefulWidget {
  final VoidCallback onClose;
  const SettingsDrawer({super.key, required this.onClose});

  @override State<SettingsDrawer> createState() => _SettingsDrawerState();
}



class _SettingsDrawerState extends State<SettingsDrawer> {
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = !AudioService().isMuted;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameCubit>().state;
    final settingsState = context.watch<SettingsCubit>().state;
    final isAutoDaub = gameState is GameLoaded ? gameState.isAutoDaubEnabled : false;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        color: _C.bg,
        child: SafeArea(
          child: Column(children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(children: [
                const Icon(Icons.tune_rounded, color: _C.gold, size: 18),
                const SizedBox(width: 10),
                Text(S.settings,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _C.textHigh,
                      letterSpacing: 0.5,
                    )),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close_rounded, color: _C.textLow, size: 20),
                ),
              ]),
            ),
            Container(height: 0.5, color: _C.divider, margin: const EdgeInsets.symmetric(horizontal: 16)),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  _SectionLabel(S.preferences),
                  const SizedBox(height: 8),

                  _ToggleTile(
                    icon: Icons.volume_up_rounded,
                    label: S.soundEffects,
                    value: _soundEnabled,
                    onChanged: (v) {
                      setState(() => _soundEnabled = v);
                      AudioService().toggleMute();
                    },
                  ),
                  const SizedBox(height: 8),

                  _ToggleTile(
                    icon: Icons.language_rounded,
                    label: S.isAmharic ? 'English' : 'አማርኛ',
                    value: settingsState.isAmharic,
                    onChanged: (v) => context.read<SettingsCubit>().toggleLanguage(),
                  ),
                  const SizedBox(height: 8),

                  _ToggleTile(
                    icon: settingsState.isLightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    label: settingsState.isLightMode ? 'Dark Mode' : 'Light Mode',
                    value: settingsState.isLightMode,
                    onChanged: (v) => context.read<SettingsCubit>().toggleTheme(),
                  ),

                  if (gameState is GameLoaded) ...[
                    const SizedBox(height: 8),
                    _ToggleTile(
                      icon: Icons.brightness_auto_rounded,
                      label: S.autoDaubSetting,
                      value: isAutoDaub,
                      onChanged: (v) => context.read<GameCubit>().toggleAutoDaub(v),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _SectionLabel(S.support),
                  const SizedBox(height: 8),

                  _ActionTile(
                    icon: Icons.headset_mic_rounded,
                    label: S.contactSupport,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.callSupport,
                            style: _T.body(size: 13)),
                        backgroundColor: _C.surfaceHigh,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [
                Container(height: 0.5, color: _C.divider),
                const SizedBox(height: 16),

                // Sign out
                GestureDetector(
                  onTap: () {
                    widget.onClose();
                    context.read<AuthCubit>().logout();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _C.dangerFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.dangerBorder),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.logout_rounded, color: _C.danger, size: 16),
                      const SizedBox(width: 8),
                      Text(S.signOut,
                          style: _T.label(size: 12, color: _C.danger, spacing: 1.5)),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),
                Text(S.appVersion,
                    style: _T.label(size: 10, color: _C.textLow, spacing: 0.3,
                        weight: FontWeight.w400)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Components ───────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.0,
        color: _C.textLow,
      ));
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon, required this.label,
    required this.value, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(children: [
      Icon(icon, color: value ? _C.gold : _C.textLow, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: value ? _C.textHigh : _C.textMid,
            )),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: _C.gold,
        activeTrackColor: _C.goldFill,
        inactiveThumbColor: _C.textLow,
        inactiveTrackColor: Colors.white.withOpacity(0.05),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        Icon(icon, color: _C.textMid, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _C.textHigh,
              )),
        ),
        Icon(Icons.chevron_right_rounded, color: _C.textLow, size: 18),
      ]),
    ),
  );
}