import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/bingo_repository.dart';

class AdminState extends Equatable {
  final bool isDrawing;
  final bool isPaused;
  final String sessionId;
  final int lastDrawn;

  const AdminState({
    this.isDrawing = false, 
    this.isPaused = false,
    this.sessionId = '',
    this.lastDrawn = 0
  });

  @override
  List<Object?> get props => [isDrawing, isPaused, sessionId, lastDrawn];

  AdminState copyWith({
    bool? isDrawing, 
    bool? isPaused,
    String? sessionId,
    int? lastDrawn,
  }) {
    return AdminState(
      isDrawing: isDrawing ?? this.isDrawing,
      isPaused: isPaused ?? this.isPaused,
      sessionId: sessionId ?? this.sessionId,
      lastDrawn: lastDrawn ?? this.lastDrawn,
    );
  }
}

class AdminCubit extends Cubit<AdminState> {
  final BingoRepository _bingoRepository;
  Timer? _timer;
  final List<int> _drawnPool = [];

  AdminCubit(this._bingoRepository) : super(const AdminState());

  String _generateSessionId() {
    return Random().nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }

  Future<void> startGame(String gameId) async {
    if (state.isDrawing && !state.isPaused) return;

    final String sid = state.sessionId.isEmpty ? _generateSessionId() : state.sessionId;
    
    // Update game status to active
    await _bingoRepository.createGame(gameId, {
      'status': 'active',
      'sessionId': sid,
      'isPaused': false,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    emit(state.copyWith(isDrawing: true, isPaused: false, sessionId: sid));

    _timer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (state.isPaused) return;
      
      if (_drawnPool.length >= 75) {
        stopDrawing();
        return;
      }

      int next;
      final random = Random();
      do {
        next = random.nextInt(75) + 1;
      } while (_drawnPool.contains(next));

      _drawnPool.add(next);
      await _bingoRepository.drawNumber(gameId, next);
      emit(state.copyWith(lastDrawn: next));
    });
  }

  Future<void> pauseDrawing(String gameId) async {
    await _bingoRepository.createGame(gameId, {
      'isPaused': true,
      'status': 'paused',
    });
    emit(state.copyWith(isPaused: true));
  }

  Future<void> resumeDrawing(String gameId) async {
    await _bingoRepository.createGame(gameId, {
      'isPaused': false,
      'status': 'active',
    });
    emit(state.copyWith(isPaused: false));
  }

  void stopDrawing() {
    _timer?.cancel();
    _timer = null;
    emit(state.copyWith(isDrawing: false, isPaused: false));
  }

  Future<void> cancelGame(String gameId) async {
    stopDrawing();
    _drawnPool.clear();
    await _bingoRepository.createGame(gameId, {
      'status': 'buying',
      'sessionId': '',
      'drawnNumbers': [],
      'isPaused': false,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    emit(const AdminState());
  }

  Future<void> resetGame(String gameId) async {
    await cancelGame(gameId);
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
