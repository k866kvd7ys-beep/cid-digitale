class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.title = '',
    this.street = '',
    this.postalCode = '',
    this.city = '',
    this.country = '',
    this.phone = '',
    this.profileCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String title;
  final String firstName;
  final String lastName;
  final String street;
  final String postalCode;
  final String city;
  final String country;
  final String phone;
  final String email;
  final bool profileCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName => [firstName.trim(), lastName.trim()]
      .where((part) => part.isNotEmpty)
      .join(' ');

  factory CustomerProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return CustomerProfile(
      userId: map['user_id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name']?.toString() ?? '',
      street: map['street']?.toString() ?? '',
      postalCode: map['postal_code']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      country: map['country']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      profileCompleted: map['profile_completed'] == true,
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'user_id': userId,
      'title': title.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'street': street.trim(),
      'postal_code': postalCode.trim(),
      'city': city.trim(),
      'country': country.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'profile_completed': profileCompleted,
    };
  }

  CustomerProfile copyWith({
    String? title,
    String? firstName,
    String? lastName,
    String? street,
    String? postalCode,
    String? city,
    String? country,
    String? phone,
    String? email,
    bool? profileCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerProfile(
      userId: userId,
      title: title ?? this.title,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      street: street ?? this.street,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
