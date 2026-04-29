import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth_cubit.dart';
import '../blocs/wallet_cubit.dart';
import '../pages/profile_page.dart';
import '../pages/leaderboard_page.dart';
import '../../core/theme/app_theme.dart';

class SettingsDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const SettingsDrawer({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('PREFERENCES'),
                  _buildToggleItem(
                    Icons.volume_up,
                    'Sound Effects',
                    true,
                    (val) {},
                  ),
                  _buildToggleItem(
                    Icons.dark_mode,
                    'Dark Mode',
                    true,
                    (val) {},
                  ),
                  _buildLanguageItem(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('ACCOUNT'),
                  _buildActionItem(Icons.person, 'Profile', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<WalletCubit>(),
                          child: const ProfilePage(),
                        ),
                      ),
                    );
                  }),
                  _buildActionItem(Icons.leaderboard, 'Leaderboard', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardPage(),
                      ),
                    );
                  }),
                  _buildActionItem(Icons.help_outline, 'Support', () {}),
                  const SizedBox(height: 24),
                  _buildLogoutButton(context),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0 (Bingo Ethio)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    IconData icon,
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildLanguageItem() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.language,
        color: AppColors.textSecondary,
        size: 20,
      ),
      title: const Text(
        'Language',
        style: TextStyle(fontSize: 14, color: Colors.white),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'EN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary,
        size: 20,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.read<AuthCubit>().logout(),
        icon: const Icon(Icons.logout, size: 16),
        label: const Text('LOG OUT'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
