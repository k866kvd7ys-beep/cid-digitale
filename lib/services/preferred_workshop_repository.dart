import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workshop_model.dart';

const Set<String> legacyMockWorkshopIds = {
  'garage-europa-ag',
  'autocentro-ticino',
  'officine-mendrisio',
  'carrosserie-lac',
};

bool isLegacyMockWorkshop(WorkshopModel? workshop) {
  final id = workshop?.id.trim().toLowerCase() ?? '';
  return legacyMockWorkshopIds.contains(id);
}

abstract interface class PreferredWorkshopRepository {
  Future<WorkshopModel?> load();

  Future<void> save(WorkshopModel workshop);

  Future<void> remove();
}

class SupabasePreferredWorkshopRepository
    implements PreferredWorkshopRepository {
  SupabasePreferredWorkshopRepository({SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  String get _userId {
    final userId = _client.auth.currentUser?.id.trim() ?? '';
    if (userId.isEmpty) {
      throw StateError('Authenticated customer required');
    }
    return userId;
  }

  @override
  Future<WorkshopModel?> load() async {
    final response = await _client
        .from('customer_profiles')
        .select('preferred_workshop')
        .eq('user_id', _userId)
        .maybeSingle();
    final workshop = _decodeWorkshop(response?['preferred_workshop']);
    return isLegacyMockWorkshop(workshop) ? null : workshop;
  }

  @override
  Future<void> save(WorkshopModel workshop) async {
    if (isLegacyMockWorkshop(workshop)) return;
    await _client
        .from('customer_profiles')
        .update({'preferred_workshop': _encodeWorkshop(workshop)})
        .eq('user_id', _userId)
        .select('preferred_workshop')
        .single();
  }

  @override
  Future<void> remove() async {
    await _client
        .from('customer_profiles')
        .update({'preferred_workshop': null})
        .eq('user_id', _userId)
        .select('preferred_workshop')
        .single();
  }

  Map<String, dynamic> _encodeWorkshop(WorkshopModel workshop) {
    return {
      'id': workshop.id.trim(),
      'name': workshop.name.trim(),
      'email': workshop.email?.trim(),
      'phone': workshop.phone?.trim(),
      'address': workshop.address.trim(),
      'city': workshop.city.trim(),
      'rating': workshop.rating,
      'is_open': workshop.isOpen,
      'latitude': workshop.latitude,
      'longitude': workshop.longitude,
    };
  }

  WorkshopModel? _decodeWorkshop(dynamic value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    final id = map['id']?.toString().trim() ?? '';
    final name = map['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) return null;

    double? number(String key) {
      final raw = map[key];
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    return WorkshopModel(
      id: id,
      name: name,
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      address: map['address']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      rating: number('rating'),
      isOpen: map['is_open'] is bool ? map['is_open'] as bool : null,
      latitude: number('latitude'),
      longitude: number('longitude'),
    );
  }
}
