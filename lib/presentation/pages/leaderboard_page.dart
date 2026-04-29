import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../core/theme/app_theme.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _leaders = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final repo = RepositoryProvider.of<BingoRepository>(context);
    final leaders = await repo.getTopPlayers();
    final history = await repo.getGameHistory();
    if (mounted) {
      setState(() {
        _leaders = leaders;
        _history = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Leaderboard', style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildTabs(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLeadersTab(),
                      _buildHistoryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'TOP PLAYERS'),
          Tab(text: 'GAME HISTORY'),
        ],
      ),
    );
  }

  Widget _buildLeadersTab() {
    if (_leaders.isEmpty) {
      return const Center(child: Text('No winners yet.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaders.length,
      itemBuilder: (context, index) {
        final entry = _leaders[index];
        final isTop = index == 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isTop ? Colors.amber.withOpacity(0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isTop ? Colors.amber.withOpacity(0.3) : AppColors.border),
          ),
          child: Row(
            children: [
              _buildRankBadge(index),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry['displayName'] ?? 'Anonymous',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${entry['wins']} wins',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${entry['totalPrize']} ETB',
                style: const TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankBadge(int index) {
    if (index == 0) return const Icon(Icons.emoji_events, color: Colors.amber, size: 24);
    if (index == 1) return const Icon(Icons.emoji_events, color: Colors.grey, size: 24);
    if (index == 2) return const Icon(Icons.emoji_events, color: Colors.brown, size: 24);
    return CircleAvatar(
      radius: 12,
      backgroundColor: AppColors.background,
      child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(child: Text('No games played yet.', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final game = _history[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      game['pattern'] ?? 'Full House',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const Text('12:30 PM', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    game['winnerName'] != null ? '🏆 ${game['winnerName']}' : 'No winner',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${game['prize']} ETB',
                    style: const TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
