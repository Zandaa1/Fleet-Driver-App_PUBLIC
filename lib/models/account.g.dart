// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppLoginCommand _$AppLoginCommandFromJson(Map<String, dynamic> json) =>
    AppLoginCommand(
      email: json['email'] as String,
      password: json['password'] as String,
      deviceId: json['deviceId'] as String,
    );

Map<String, dynamic> _$AppLoginCommandToJson(AppLoginCommand instance) =>
    <String, dynamic>{
      'email': instance.email,
      'password': instance.password,
      'deviceId': instance.deviceId,
    };

AppLoginResponse _$AppLoginResponseFromJson(Map<String, dynamic> json) =>
    AppLoginResponse(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String,
      userType: AppLoginResponse._intFromJson(json['userType']),
      isDeviceRegistered: json['isDeviceRegistered'] as bool,
      isDeviceBlocked: json['isDeviceBlocked'] as bool,
      token: json['token'] as String?,
    );

Map<String, dynamic> _$AppLoginResponseToJson(AppLoginResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'userType': instance.userType,
      'isDeviceRegistered': instance.isDeviceRegistered,
      'isDeviceBlocked': instance.isDeviceBlocked,
      'token': instance.token,
    };

RegisterDeviceCommand _$RegisterDeviceCommandFromJson(
  Map<String, dynamic> json,
) => RegisterDeviceCommand(
  email: json['email'] as String,
  deviceId: json['deviceId'] as String,
  manufacturer: json['manufacturer'] as String,
  model: json['model'] as String,
  brand: json['brand'] as String,
);

Map<String, dynamic> _$RegisterDeviceCommandToJson(
  RegisterDeviceCommand instance,
) => <String, dynamic>{
  'email': instance.email,
  'deviceId': instance.deviceId,
  'manufacturer': instance.manufacturer,
  'model': instance.model,
  'brand': instance.brand,
};
