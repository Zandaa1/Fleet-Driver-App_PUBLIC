import 'package:json_annotation/json_annotation.dart';

part 'trip.g.dart';

@JsonSerializable()
class ActiveTripDto {
  final String id;
  final String truckPlateNumber;
  final String jobId;
  final String destinationName;
  final String destinationAddress;
  @JsonKey(fromJson: _doubleFromJson)
  final double destinationLatitude;
  @JsonKey(fromJson: _doubleFromJson)
  final double destinationLongitude;
  @JsonKey(fromJson: _doubleNullableFromJson)
  final double? currentLatitude;
  @JsonKey(fromJson: _doubleNullableFromJson)
  final double? currentLongitude;
  final DateTime? lastLocationUpdate;
  @JsonKey(fromJson: _doubleNullableFromJson)
  final double? distanceKm;
  final DateTime? departureTime;
  @JsonKey(fromJson: _intNullableFromJson)
  final int? estimatedDurationMinutes;
  final bool isPaused;
  final String? adminInstructions;
  final String pickupName;
  final String? pickupAddress;

  ActiveTripDto({
    required this.id,
    required this.truckPlateNumber,
    required this.jobId,
    required this.destinationName,
    required this.destinationAddress,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.currentLatitude,
    this.currentLongitude,
    this.lastLocationUpdate,
    this.distanceKm,
    this.departureTime,
    this.estimatedDurationMinutes,
    required this.isPaused,
    this.adminInstructions,
    required this.pickupName,
    this.pickupAddress,
  });

  static double _doubleFromJson(dynamic json) =>
      _doubleNullableFromJson(json) ?? 0.0;
  static double? _doubleNullableFromJson(dynamic json) {
    if (json is num) return json.toDouble();
    if (json is String) return double.tryParse(json);
    return null;
  }

  static int? _intNullableFromJson(dynamic json) {
    if (json is num) return json.toInt();
    if (json is String) return int.tryParse(json);
    return null;
  }

  factory ActiveTripDto.fromJson(Map<String, dynamic> json) =>
      _$ActiveTripDtoFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveTripDtoToJson(this);
}

@JsonSerializable()
class StartTripRequest {
  final List<String> preRideExteriorImages;
  final int startingMileage;
  final String preRideOdometerImage;
  final List<String> preRideManifestImages;
  final String gasolineLiters;
  final String? fuelImage;

  StartTripRequest({
    required this.preRideExteriorImages,
    required this.startingMileage,
    required this.preRideOdometerImage,
    required this.preRideManifestImages,
    required this.gasolineLiters,
    this.fuelImage,
  });

  factory StartTripRequest.fromJson(Map<String, dynamic> json) =>
      _$StartTripRequestFromJson(json);
  Map<String, dynamic> toJson() => _$StartTripRequestToJson(this);
}

@JsonSerializable()
class CompleteTripRequest {
  final int endingMileage;
  final List<String> postRideExteriorImages;
  final List<String> postRideOdometerImages;
  final List<String> postRideManifestImages;

  CompleteTripRequest({
    required this.endingMileage,
    required this.postRideExteriorImages,
    required this.postRideOdometerImages,
    required this.postRideManifestImages,
  });

  factory CompleteTripRequest.fromJson(Map<String, dynamic> json) =>
      _$CompleteTripRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CompleteTripRequestToJson(this);
}

@JsonSerializable()
class CrewDashboardDto {
  final String crewName;
  final CrewTripDto? ongoingTrip;
  final List<CrewTripDto> upcomingTrips;
  final List<CrewTripDto> tripHistory;

  CrewDashboardDto({
    required this.crewName,
    this.ongoingTrip,
    required this.upcomingTrips,
    required this.tripHistory,
  });

  factory CrewDashboardDto.fromJson(Map<String, dynamic> json) =>
      _$CrewDashboardDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CrewDashboardDtoToJson(this);
}

@JsonSerializable()
class CrewTripDto {
  final String id;
  final String status;
  final String truckPlateNumber;
  final String jobId;
  final String dispatchOriginTime;
  final String destinationName;
  final String destinationAddress;
  final DateTime scheduledDate;

  CrewTripDto({
    required this.id,
    required this.status,
    required this.truckPlateNumber,
    required this.jobId,
    required this.dispatchOriginTime,
    required this.destinationName,
    required this.destinationAddress,
    required this.scheduledDate,
  });

  factory CrewTripDto.fromJson(Map<String, dynamic> json) =>
      _$CrewTripDtoFromJson(json);
  Map<String, dynamic> toJson() => _$CrewTripDtoToJson(this);
}

@JsonSerializable()
class UpdateTripLocationRequest {
  final double latitude;
  final double longitude;
  final double? speedKmh;

  UpdateTripLocationRequest({
    required this.latitude,
    required this.longitude,
    this.speedKmh,
  });

  factory UpdateTripLocationRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateTripLocationRequestFromJson(json);
  Map<String, dynamic> toJson() => _$UpdateTripLocationRequestToJson(this);
}

@JsonSerializable()
class AddTripExpenseRequest {
  final int expenseType;
  final double amount;
  final String? location;
  final String? receiptImage;
  final String? notes;
  final double? liters;
  final double? pricePerLiter;
  final int? odometer;
  final String? station;

  AddTripExpenseRequest({
    required this.expenseType,
    required this.amount,
    this.location,
    this.receiptImage,
    this.notes,
    this.liters,
    this.pricePerLiter,
    this.odometer,
    this.station,
  });

  factory AddTripExpenseRequest.fromJson(Map<String, dynamic> json) =>
      _$AddTripExpenseRequestFromJson(json);
  Map<String, dynamic> toJson() => _$AddTripExpenseRequestToJson(this);
}

@JsonSerializable()
class ReportIncidentRequest {
  final int category;
  final String incidentType;
  final String? notes;
  final double? latitude;
  final double? longitude;

  ReportIncidentRequest({
    required this.category,
    required this.incidentType,
    this.notes,
    this.latitude,
    this.longitude,
  });

  factory ReportIncidentRequest.fromJson(Map<String, dynamic> json) =>
      _$ReportIncidentRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ReportIncidentRequestToJson(this);
}

@JsonSerializable()
class SubmitCheckpointRequest {
  final int checkpointType;
  final String image;
  final String? notes;

  SubmitCheckpointRequest({
    required this.checkpointType,
    required this.image,
    this.notes,
  });

  factory SubmitCheckpointRequest.fromJson(Map<String, dynamic> json) =>
      _$SubmitCheckpointRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SubmitCheckpointRequestToJson(this);
}

@JsonSerializable()
class TriggerSosRequest {
  final double? latitude;
  final double? longitude;
  final String? notes;

  TriggerSosRequest({this.latitude, this.longitude, this.notes});

  factory TriggerSosRequest.fromJson(Map<String, dynamic> json) =>
      _$TriggerSosRequestFromJson(json);
  Map<String, dynamic> toJson() => _$TriggerSosRequestToJson(this);
}

@JsonSerializable()
class PendingExpenseDto {
  final String tripId;
  final AddTripExpenseRequest request;
  final DateTime timestamp;

  PendingExpenseDto({
    required this.tripId,
    required this.request,
    required this.timestamp,
  });

  factory PendingExpenseDto.fromJson(Map<String, dynamic> json) =>
      _$PendingExpenseDtoFromJson(json);
  Map<String, dynamic> toJson() => _$PendingExpenseDtoToJson(this);
}
