import 'package:get_it/get_it.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/bingo_repository.dart';
import '../../data/repositories/auth_repository_firebase.dart';
import '../../data/repositories/bingo_repository_firebase.dart';
import 'audio_service.dart';
import 'card_generator_service.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Services
  sl.registerLazySingleton<AudioService>(() => AudioService());
  sl.registerLazySingleton<CardGeneratorService>(() => CardGeneratorService());

  // Repositories — Firebase implementations
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryFirebase());
  sl.registerLazySingleton<BingoRepository>(() => BingoRepositoryFirebase());
}
