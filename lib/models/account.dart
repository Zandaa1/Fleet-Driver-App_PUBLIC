import 'package:json_annotation/json_annotation.dart';

part 'account.g.dart';

@JsonSerializable()
class AppLoginCommand {
  final String email;
  final String password;
  final String deviceId;

  AppLoginCommand({
    required this.email,
    required this.password,
    required this.deviceId,
  });

  factory AppLoginCommand.fromJson(Map<String, dynamic> json) =>
      _$AppLoginCommandFromJson(json);
  Map<String, dynamic> toJson() => _$AppLoginCommandToJson(this);
}

@JsonSerializable()
class AppLoginResponse {
  final String id;
  final String email;
  final String fullName;
  @JsonKey(fromJson: _intFromJson)
  final int userType;
  final bool isDeviceRegistered;
  final bool isDeviceBlocked;
  final String? token;

  AppLoginResponse({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    required this.isDeviceRegistered,
    required this.isDeviceBlocked,
    this.token,
  });

  static int _intFromJson(dynamic json) {
    if (json is num) return json.toInt();
    if (json is String) return int.tryParse(json) ?? 0;
    return 0;
  }

  factory AppLoginResponse.fromJson(Map<String, dynamic> json) =>
      _$AppLoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AppLoginResponseToJson(this);
}

@JsonSerializable()
class RegisterDeviceCommand {
  final String email;
  final String deviceId;
  final String manufacturer;
  final String model;
  final String brand;

  RegisterDeviceCommand({
    required this.email,
    required this.deviceId,
    required this.manufacturer,
    required this.model,
    required this.brand,
  });

  factory RegisterDeviceCommand.fromJson(Map<String, dynamic> json) =>
      _$RegisterDeviceCommandFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterDeviceCommandToJson(this);
}
