class WorkshopModel {
  const WorkshopModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.rating,
    required this.isOpen,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final double rating;
  final bool isOpen;

  String get locationLabel => [
        address.trim(),
        city.trim(),
      ].where((part) => part.isNotEmpty).join('\n');

  bool matchesQuery(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    return name.toLowerCase().contains(query) ||
        city.toLowerCase().contains(query) ||
        address.toLowerCase().contains(query);
  }
}
