import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'fuel_receipt_history_service.dart';

class TollExpenseRecord {
  final String id;
  final String expresswayOrLocation;
  final double amountPesos;
  final String receiptFileName;
  final DateTime uploadedAt;

  const TollExpenseRecord({
    required this.id,
    required this.expresswayOrLocation,
    required this.amountPesos,
    required this.receiptFileName,
    required this.uploadedAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'expresswayOrLocation': expresswayOrLocation,
    'amountPesos': amountPesos,
    'receiptFileName': receiptFileName,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  static TollExpenseRecord fromJson(Map<String, Object?> json) {
    return TollExpenseRecord(
      id: (json['id'] as String?) ?? 'unknown',
      expresswayOrLocation: (json['expresswayOrLocation'] as String?) ?? '',
      amountPesos: (json['amountPesos'] as num?)?.toDouble() ?? 0,
      receiptFileName: (json['receiptFileName'] as String?) ?? '',
      uploadedAt:
          DateTime.tryParse((json['uploadedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class LocationPing {
  final double lat;
  final double lng;
  final double? accuracyMeters;
  final DateTime at;

  const LocationPing({
    required this.lat,
    required this.lng,
    required this.at,
    this.accuracyMeters,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'lat': lat,
    'lng': lng,
    'accuracyMeters': accuracyMeters,
    'at': at.toIso8601String(),
  };
}

class MockBackendService {
  static bool _initialized = false;
  static late Directory _rootDir;
  static late File _dbFile;

  static Map<String, Object?> _db = <String, Object?>{
    'fuelReceiptsByTrip': <String, Object?>{},
    'tolls': <Object?>[],
    'postTripPhotos': <Object?>[],
    'locationPings': <Object?>[],
    'preRideSubmissions': <Object?>[],
    'activeRide': <String, Object?>{
      'isActive': false,
      'tripId': null,
      'destinationName': null,
      'destinationLat': null,
      'destinationLng': null,
      'lastLat': null,
      'lastLng': null,
      'lastAccuracyMeters': null,
      'lastUpdatedAt': null,
      'updatedBy': null,
    },
  };

  static Future<void> initialize() async {
    if (_initialized) return;
    _rootDir = await getApplicationDocumentsDirectory();
    final dbDir = Directory('${_rootDir.path}${Platform.pathSeparator}mock');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }
    final uploadsDir = Directory(
      '${dbDir.path}${Platform.pathSeparator}uploads',
    );
    if (!await uploadsDir.exists()) {
      await uploadsDir.create(recursive: true);
    }
    _dbFile = File('${dbDir.path}${Platform.pathSeparator}mock_db.json');

    if (await _dbFile.exists()) {
      try {
        final raw = await _dbFile.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, Object?>) {
          _db = decoded;
        } else if (decoded is Map) {
          _db = decoded.cast<String, Object?>();
        }
      } catch (_) {
        // Keep defaults
      }
    } else {
      await _persist();
    }

    _initialized = true;
  }

  static Future<void> _persist() async {
    await _dbFile.writeAsString(jsonEncode(_db));
  }

  static String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  static Future<String> _copyIntoUploads(File source) async {
    final uploadsDir = Directory(
      '${_dbFile.parent.path}${Platform.pathSeparator}uploads',
    );
    final ext = source.path.contains('.') ? source.path.split('.').last : 'jpg';
    final fileName = 'upload_${_id()}.$ext';
    final dest = File('${uploadsDir.path}${Platform.pathSeparator}$fileName');
    await source.copy(dest.path);
    return fileName;
  }

  // ---- Driver Status ----
  static Future<void> reportDriverStatus({required bool isPaused}) async {
    // Simulate sending POST request with driver status
    // In a real app, use an HTTP client to POST to /driver/status
    _db['driverStatus'] = <String, Object?>{
      'isPaused': isPaused,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await _persist();
  }

  // ---- Pre-ride submission ----
  static Future<void> submitPreRide({
    required String tripId,
    required File truckExteriorPhoto,
    required File odometerPhoto,
    required File manifestPhoto,
    required File fuelDetailsPhoto,
    required DateTime submittedAt,
  }) async {
    final truckFile = await _copyIntoUploads(truckExteriorPhoto);
    final odomFile = await _copyIntoUploads(odometerPhoto);
    final manifestFile = await _copyIntoUploads(manifestPhoto);
    final fuelFile = await _copyIntoUploads(fuelDetailsPhoto);
    final list =
        (_db['preRideSubmissions'] as List?)?.cast<Object?>() ?? <Object?>[];
    list.add(<String, Object?>{
      'id': _id(),
      'tripId': tripId,
      'truckExteriorPhoto': truckFile,
      'odometerPhoto': odomFile,
      'manifestPhoto': manifestFile,
      'fuelDetailsPhoto': fuelFile,
      'submittedAt': submittedAt.toIso8601String(),
    });
    _db['preRideSubmissions'] = list;
    await _persist();
  }

  // ---- Fuel receipts ----
  static List<FuelReceiptRecord> getFuelReceiptsForTrip(String tripId) {
    final root = _db['fuelReceiptsByTrip'];
    if (root is! Map) return const <FuelReceiptRecord>[];
    final list = root[tripId];
    if (list is! List) return const <FuelReceiptRecord>[];
    return list
        .whereType<Map>()
        .map((m) => m.cast<String, Object?>())
        .map(FuelReceiptRecord.fromJson)
        .toList()
        .reversed
        .toList(growable: false);
  }

  static Future<void> addFuelReceipt({
    required String tripId,
    required File photoFile,
    required double totalPesos,
    required double pricePerLiter,
    required double liters,
  }) async {
    final fileName = await _copyIntoUploads(photoFile);
    final record = FuelReceiptRecord(
      photoName: fileName,
      totalPesos: totalPesos,
      pricePerLiter: pricePerLiter,
      liters: liters,
      uploadedAt: DateTime.now(),
    );

    final root =
        (_db['fuelReceiptsByTrip'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final list = (root[tripId] as List?)?.cast<Object?>() ?? <Object?>[];
    list.add(record.toJson());
    root[tripId] = list;
    _db['fuelReceiptsByTrip'] = root;
    await _persist();
  }

  // ---- Toll expenses ----
  static Future<void> addTollExpense({
    required File receiptFile,
    required String expresswayOrLocation,
    required double amountPesos,
  }) async {
    final fileName = await _copyIntoUploads(receiptFile);
    final record = TollExpenseRecord(
      id: _id(),
      expresswayOrLocation: expresswayOrLocation,
      amountPesos: amountPesos,
      receiptFileName: fileName,
      uploadedAt: DateTime.now(),
    );
    final list = (_db['tolls'] as List?)?.cast<Object?>() ?? <Object?>[];
    list.add(record.toJson());
    _db['tolls'] = list;
    await _persist();
  }

  // ---- Post trip photos ----
  static Future<void> addPostTripPhoto(File photoFile) async {
    final fileName = await _copyIntoUploads(photoFile);
    final list =
        (_db['postTripPhotos'] as List?)?.cast<Object?>() ?? <Object?>[];
    list.add(<String, Object?>{
      'id': _id(),
      'fileName': fileName,
      'uploadedAt': DateTime.now().toIso8601String(),
    });
    _db['postTripPhotos'] = list;
    await _persist();
  }

  // ---- Location pings ----
  static Future<void> addLocationPing(LocationPing ping) async {
    await initialize();
    final list =
        (_db['locationPings'] as List?)?.cast<Object?>() ?? <Object?>[];
    list.add(ping.toJson());
    _db['locationPings'] = list;
    // Keep only the last 200 to avoid unbounded growth during testing
    if (list.length > 200) {
      _db['locationPings'] = list.sublist(list.length - 200);
    }

    final activeRide =
        (_db['activeRide'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    final isActive = activeRide['isActive'] == true;
    if (isActive) {
      activeRide['lastLat'] = ping.lat;
      activeRide['lastLng'] = ping.lng;
      activeRide['lastAccuracyMeters'] = ping.accuracyMeters;
      activeRide['lastUpdatedAt'] = ping.at.toIso8601String();
      if ((activeRide['updatedBy'] as String?) == null) {
        activeRide['updatedBy'] = 'background_service';
      }
      _db['activeRide'] = activeRide;
    }

    await _persist();
  }

  static Future<void> setActiveRide({
    required bool isActive,
    required String updatedBy,
    String? tripId,
    String? destinationName,
    double? destinationLat,
    double? destinationLng,
  }) async {
    await initialize();
    final activeRide =
        (_db['activeRide'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};

    activeRide['isActive'] = isActive;
    activeRide['updatedBy'] = updatedBy;
    activeRide['lastUpdatedAt'] = DateTime.now().toIso8601String();

    if (tripId != null) {
      activeRide['tripId'] = tripId;
    }
    if (destinationName != null) {
      activeRide['destinationName'] = destinationName;
    }
    if (destinationLat != null) {
      activeRide['destinationLat'] = destinationLat;
    }
    if (destinationLng != null) {
      activeRide['destinationLng'] = destinationLng;
    }

    if (!isActive) {
      activeRide['lastLat'] = null;
      activeRide['lastLng'] = null;
      activeRide['lastAccuracyMeters'] = null;
    }

    _db['activeRide'] = activeRide;
    await _persist();
  }

  static Future<Map<String, Object?>> getActiveRide() async {
    await initialize();
    final activeRide =
        (_db['activeRide'] as Map?)?.cast<String, Object?>() ??
        <String, Object?>{};
    return Map<String, Object?>.from(activeRide);
  }
}
