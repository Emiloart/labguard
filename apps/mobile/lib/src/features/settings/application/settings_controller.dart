import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/android_background_runtime_bridge.dart';
import '../data/settings_repository.dart';
import '../domain/settings_bundle.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsBundle>(
      SettingsController.new,
    );

class SettingsController extends AsyncNotifier<SettingsBundle> {
  @override
  Future<SettingsBundle> build() async {
    final settings = await ref
        .watch(settingsRepositoryProvider)
        .fetchSettings();
    await _syncRuntimePreferences(settings.preferences);
    return settings;
  }

  Future<void> updatePreferences(
    SecurityPreferences Function(SecurityPreferences current) mutate,
  ) async {
    final current = state.valueOrNull;

    if (current == null) {
      state = await AsyncValue.guard(
        () => ref.read(settingsRepositoryProvider).fetchSettings(),
      );
      return;
    }

    final optimistic = current.copyWith(
      preferences: mutate(current.preferences),
    );

    state = AsyncValue.data(optimistic);
    state = await AsyncValue.guard(
      () => ref
          .read(settingsRepositoryProvider)
          .updatePreferences(optimistic.preferences),
    );

    final synchronized = state.valueOrNull;

    if (synchronized != null) {
      await _syncRuntimePreferences(synchronized.preferences);
    }
  }

  Future<void> _syncRuntimePreferences(SecurityPreferences preferences) {
    return ref
        .read(androidBackgroundRuntimeBridgeProvider)
        .syncRuntimePreferences(
          notificationsEnabled: preferences.notificationsEnabled,
          autoConnectEnabled: preferences.autoConnectEnabled,
        );
  }
}
