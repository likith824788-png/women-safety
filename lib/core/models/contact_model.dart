class TrustedContact {
  final String id;
  final String name;
  final String phone;
  final String email;
  final int priority;
  final String relationship;

  TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    required this.priority,
    required this.relationship,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'priority': priority,
      'relationship': relationship,
    };
  }

  factory TrustedContact.fromFirestore(Map<String, dynamic> data, String docId) {
    return TrustedContact(
      id: docId,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      priority: data['priority'] ?? 1,
      relationship: data['relationship'] ?? 'Family',
    );
  }

  TrustedContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    int? priority,
    String? relationship,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      priority: priority ?? this.priority,
      relationship: relationship ?? this.relationship,
    );
  }
}
