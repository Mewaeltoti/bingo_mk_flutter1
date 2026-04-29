import 'package:flutter/material.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../data/repositories/bingo_repository_impl.dart';
import '../../core/theme/app_theme.dart';
import 'dart:math';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final BingoRepository _bingoRepository = BingoRepositoryImpl();
  final List<int> _calledNumbers = [];
  final String _gameId = 'test-game-123';

  void _callNextNumber() {
    if (_calledNumbers.length >= 75) return;

    final random = Random();
    int next;
    do {
      next = random.nextInt(75) + 1;
    } while (_calledNumbers.contains(next));

    setState(() {
      _calledNumbers.add(next);
    });

    _bingoRepository.drawNumber(_gameId, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _callNextNumber,
              child: const Text('CALL NEXT NUMBER'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                ),
                itemCount: 75,
                itemBuilder: (context, index) {
                  final n = index + 1;
                  final isCalled = _calledNumbers.contains(n);
                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isCalled ? AppColors.accent : Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        n.toString(),
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
