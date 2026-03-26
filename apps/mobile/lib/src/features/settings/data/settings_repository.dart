import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/settings_bundle.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(client: ref.watch(labGuardApiClientProvider));
});

class SettingsRepository {
  SettingsRepository({required Dio client}) : _client = client;

  final Dio _client;

  Future<SettingsBundle> fetchSettings() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/v1/preferences/me',
      );
      final payload = response.data;

      if (payload == null) {
        throw const ApiException('The settings payload was empty.');
      }

      return SettingsBundle.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(error.message ?? 'Unable to load LabGuard settings.');
    }
  }

  Future<SettingsBundle> updatePreferences(
    SecurityPreferences preferences, {
    String? appPin,
    bool clearAppPin = false,
  }) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/v1/preferences/me',
        data: {
          ...preferences.toJson(),
          ...?(appPin == null ? null : {'appPin': appPin}),
          if (clearAppPin) 'appPin': null,
        },
      );
      final payload = response.data;

      if (payload == null) {
        throw const ApiException('The settings update response was empty.');
      }

      return SettingsBundle.fromJson(payload);
    } on DioException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to update LabGuard settings.',
      );
    }
  }
}
