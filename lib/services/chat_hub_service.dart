import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'api_service.dart';

class ChatHubService {
  HubConnection? _hubConnection;

  String get _hubUrl {
    final base = ApiService.baseUrl;
    final path = 'api/app/appChatHub';
    final url = base.endsWith('/') ? '$base$path' : '$base/$path';
    return url.replaceAll(RegExp(r'#+$'), '');
  }

  Future<void> connect(String token) async {
    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      return;
    }

    // Use the HTTPS hubUrl. withUrl + skipNegotiation + WebSockets transport 
    // will automatically handle the wss:// connection internally.
    _hubConnection = HubConnectionBuilder()
        .withUrl(
          _hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
            skipNegotiation: true,
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect()
        .build();

    _hubConnection!.onclose(
      ({error}) =>
          debugPrint('SignalR Connection Closed${error != null ? ': $error' : ''}'),
    );

    try {
      await _hubConnection!.start();
      debugPrint('SignalR Connected (WebSocket-only mode)');
    } catch (e) {
      debugPrint('SignalR Connection Failed: $e');
      rethrow;
    }
  }

  void onMessageReceived(void Function(List<Object?>?) callback) {
    _hubConnection?.on("ReceiveMessage", callback);
  }

  void offMessageReceived(void Function(List<Object?>?) callback) {
    _hubConnection?.off("ReceiveMessage", method: callback);
  }

  Future<void> disconnect() async {
    await _hubConnection?.stop();
  }
}

final chatHubService = ChatHubService();
