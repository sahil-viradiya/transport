import 'package:dio/dio.dart';
import 'package:transport/widgets/dialogs/app_snackbar.dart';

class ApiProvider {
  late final Dio _dio;

  ApiProvider() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://jsonplaceholder.typicode.com', // Mock API Base URL
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Logging & Header Interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // You can retrieve JWT tokens from SharedPreferences if available
          // options.headers['Authorization'] = 'Bearer $token';
          print('--> ${options.method} ${options.path}');
          print('Headers: ${options.headers}');
          print('Body: ${options.data}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('<-- ${response.statusCode} ${response.requestOptions.path}');
          print('Response: ${response.data}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          final errorMessage = AppErrorHandler.handleError(e);
          AppSnackBar.showError(title: 'API Error', message: errorMessage);
          return handler.next(e);
        },
      ),
    );
  }

  // GET Request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters, options: options);
    } on DioException {
      rethrow;
    }
  }

  // POST Request
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException {
      rethrow;
    }
  }
}

class AppErrorHandler {
  AppErrorHandler._();

  static String handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout with the server. Please try again.';
      case DioExceptionType.sendTimeout:
        return 'Send timeout. Please check your internet connectivity.';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout. Server is taking too long to respond.';
      case DioExceptionType.badCertificate:
        return 'Secure connection verification failed (Bad Certificate).';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final data = error.response?.data;
        if (status != null) {
          switch (status) {
            case 400:
              return _getErrorMessage(data) ?? 'Bad Request. Invalid parameters.';
            case 401:
              return 'Unauthorized. Access denied.';
            case 403:
              return 'Forbidden. You do not have permission.';
            case 404:
              return 'Resource not found.';
            case 500:
              return 'Internal Server Error. Please contact support.';
            case 503:
              return 'Service unavailable. Server is temporarily down.';
            default:
              return 'Received error status code: $status';
          }
        }
        return 'Bad response from the server.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please verify your network settings.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static String? _getErrorMessage(dynamic data) {
    if (data is Map && data.containsKey('message')) {
      return data['message'].toString();
    }
    return null;
  }
}
