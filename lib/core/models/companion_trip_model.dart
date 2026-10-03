class CompanionTrip {
  final String id;
  final String uid;
  final String destination;
  final DateTime expectedArrival;
  final String status; // "active" | "arrived" | "deviated" | "sos"
  final String routePolyline;
  final List<String> recipientContactIds;

  CompanionTrip({
    required this.id,
    required this.uid,
    required this.destination,
    required this.expectedArrival,
    required this.status,
    required this.routePolyline,
    required this.recipientContactIds,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'destination': destination,
      'expectedArrival': expectedArrival.toIso8601String(),
      'status': status,
      'routePolyline': routePolyline,
      'recipientContactIds': recipientContactIds,
    };
  }

  factory CompanionTrip.fromFirestore(Map<String, dynamic> data, String docId) {
    return CompanionTrip(
      id: docId,
      uid: data['uid'] ?? '',
      destination: data['destination'] ?? '',
      expectedArrival: data['expectedArrival'] != null
          ? DateTime.tryParse(data['expectedArrival']) ?? DateTime.now()
          : DateTime.now(),
      status: data['status'] ?? 'active',
      routePolyline: data['routePolyline'] ?? '',
      recipientContactIds: List<String>.from(data['recipientContactIds'] ?? []),
    );
  }
}
