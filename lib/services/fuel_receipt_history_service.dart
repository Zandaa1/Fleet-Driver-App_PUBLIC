class FuelReceiptRecord {
  final String photoName;
  final double totalPesos;
  final double pricePerLiter;
  final double liters;
  final DateTime uploadedAt;

  const FuelReceiptRecord({
    required this.photoName,
    required this.totalPesos,
    required this.pricePerLiter,
    required this.liters,
    required this.uploadedAt,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    'photoName': photoName,
    'totalPesos': totalPesos,
    'pricePerLiter': pricePerLiter,
    'liters': liters,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  static FuelReceiptRecord fromJson(Map<String, Object?> json) {
    return FuelReceiptRecord(
      photoName: (json['photoName'] as String?) ?? '',
      totalPesos: (json['totalPesos'] as num?)?.toDouble() ?? 0,
      pricePerLiter: (json['pricePerLiter'] as num?)?.toDouble() ?? 0,
      liters: (json['liters'] as num?)?.toDouble() ?? 0,
      uploadedAt:
          DateTime.tryParse((json['uploadedAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class FuelReceiptHistoryService {
  static final Map<String, List<FuelReceiptRecord>> _historyByTrip =
      <String, List<FuelReceiptRecord>>{};

  static List<FuelReceiptRecord> getHistoryForTrip(String tripId) {
    final history = _historyByTrip[tripId];
    if (history == null) {
      return const <FuelReceiptRecord>[];
    }

    return List<FuelReceiptRecord>.unmodifiable(history.reversed.toList());
  }

  static void addReceipt({
    required String tripId,
    required FuelReceiptRecord record,
  }) {
    final history = _historyByTrip.putIfAbsent(
      tripId,
      () => <FuelReceiptRecord>[],
    );
    history.add(record);
  }
}
