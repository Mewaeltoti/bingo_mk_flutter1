import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/bingo_card.dart';
import '../blocs/admin_cubit.dart';
import '../blocs/auth_cubit.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPattern = 'Full House';
  final double _cartelaPrice = 10.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Bingo Ethio Admin',
          style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGameTab(),
                _buildDepositsTab(),
                _buildWithdrawalsTab(),
                _buildPlayersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(text: 'GAME'),
          Tab(text: 'DEPOSITS'),
          Tab(text: 'WITHDRAWALS'),
          Tab(text: 'PLAYERS'),
        ],
      ),
    );
  }

  Widget _buildGameTab() {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('WINNING PATTERN'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BingoPattern.values.map((p) {
                final bool isSelected = _selectedPattern == p.name;
                return ChoiceChip(
                  label: Text(
                    p.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedPattern = p.name),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.card,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('GAME SETTINGS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    'Cartela Price',
                    '${_cartelaPrice.toInt()} ETB',
                    Icons.shopping_cart,
                  ),
                  const Divider(color: AppColors.border),
                  _buildSettingRow('Draw Speed', '5s (Auto)', Icons.timer),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildActionButtons(state),
            const SizedBox(height: 12),
            _buildAdminButton(
              label: 'INITIALIZE SYSTEM',
              icon: Icons.settings_power,
              color: Colors.purpleAccent,
              onPressed: () => context.read<BingoRepository>().initializeGame(),
            ),
            if (state.isDrawing) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('STATUS: DRAWING NUMBERS'),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 4),
                  ),
                  child: Text(
                    '${state.lastDrawn}',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontFamily: 'Orbitron',
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons(AdminState state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAdminButton(
                label: state.isDrawing 
                    ? (state.isPaused ? 'RESUME' : 'PAUSE') 
                    : 'START GAME',
                icon: state.isDrawing 
                    ? (state.isPaused ? Icons.play_arrow : Icons.pause) 
                    : Icons.play_arrow,
                color: state.isDrawing 
                    ? (state.isPaused ? Colors.greenAccent : Colors.orangeAccent) 
                    : Colors.greenAccent,
                onPressed: () {
                  if (!state.isDrawing) {
                    context.read<AdminCubit>().startGame('current_game');
                  } else if (state.isPaused) {
                    context.read<AdminCubit>().resumeDrawing('current_game');
                  } else {
                    context.read<AdminCubit>().pauseDrawing('current_game');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdminButton(
                label: 'CANCEL GAME',
                icon: Icons.cancel,
                color: Colors.redAccent,
                onPressed: () => context.read<AdminCubit>().cancelGame('current_game'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildAdminButton(
          label: 'RESET SYSTEM',
          icon: Icons.refresh,
          color: Colors.blueAccent,
          onPressed: () => context.read<AdminCubit>().resetGame('current_game'),
        ),
      ],
    );
  }

  Widget _buildAdminButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepositsTab() {
    return const Center(
      child: Text(
        'Manage User Deposits',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildWithdrawalsTab() {
    return const Center(
      child: Text(
        'Manage User Withdrawals',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildPlayersTab() {
    return const Center(
      child: Text(
        'Player Stats & Management',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
