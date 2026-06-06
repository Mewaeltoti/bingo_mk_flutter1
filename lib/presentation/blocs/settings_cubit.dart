import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/l10n/app_strings.dart';

class SettingsState {
  final bool isAmharic;
  final bool isLightMode;

  const SettingsState({this.isAmharic = true, this.isLightMode = false});

  SettingsState copyWith({bool? isAmharic, bool? isLightMode}) {
    return SettingsState(
      isAmharic: isAmharic ?? this.isAmharic,
      isLightMode: isLightMode ?? this.isLightMode,
    );
  }
}

class SettingsCubit extends Cubit<SettingsState> {
  static bool isLightModeGlobal = false;

  SettingsCubit() : super(const SettingsState()) {
    // Sync initial state with AppStrings
    S.isAmharic = state.isAmharic;
    isLightModeGlobal = state.isLightMode;
  }

  void toggleLanguage() {
    final newState = !state.isAmharic;
    S.isAmharic = newState;
    emit(state.copyWith(isAmharic: newState));
  }

  void toggleTheme() {
    final newState = !state.isLightMode;
    isLightModeGlobal = newState;
    emit(state.copyWith(isLightMode: newState));
  }
}
