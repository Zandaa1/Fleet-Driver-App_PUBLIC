// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trip.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActiveTripDto _$ActiveTripDtoFromJson(Map<String, dynamic> json) =>
    ActiveTripDto(
      id: json['id'] as String,
      truckPlateNumber: json['truckPlateNumber'] as String,
      jobId: json['jobId'] as String,
      destinationName: json['destinationName'] as String,
      destinationAddress: json['destinationAddress'] as String,
      destinationLatitude: ActiveTripDto._doubleFromJson(
        json['destinationLatitude'],
      ),
      destinationLongitude: ActiveTripDto._doubleFromJson(
        json['destinationLongitude'],
      ),
      currentLatitude: ActiveTripDto._doubleNullableFromJson(
        json['currentLatitude'],
      ),
      currentLongitude: ActiveTripDto._doubleNullableFromJson(
        json['currentLongitude'],
      ),
      lastLocationUpdate: json['lastLocationUpdate'] == null
          ? null
          : DateTime.parse(json['lastLocationUpdate'] as String),
      distanceKm: ActiveTripDto._doubleNullableFromJson(json['distanceKm']),
      departureTime: json['departureTime'] == null
          ? null
          : DateTime.parse(json['departureTime'] as String),
      estimatedDurationMinutes: ActiveTripDto._intNullableFromJson(
        json['estimatedDurationMinutes'],
      ),
      isPaused: json['isPaused'] as bool,
      adminInstructions: json['adminInstructions'] as String?,
      pickupName: json['pickupName'] as String,
      pickupAddress: json['pickupAddress'] as String?,
    );

Map<String, dynamic> _$ActiveTripDtoToJson(ActiveTripDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'truckPlateNumber': instance.truckPlateNumber,
      'jobId': instance.jobId,
      'destinationName': instance.destinationName,
      'destinationAddress': instance.destinationAddress,
      'destinationLatitude': instance.destinationLatitude,
      'destinationLongitude': instance.destinationLongitude,
      'currentLatitude': instance.currentLatitude,
      'currentLongitude': instance.currentLongitude,
      'lastLocationUpdate': instance.lastLocationUpdate?.toIso8601String(),
      'distanceKm': instance.distanceKm,
      'departureTime': instance.departureTime?.toIso8601String(),
      'estimatedDurationMinutes': instance.estimatedDurationMinutes,
      'isPaused': instance.isPaused,
      'adminInstructions': instance.adminInstructions,
      'pickupName': instance.pickupName,
      'pickupAddress': instance.pickupAddress,
    };

StartTripRequest _$StartTripRequestFromJson(Map<String, dynamic> json) =>
    StartTripRequest(
      preRideExteriorImages: (json['preRideExteriorImages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      startingMileage: (json['startingMileage'] as num).toInt(),
      preRideOdometerImage: json['preRideOdometerImage'] as String,
      preRideManifestImages: (json['preRideManifestImages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      gasolineLiters: json['gasolineLiters'] as String,
      fuelImage: json['fuelImage'] as String?,
    );

Map<String, dynamic> _$StartTripRequestToJson(StartTripRequest instance) =>
    <String, dynamic>{
      'preRideExteriorImages': instance.preRideExteriorImages,
      'startingMileage': instance.startingMileage,
      'preRideOdometerImage': instance.preRideOdometerImage,
      'preRideManifestImages': instance.preRideManifestImages,
      'gasolineLiters': instance.gasolineLiters,
      'fuelImage': instance.fuelImage,
    };

CompleteTripRequest _$CompleteTripRequestFromJson(Map<String, dynamic> json) =>
    CompleteTripRequest(
      endingMileage: (json['endingMileage'] as num).toInt(),
      postRideExteriorImages: (json['postRideExteriorImages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      postRideOdometerImages: (json['postRideOdometerImages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      postRideManifestImages: (json['postRideManifestImages'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$CompleteTripRequestToJson(
  CompleteTripRequest instance,
) => <String, dynamic>{
  'endingMileage': instance.endingMileage,
  'postRideExteriorImages': instance.postRideExteriorImages,
  'postRideOdometerImages': instance.postRideOdometerImages,
  'postRideManifestImages': instance.postRideManifestImages,
};

CrewDashboardDto _$CrewDashboardDtoFromJson(Map<String, dynamic> json) =>
    CrewDashboardDto(
      crewName: json['crewName'] as String,
      ongoingTrip: json['ongoingTrip'] == null
          ? null
          : CrewTripDto.fromJson(json['ongoingTrip'] as Map<String, dynamic>),
      upcomingTrips: (json['upcomingTrips'] as List<dynamic>)
          .map((e) => CrewTripDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      tripHistory: (json['tripHistory'] as List<dynamic>)
          .map((e) => CrewTripDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CrewDashboardDtoToJson(CrewDashboardDto instance) =>
    <String, dynamic>{
      'crewName': instance.crewName,
      'ongoingTrip': instance.ongoingTrip,
      'upcomingTrips': instance.upcomingTrips,
      'tripHistory': instance.tripHistory,
    };

CrewTripDto _$CrewTripDtoFromJson(Map<String, dynamic> json) => CrewTripDto(
  id: json['id'] as String,
  status: json['status'] as String,
  truckPlateNumber: json['truckPlateNumber'] as String,
  jobId: json['jobId'] as String,
  dispatchOriginTime: json['dispatchOriginTime'] as String,
  destinationName: json['destinationName'] as String,
  destinationAddress: json['destinationAddress'] as String,
  scheduledDate: DateTime.parse(json['scheduledDate'] as String),
);

Map<String, dynamic> _$CrewTripDtoToJson(CrewTripDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'truckPlateNumber': instance.truckPlateNumber,
      'jobId': instance.jobId,
      'dispatchOriginTime': instance.dispatchOriginTime,
      'destinationName': instance.destinationName,
      'destinationAddress': instance.destinationAddress,
      'scheduledDate': instance.scheduledDate.toIso8601String(),
    };

UpdateTripLocationRequest _$UpdateTripLocationRequestFromJson(
  Map<String, dynamic> json,
) => UpdateTripLocationRequest(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
  speedKmh: (json['speedKmh'] as num?)?.toDouble(),
);

Map<String, dynamic> _$UpdateTripLocationRequestToJson(
  UpdateTripLocationRequest instance,
) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'speedKmh': instance.speedKmh,
};

AddTripExpenseRequest _$AddTripExpenseRequestFromJson(
  Map<String, dynamic> json,
) => AddTripExpenseRequest(
  expenseType: (json['expenseType'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
  location: json['location'] as String?,
  receiptImage: json['receiptImage'] as String?,
  notes: json['notes'] as String?,
  liters: (json['liters'] as num?)?.toDouble(),
  pricePerLiter: (json['pricePerLiter'] as num?)?.toDouble(),
  odometer: (json['odometer'] as num?)?.toInt(),
  station: json['station'] as String?,
);

Map<String, dynamic> _$AddTripExpenseRequestToJson(
  AddTripExpenseRequest instance,
) => <String, dynamic>{
  'expenseType': instance.expenseType,
  'amount': instance.amount,
  'location': instance.location,
  'receiptImage': instance.receiptImage,
  'notes': instance.notes,
  'liters': instance.liters,
  'pricePerLiter': instance.pricePerLiter,
  'odometer': instance.odometer,
  'station': instance.station,
};

ReportIncidentRequest _$ReportIncidentRequestFromJson(
  Map<String, dynamic> json,
) => ReportIncidentRequest(
  category: (json['category'] as num).toInt(),
  incidentType: json['incidentType'] as String,
  notes: json['notes'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ReportIncidentRequestToJson(
  ReportIncidentRequest instance,
) => <String, dynamic>{
  'category': instance.category,
  'incidentType': instance.incidentType,
  'notes': instance.notes,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

SubmitCheckpointRequest _$SubmitCheckpointRequestFromJson(
  Map<String, dynamic> json,
) => SubmitCheckpointRequest(
  checkpointType: (json['checkpointType'] as num).toInt(),
  image: json['image'] as String,
  notes: json['notes'] as String?,
);

Map<String, dynamic> _$SubmitCheckpointRequestToJson(
  SubmitCheckpointRequest instance,
) => <String, dynamic>{
  'checkpointType': instance.checkpointType,
  'image': instance.image,
  'notes': instance.notes,
};

TriggerSosRequest _$TriggerSosRequestFromJson(Map<String, dynamic> json) =>
    TriggerSosRequest(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$TriggerSosRequestToJson(TriggerSosRequest instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'notes': instance.notes,
    };

PendingExpenseDto _$PendingExpenseDtoFromJson(Map<String, dynamic> json) =>
    PendingExpenseDto(
      tripId: json['tripId'] as String,
      request: AddTripExpenseRequest.fromJson(
        json['request'] as Map<String, dynamic>,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$PendingExpenseDtoToJson(PendingExpenseDto instance) =>
    <String, dynamic>{
      'tripId': instance.tripId,
      'request': instance.request,
      'timestamp': instance.timestamp.toIso8601String(),
    };
