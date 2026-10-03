class UserProfile {
  final String uid;
  final String name;
  final String phone;
  final String? email; // Added for Firebase Auth email
  final String dateOfBirth;
  final String securityPin;
  final String? profileImagePath; // local file path or data URI for web

  UserProfile({
    required this.uid,
    required this.name,
    required this.phone,
    this.email,
    required this.dateOfBirth,
    required this.securityPin,
    this.profileImagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email ?? '',
      'dateOfBirth': dateOfBirth,
      'securityPin': securityPin,
      'profileImagePath': profileImagePath,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] as String?,
      dateOfBirth: map['dateOfBirth'] ?? '',
      securityPin: map['securityPin'] ?? '',
      profileImagePath: map['profileImagePath'],
    );
  }

  UserProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? dateOfBirth,
    String? securityPin,
    String? profileImagePath,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      securityPin: securityPin ?? this.securityPin,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }
}
