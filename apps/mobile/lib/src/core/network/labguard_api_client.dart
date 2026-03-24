import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_session_store.dart';
import '../../features/auth/domain/auth_session.dart';
import '../config/app_environment.dart';

final labGuardApiClientProvider = Provider<Dio>((ref) {
  final sessionStore = ref.watch(authSessionStoreProvider);
  final client = Dio(_baseOptions());
  final refreshClient = Dio(_baseOptions());
  Future<AuthSession?>? refreshOperation;

  client.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['skipAuth'] == true) {
          handler.next(options);
          return;
        }

        final session = await sessionStore.readSession();
        if (session != null && session.accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }

        handler.next(options);
      },
      onError: (error, handler) async {
        final requestOptions = error.requestOptions;

        if (_shouldRefresh(error)) {
          refreshOperation ??= _refreshSession(sessionStore, refreshClient);
          final refreshedSession = await refreshOperation;
          refreshOperation = null;

          if (refreshedSession != null) {
            try {
              final response = await _replayRequest(
                client,
                requestOptions,
                accessToken: refreshedSession.accessToken,
                markRefreshed: true,
              );
              handler.resolve(response);
              return;
            } on DioException catch (retryError) {
              handler.next(retryError);
              return;
            }
          }

          ref.read(authSessionInvalidationProvider.notifier).state++;
        }

        if (_shouldRetry(error)) {
          try {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            final response = await _replayRequest(
              client,
              requestOptions,
              retryCount: (requestOptions.extra['retryCount'] as int? ?? 0) + 1,
            );
            handler.resolve(response);
            return;
          } on DioException catch (retryError) {
            handler.next(retryError);
            return;
          }
        }

        handler.next(error);
      },
    ),
  );

  ref.onDispose(client.close);
  ref.onDispose(refreshClient.close);
  return client;
});

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: AppEnvironment.apiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    sendTimeout: const Duration(seconds: 12),
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  );
}

bool _shouldRefresh(DioException error) {
  final requestOptions = error.requestOptions;

  return error.response?.statusCode == 401 &&
      requestOptions.extra['skipAuth'] != true &&
      requestOptions.extra['authRefreshed'] != true;
}

bool _shouldRetry(DioException error) {
  final requestOptions = error.requestOptions;
  final retryCount = requestOptions.extra['retryCount'] as int? ?? 0;
  final method = requestOptions.method.toUpperCase();
  final isSafeMethod = method == 'GET' || method == 'HEAD';
  final isTransientStatus = (error.response?.statusCode ?? 0) >= 500;
  final isTransientType =
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  return requestOptions.extra['noRetry'] != true &&
      requestOptions.extra['skipRetry'] != true &&
      retryCount < 1 &&
      isSafeMethod &&
      (isTransientStatus || isTransientType);
}

Future<Response<dynamic>> _replayRequest(
  Dio client,
  RequestOptions requestOptions, {
  String? accessToken,
  int? retryCount,
  bool markRefreshed = false,
}) {
  final nextHeaders = Map<String, dynamic>.from(requestOptions.headers);
  if (accessToken != null && accessToken.isNotEmpty) {
    nextHeaders['Authorization'] = 'Bearer $accessToken';
  }

  final nextExtra = Map<String, dynamic>.from(requestOptions.extra);
  if (retryCount != null) {
    nextExtra['retryCount'] = retryCount;
  }
  if (markRefreshed) {
    nextExtra['authRefreshed'] = true;
  }

  return client.fetch<dynamic>(
    requestOptions.copyWith(headers: nextHeaders, extra: nextExtra),
  );
}

Future<AuthSession?> _refreshSession(
  AuthSessionStore sessionStore,
  Dio refreshClient,
) async {
  final existingSession = await sessionStore.readSession();

  if (existingSession == null || existingSession.refreshToken.isEmpty) {
    await sessionStore.clearSession();
    return null;
  }

  try {
    final response = await refreshClient.post<Map<String, dynamic>>(
      '/v1/auth/refresh',
      data: {'refreshToken': existingSession.refreshToken},
      options: Options(extra: const {'skipAuth': true, 'skipRetry': true}),
    );
    final payload = response.data;

    if (payload == null) {
      return null;
    }

    final refreshedSession = existingSession.copyWith(
      accessToken:
          payload['accessToken'] as String? ?? existingSession.accessToken,
      refreshToken:
          payload['refreshToken'] as String? ?? existingSession.refreshToken,
      expiresInSeconds:
          payload['expiresInSeconds'] as int? ??
          existingSession.expiresInSeconds,
      viewer: AuthViewer.fromJson(
        (payload['session'] as Map<String, dynamic>? ?? const {})['viewer']
                as Map<String, dynamic>? ??
            const {},
      ),
      account: AuthAccount.fromJson(
        (payload['session'] as Map<String, dynamic>? ?? const {})['account']
                as Map<String, dynamic>? ??
            const {},
      ),
      device: AuthDevice.fromJson(
        (payload['session'] as Map<String, dynamic>? ?? const {})['device']
                as Map<String, dynamic>? ??
            const {},
      ),
    );

    await sessionStore.writeSession(refreshedSession);
    return refreshedSession;
  } on DioException catch (error) {
    if (error.response?.statusCode == 401) {
      await sessionStore.clearSession();
    }
    return null;
  }
}
