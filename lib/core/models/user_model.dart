class AppUser {
  final String uid;
  final String name;
  final String phone;
  final String role; // "user" | "officer"
  final bool officialIdVerified;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.phone,
    this.role = 'user',
    this.officialIdVerified = false,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
      'officialIdVerified': officialIdVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromFirestore(Map<String, dynamic> data, String docId) {
    return AppUser(
      uid: docId,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'user',
      officialIdVerified: data['officialIdVerified'] ?? false,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
