import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/trip.dart';
import '../models/chat.dart';

class ApiService {
  late final Dio _dio;
  String? _token;
  static const String _tokenKey = 'auth_token';
  static const String _spoofedIdKey = 'spoofed_device_id';
  static bool _offlineTestModeEnabled = false;
  static bool _offlineUiTestModeEnabled = false;
  static String? _spoofedDeviceId;
  static final ValueNotifier<bool> offlineUiTestModeNotifier =
      ValueNotifier<bool>(false);
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'https://example.invalid/',
  );
  static const String maintenanceMessage =
      'Server is under maintenance. Please try again shortly.';
  static const String offlineMessage =
      'No internet connection. Please check your network and try again.';

  static bool get offlineTestModeEnabled => _offlineTestModeEnabled;

  static bool get offlineUiTestModeEnabled => _offlineUiTestModeEnabled;

  static bool get usesOfflineUiFakeData =>
      _offlineTestModeEnabled && _offlineUiTestModeEnabled;

  static String? get spoofedDeviceId => _spoofedDeviceId;

  static void setOfflineTestModeEnabled(bool enabled) {
    _offlineTestModeEnabled = enabled;
    offlineUiTestModeNotifier.value = usesOfflineUiFakeData;
  }

  static void setOfflineUiTestModeEnabled(bool enabled) {
    _offlineUiTestModeEnabled = enabled;
    offlineUiTestModeNotifier.value = usesOfflineUiFakeData;
  }

  static Future<void> setSpoofedDeviceId(String? id) async {
    if (kReleaseMode) return;
    _spoofedDeviceId = id;
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_spoofedIdKey);
    } else {
      await prefs.setString(_spoofedIdKey, id);
    }
  }

  static Future<void> _loadSpoofedId() async {
    if (kReleaseMode) return;
    final prefs = await SharedPreferences.getInstance();
    _spoofedDeviceId = prefs.getString(_spoofedIdKey);
  }

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );


    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_offlineTestModeEnabled && !_offlineUiTestModeEnabled) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'Offline mode test is enabled by admin tools.',
              ),
            );
            return;
          }

          handler.next(options);
        },
      ),
    );

    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseBody: false,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );

    // Token interceptor can be added here once storage is implemented
  }

  void setToken(String token) {
    _token = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> loadSavedToken() async {
    await _loadSpoofedId();
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    if (savedToken != null && savedToken.isNotEmpty) {
      _token = savedToken;
      _dio.options.headers['Authorization'] = 'Bearer $savedToken';
    }
  }

  Future<void> logout() async {
    _token = null;
    _dio.options.headers.remove('Authorization');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  String? get token => _token;

  bool isUnauthorized(dynamic e) {
    if (e is DioException) {
      return e.response?.statusCode == 401;
    }
    return false;
  }

  // Account
  Future<AppLoginResponse> login(AppLoginCommand command) async {
    if (usesOfflineUiFakeData) {
      return AppLoginResponse(
        id: 'ui-test-user-001',
        email: command.email.isEmpty
            ? 'ui.test@example.invalid'
            : command.email,
        fullName: 'UI Test Driver',
        userType: 0,
        isDeviceRegistered: true,
        isDeviceBlocked: false,
        token: 'ui-test-token',
      );
    }

    final response = await _dio.post('/api/app/Account/login', data: command.toJson());
    return AppLoginResponse.fromJson(response.data);
  }

  Future<void> registerDevice(RegisterDeviceCommand command) async {
    if (usesOfflineUiFakeData) return;
    await _dio.post('/api/app/Account/register-device', data: command.toJson());
  }

  Future<AppLoginResponse> getMe() async {
    if (usesOfflineUiFakeData) {
      return AppLoginResponse(
        id: 'ui-test-user-001',
        email: 'ui.test@example.invalid',
        fullName: 'UI Test Driver',
        userType: 0,
        isDeviceRegistered: true,
        isDeviceBlocked: false,
        token: _token ?? 'ui-test-token',
      );
    }

    final response = await _dio.get('/api/app/Account/me');
    return AppLoginResponse.fromJson(response.data);
  }

  /// Returns the effective device ID.
  /// Uses spoofed ID if set and not in release mode, otherwise gets real hardware ID.
  Future<String?> getDeviceId() async {
    if (!kReleaseMode && _spoofedDeviceId != null) {
      return _spoofedDeviceId;
    }

    final deviceInfo = DeviceInfoPlugin();
    const androidIdPlugin = AndroidId();

    try {
      if (kIsWeb) {
        return 'Web';
      } else if (Platform.isAndroid) {
        return await androidIdPlugin.getId();
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      } else {
        final info = await deviceInfo.deviceInfo;
        return info.data['id']?.toString();
      }
    } catch (_) {
      return null;
    }
  }

  // Trips
  Future<CrewDashboardDto> getDashboard() async {
    if (usesOfflineUiFakeData) {
      final now = DateTime.now();
      return CrewDashboardDto(
        crewName: 'UI Test Driver',
        ongoingTrip: CrewTripDto(
          id: 'trip-ui-ongoing-001',
          status: 'in_progress',
          truckPlateNumber: 'UI-1234',
          jobId: 'JOB-UI-001',
          dispatchOriginTime: 'Demo Origin',
          destinationName: 'Demo Warehouse',
          destinationAddress: 'Demo Destination',
          scheduledDate: now,
        ),
        upcomingTrips: <CrewTripDto>[
          CrewTripDto(
            id: 'trip-ui-upcoming-001',
            status: 'upcoming',
            truckPlateNumber: 'UI-9231',
            jobId: 'JOB-UI-002',
            dispatchOriginTime: 'Demo Depot',
            destinationName: 'Demo Yard',
            destinationAddress: 'Demo Destination',
            scheduledDate: now.add(const Duration(days: 1)),
          ),
        ],
        tripHistory: <CrewTripDto>[
          CrewTripDto(
            id: 'trip-ui-history-001',
            status: 'completed',
            truckPlateNumber: 'UI-4502',
            jobId: 'JOB-UI-000',
            dispatchOriginTime: 'Demo Yard',
            destinationName: 'Demo Drop-Off',
            destinationAddress: 'Demo Destination',
            scheduledDate: now.subtract(const Duration(days: 2)),
          ),
        ],
      );
    }

    final response = await _dio.get('/api/app/Trips/dashboard');

    return CrewDashboardDto.fromJson(response.data);
  }

  Future<ActiveTripDto> getActiveTrip() async {
    if (usesOfflineUiFakeData) {
      return ActiveTripDto(
        id: 'trip-ui-ongoing-001',
        truckPlateNumber: 'UI-1234',
        jobId: 'JOB-UI-001',
        destinationName: 'Demo Warehouse',
        destinationAddress: 'Demo Destination',
        destinationLatitude: 0.001,
        destinationLongitude: 0.001,
        currentLatitude: 0.001,
        currentLongitude: 0.001,
        lastLocationUpdate: DateTime.now(),
        distanceKm: 8.4,
        departureTime: DateTime.now().subtract(const Duration(minutes: 18)),
        estimatedDurationMinutes: 24,
        isPaused: false,
        adminInstructions:
            'UI test mode: proceed to destination and verify flow.',
        pickupName: 'Demo Origin',
        pickupAddress: 'Demo Origin',
      );
    }

    final response = await _dio.get('/api/app/Trips/active');
    return ActiveTripDto.fromJson(response.data);
  }

  Future<void> startTrip(String id, StartTripRequest request) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/start', data: request.toJson());
  }

  Future<void> updateLocation(
    String id,
    UpdateTripLocationRequest request,
  ) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/location', data: request.toJson());
  }

  Future<void> pauseTrip(String id, bool pause) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post(
      '/api/app/Trips/$id/pause',
      data: pause,
      options: Options(contentType: 'application/json'),
    );
  }

  Future<void> addExpense(String id, AddTripExpenseRequest request) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/expense', data: request.toJson());
  }

  Future<void> reportIncident(String id, ReportIncidentRequest request) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/incident', data: request.toJson());
  }

  Future<void> submitCheckpoint(
    String id,
    SubmitCheckpointRequest request,
  ) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/checkpoint', data: request.toJson());
  }

  Future<void> completeTrip(String id, CompleteTripRequest request) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/complete', data: request.toJson());
  }

  Future<void> triggerSos(String id, TriggerSosRequest request) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Trips/$id/sos', data: request.toJson());
  }

  Future<Map<String, dynamic>> getTripHistoryOutput(String tripId) async {
    if (usesOfflineUiFakeData) {
      return <String, dynamic>{
        'id': tripId,
        'status': 'completed',
        'notes': 'UI test mode generated payload',
      };
    }

    final response = await _dio.get('/api/dashboard/trips/$tripId');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: 'Unexpected trip history response format',
    );
  }

  // Chat
  Future<List<AppConversationDto>> getConversations({String? search}) async {
    if (usesOfflineUiFakeData) {
      final now = DateTime.now();
      return <AppConversationDto>[
        AppConversationDto(
          id: 'conv-ui-001',
          lastMessageText: 'This is a UI test conversation.',
          lastMessageAt: now,
          unreadCount: 0,
          dateCreated: now.subtract(const Duration(days: 1)),
        ),
      ];
    }

    final response = await _dio.get(
      '/api/app/Chat',
      queryParameters: {'search': search},
    );
    return (response.data as List)
        .map((e) => AppConversationDto.fromJson(e))
        .toList();
  }

  Future<String> createConversation() async {
    if (usesOfflineUiFakeData) {
      return 'conv-ui-001';
    }

    final response = await _dio.post('/api/app/Chat');
    return response.data as String;
  }

  Future<PagedResponseOfAppChatMessageDto> getMessages(
    String id, {
    int page = 1,
    int pageSize = 50,
  }) async {
    if (usesOfflineUiFakeData) {
      final now = DateTime.now();
      return PagedResponseOfAppChatMessageDto(
        items: <AppChatMessageDto>[
          AppChatMessageDto(
            id: 'msg-ui-001',
            senderId: 'dispatcher-ui-001',
            senderName: 'Dispatch (UI Test)',
            content: 'UI test mode is enabled. Backend is bypassed.',
            isRead: true,
            isMine: false,
            dateCreated: now.subtract(const Duration(minutes: 5)),
          ),
        ],
        totalCount: 1,
        page: page,
        pageSize: pageSize,
      );
    }

    final response = await _dio.get(
      '/api/app/Chat/$id/messages',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return PagedResponseOfAppChatMessageDto.fromJson(response.data);
  }

  Future<void> sendMessage(String id, SendAppMessageRequest request) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Chat/$id/messages', data: request.toJson());
  }

  Future<void> markAsRead(String id) async {
    if (usesOfflineUiFakeData) {
      return;
    }

    await _dio.post('/api/app/Chat/$id/read');
  }

  Future<String> getErrorMessage(DioException e) async {
    if (_offlineTestModeEnabled && !_offlineUiTestModeEnabled) {
      return offlineMessage;
    }

    if (isUnauthorized(e)) {
      return 'Your session has expired. Please log in again.';
    }

    if (e.response?.statusCode == 429) {
      return 'Too many login attempts. Please wait a few minutes before trying again.';
    }

    final responseData = e.response?.data;
    if (responseData is Map && responseData['errors'] is List) {
      final errors = (responseData['errors'] as List)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      if (errors.isNotEmpty) {
        return errors.join('\n');
      }
    }

    if (e.response?.statusCode == 503) {
      return maintenanceMessage;
    }

    final isConnectivityError =
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout;

    if (isConnectivityError && e.response == null) {
      final hasInternet = await _hasInternetConnection();
      return hasInternet ? maintenanceMessage : offlineMessage;
    }

    if (e.response?.statusCode != null) {
      return 'Server error: ${e.response!.statusCode}';
    }

    return e.message ?? 'Request failed. Please try again.';
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }
}
