import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/labguard_api_client.dart';
import '../domain/about_runtime_status.dart';

final aboutRuntimeStatusProvider = FutureProvider<AboutRuntimeStatus>((ref) async {
  final client = ref.watch(labGuardApiClientProvider);

  try {
    final response = await client.get<Map<String, dynamic>>(
      '/v1/health',
      options: Options(
        extra: const {
          'skipAuth': true,
          'skipRetry': true,
        },
      ),
    );

    return AboutRuntimeStatus.fromJson(response.data ?? const {});
  } on DioException catch (error) {
    throw ApiException(
      error.message ?? 'Unable to reach the LabGuard service status.',
    );
  }
});
