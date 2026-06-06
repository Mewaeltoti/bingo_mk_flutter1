import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/game_cubit.dart';
import '../../core/services/audio_service.dart';
import 'package:bingo_mk/core/l10n/app_strings.dart';
import '../blocs/settings_cubit.dart';
import 'package:bingo_mk/core/theme/app_tokens.dart';


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
        color: AppTokens.bg,
        child: SafeArea(
          child: Column(children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(children: [
                const Icon(Icons.tune_rounded, color: AppTokens.gold, size: 18),
                const SizedBox(width: 10),
                Text(S.settings,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTokens.textHigh,
                      letterSpacing: 0.5,
                    )),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close_rounded, color: AppTokens.textLow, size: 20),
                ),
              ]),
            ),
            Container(height: 0.5, color: AppTokens.divider, margin: const EdgeInsets.symmetric(horizontal: 16)),

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
                            style: AppText.body(size: 13)),
                        backgroundColor: AppTokens.surfaceHigh,
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
                Container(height: 0.5, color: AppTokens.divider),
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
                      color: AppTokens.dangerFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTokens.dangerBorder),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.logout_rounded, color: AppTokens.danger, size: 16),
                      const SizedBox(width: 8),
                      Text(S.signOut,
                          style: AppText.label(size: 12, color: AppTokens.danger, spacing: 1.5)),
                    ]),
                  ),
                ),

                const SizedBox(height: 12),
                Text(S.appVersion,
                    style: AppText.label(size: 10, color: AppTokens.textLow, spacing: 0.3,
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
        color: AppTokens.textLow,
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
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Row(children: [
      Icon(icon, color: value ? AppTokens.gold : AppTokens.textLow, size: 18),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: value ? AppTokens.textHigh : AppTokens.textMid,
            )),
      ),
      Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTokens.gold,
        activeTrackColor: AppTokens.goldFill,
        inactiveThumbColor: AppTokens.textLow,
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
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        Icon(icon, color: AppTokens.textMid, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTokens.textHigh,
              )),
        ),
        Icon(Icons.chevron_right_rounded, color: AppTokens.textLow, size: 18),
      ]),
    ),
  );
}