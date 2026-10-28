class Ride {
  final String id;
  final String? jobId;
  final String truckNumber;
  final String destination;
  final String destinationAddress;
  final DateTime departureDate;
  final DateTime arrivalDate;
  final String expectedDeparture;
  final String expectedArrival;
  final RideStatus status;
  final String? remarks; // Admin notes/instructions

  Ride({
    required this.id,
    this.jobId,
    required this.truckNumber,
    required this.destination,
    required this.destinationAddress,
    required this.departureDate,
    required this.arrivalDate,
    required this.expectedDeparture,
    required this.expectedArrival,
    required this.status,
    this.remarks,
  });

  // For backward compatibility - use departureDate as primary date
  DateTime get date => departureDate;
}

enum RideStatus { upcoming, current, past }
