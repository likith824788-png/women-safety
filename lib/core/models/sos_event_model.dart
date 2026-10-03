class SosEvent {
  final String id;
  final String uid;
  final String status; // "countdown" | "cancelled" | "sent" | "resolved"
  final String triggeredBy; // "manual" | "ai_audio" | "ai_text" | "companion_deviation"
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final double latitude;
  final double longitude;
  final List<String> notifiedContactIds;

  SosEvent({
    required this.id,
    required this.uid,
    required this.status,
    required this.triggeredBy,
    required this.createdAt,
    this.resolvedAt,
    required this.latitude,
    required this.longitude,
    required this.notifiedContactIds,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'status': status,
      'triggeredBy': triggeredBy,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'notifiedContactIds': notifiedContactIds,
    };
  }

  factory SosEvent.fromFirestore(Map<String, dynamic> data, String docId) {
    final loc = data['location'] as Map<String, dynamic>? ?? {};
    return SosEvent(
      id: docId,
      uid: data['uid'] ?? '',
      status: data['status'] ?? 'countdown',
      triggeredBy: data['triggeredBy'] ?? 'manual',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: data['resolvedAt'] != null
          ? DateTime.tryParse(data['resolvedAt'])
          : null,
      latitude: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
      notifiedContactIds: List<String>.from(data['notifiedContactIds'] ?? []),
    );
  }
}
