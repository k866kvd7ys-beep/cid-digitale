class WorkshopModel {
  const WorkshopModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.address,
    required this.city,
    this.rating,
    this.isOpen,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String address;
  final String city;
  final double? rating;
  final bool? isOpen;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasEmail => email?.trim().isNotEmpty == true;
  bool get hasPhone => phone?.trim().isNotEmpty == true;

  String get locationLabel => [
        address.trim(),
        city.trim(),
      ].where((part) => part.isNotEmpty).join('\n');

  WorkshopModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? city,
    double? rating,
    bool? isOpen,
    double? latitude,
    double? longitude,
    double? distanceKm,
    bool clearEmail = false,
    bool clearPhone = false,
    bool clearRating = false,
    bool clearIsOpen = false,
    bool clearLatitude = false,
    bool clearLongitude = false,
    bool clearDistanceKm = false,
  }) {
    return WorkshopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: clearEmail ? null : (email ?? this.email),
      phone: clearPhone ? null : (phone ?? this.phone),
      address: address ?? this.address,
      city: city ?? this.city,
      rating: clearRating ? null : (rating ?? this.rating),
      isOpen: clearIsOpen ? null : (isOpen ?? this.isOpen),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      distanceKm: clearDistanceKm ? null : (distanceKm ?? this.distanceKm),
    );
  }

  bool matchesQuery(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    return name.toLowerCase().contains(query) ||
        city.toLowerCase().contains(query) ||
        address.toLowerCase().contains(query) ||
        (phone?.toLowerCase().contains(query) ?? false) ||
        (email?.toLowerCase().contains(query) ?? false);
  }
}
