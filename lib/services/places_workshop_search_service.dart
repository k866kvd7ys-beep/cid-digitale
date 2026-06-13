import 'dart:convert';

import 'package:cid_digitale/config/google_places_api_key.dart';
import 'package:cid_digitale/models/workshop_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class PlacesWorkshopSearchService {
  PlacesWorkshopSearchService({
    http.Client? client,
    String? apiKey,
  })  : _client = client,
        _apiKeyOverride = apiKey;

  // TODO: pass the key at runtime with:
  // flutter run --dart-define=GOOGLE_PLACES_API_KEY=YOUR_KEY

  static const List<int> _nearbyRadiusMeters = [
    10000,
    25000,
    50000,
  ];

  static const List<String> _nearbyFallbackQueries = [
    'car repair',
    'garage',
    'auto repair',
    'car service',
    'body shop',
  ];

  final http.Client? _client;
  final String? _apiKeyOverride;

  String get _apiKey {
    final override = _apiKeyOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return kGooglePlacesApiKey.trim();
  }

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<WorkshopModel>> searchNearbyWorkshops({
    required double latitude,
    required double longitude,
    required String locale,
  }) async {
    if (!isConfigured) {
      return const [];
    }

    final client = _client ?? http.Client();
    try {
      for (final radiusMeters in _nearbyRadiusMeters) {
        final nearbyPlaces = await _performNearbySearch(
          client,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          locale: locale,
        );

        final nearbyResults = await _hydratePlaces(
          client,
          nearbyPlaces,
          locale: locale,
          originLatitude: latitude,
          originLongitude: longitude,
          radiusMeters: radiusMeters,
        );
        if (nearbyResults.isNotEmpty) {
          return nearbyResults;
        }

        final fallbackPlaces = await _performNearbyTextFallbacks(
          client,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          locale: locale,
        );

        final fallbackResults = await _hydratePlaces(
          client,
          fallbackPlaces,
          locale: locale,
          originLatitude: latitude,
          originLongitude: longitude,
          radiusMeters: radiusMeters,
        );
        if (fallbackResults.isNotEmpty) {
          return fallbackResults;
        }
      }

      return const [];
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<List<WorkshopModel>> searchWorkshopsByText({
    required String query,
    required String locale,
    double? latitude,
    double? longitude,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty || !isConfigured) {
      return const [];
    }

    final client = _client ?? http.Client();
    try {
      final places = await _performTextSearch(
        client,
        query: trimmedQuery,
        locale: locale,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: latitude != null && longitude != null ? 50000 : null,
        maxResults: 14,
      );

      return _hydratePlaces(
        client,
        places,
        locale: locale,
        originLatitude: latitude,
        originLongitude: longitude,
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<List<Map<String, dynamic>>> _performNearbySearch(
    http.Client client, {
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String locale,
  }) async {
    final response = await client.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: _jsonHeaders(
        'places.id,places.displayName,places.formattedAddress,places.location',
      ),
      body: jsonEncode({
        'includedTypes': ['car_repair'],
        'maxResultCount': 12,
        'rankPreference': 'DISTANCE',
        'languageCode': _normalizedLocale(locale),
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': latitude,
              'longitude': longitude,
            },
            'radius': radiusMeters.toDouble(),
          },
        },
      }),
    );

    return _decodePlacesResponse(response);
  }

  Future<List<Map<String, dynamic>>> _performNearbyTextFallbacks(
    http.Client client, {
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String locale,
  }) async {
    final merged = <Map<String, dynamic>>[];
    final seenIds = <String>{};

    for (final query in _nearbyFallbackQueries) {
      final responsePlaces = await _performTextSearch(
        client,
        query: query,
        locale: locale,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        maxResults: 8,
      );

      for (final place in responsePlaces) {
        final id = place['id']?.toString() ?? '';
        if (id.isEmpty || !seenIds.add(id)) continue;
        merged.add(place);
      }

      if (merged.length >= 12) {
        break;
      }
    }

    return merged;
  }

  Future<List<Map<String, dynamic>>> _performTextSearch(
    http.Client client, {
    required String query,
    required String locale,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    int maxResults = 12,
  }) async {
    final body = <String, dynamic>{
      'textQuery': query,
      'maxResultCount': maxResults,
      'languageCode': _normalizedLocale(locale),
      'includedType': 'car_repair',
      'strictTypeFiltering': false,
    };

    if (latitude != null && longitude != null) {
      body['rankPreference'] = 'DISTANCE';
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': latitude,
            'longitude': longitude,
          },
          'radius': (radiusMeters ?? 50000).toDouble(),
        },
      };
    }

    final response = await client.post(
      Uri.parse('https://places.googleapis.com/v1/places:searchText'),
      headers: _jsonHeaders(
        'places.id,places.displayName,places.formattedAddress,places.location',
      ),
      body: jsonEncode(body),
    );

    return _decodePlacesResponse(response);
  }

  Future<List<WorkshopModel>> _hydratePlaces(
    http.Client client,
    List<Map<String, dynamic>> places, {
    required String locale,
    double? originLatitude,
    double? originLongitude,
    int? radiusMeters,
  }) async {
    if (places.isEmpty) {
      return const [];
    }

    final uniquePlaces = <String, Map<String, dynamic>>{};
    for (final place in places) {
      final id = place['id']?.toString() ?? '';
      if (id.isEmpty || uniquePlaces.containsKey(id)) continue;
      uniquePlaces[id] = place;
      if (uniquePlaces.length >= 12) break;
    }

    final placeIds = uniquePlaces.keys.toList(growable: false);
    final placeDetails = await Future.wait(
      placeIds.map(
        (placeId) => _fetchPlaceDetails(
          client,
          placeId: placeId,
          locale: locale,
        ),
      ),
    );

    final detailsById = <String, Map<String, dynamic>>{
      for (final detail in placeDetails)
        if (detail != null) detail['id']?.toString() ?? '': detail,
    }..remove('');

    final results = <WorkshopModel>[];
    for (final entry in uniquePlaces.entries) {
      final workshop = _toWorkshopModel(
        rawPlace: entry.value,
        details: detailsById[entry.key],
        originLatitude: originLatitude,
        originLongitude: originLongitude,
      );
      if (workshop == null) continue;

      if (radiusMeters != null &&
          workshop.distanceKm != null &&
          workshop.distanceKm! > radiusMeters / 1000) {
        continue;
      }

      results.add(workshop);
    }

    results.sort((left, right) {
      final leftDistance = left.distanceKm;
      final rightDistance = right.distanceKm;
      if (leftDistance != null && rightDistance != null) {
        final byDistance = leftDistance.compareTo(rightDistance);
        if (byDistance != 0) return byDistance;
      } else if (leftDistance != null) {
        return -1;
      } else if (rightDistance != null) {
        return 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return results;
  }

  Future<Map<String, dynamic>?> _fetchPlaceDetails(
    http.Client client, {
    required String placeId,
    required String locale,
  }) async {
    final response = await client.get(
      Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
      headers: _jsonHeaders(
        'id,formattedAddress,addressComponents,location,rating,internationalPhoneNumber,nationalPhoneNumber,currentOpeningHours,businessStatus',
        includeContentType: false,
        languageCode: _normalizedLocale(locale),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  WorkshopModel? _toWorkshopModel({
    required Map<String, dynamic> rawPlace,
    Map<String, dynamic>? details,
    double? originLatitude,
    double? originLongitude,
  }) {
    final merged = <String, dynamic>{
      ...rawPlace,
      if (details != null) ...details,
    };

    final id = merged['id']?.toString().trim() ?? '';
    final name = _displayNameFrom(merged).trim();
    final address = (merged['formattedAddress']?.toString() ?? '').trim();
    final location = merged['location'];
    final latitude = _asDouble(location is Map ? location['latitude'] : null);
    final longitude = _asDouble(location is Map ? location['longitude'] : null);

    if (id.isEmpty || name.isEmpty || address.isEmpty) {
      return null;
    }

    final distanceKm = originLatitude != null &&
            originLongitude != null &&
            latitude != null &&
            longitude != null
        ? Geolocator.distanceBetween(
              originLatitude,
              originLongitude,
              latitude,
              longitude,
            ) /
            1000
        : null;

    final phone = _firstNonEmptyString([
      merged['internationalPhoneNumber']?.toString(),
      merged['nationalPhoneNumber']?.toString(),
    ]);

    return WorkshopModel(
      id: id,
      name: name,
      email: '',
      phone: phone ?? '',
      address: address,
      city: _cityFromPlace(merged, fallbackAddress: address),
      latitude: latitude,
      longitude: longitude,
      rating: _asDouble(merged['rating']),
      isOpen: _openStateFromPlace(merged),
      distanceKm: distanceKm,
    );
  }

  List<Map<String, dynamic>> _decodePlacesResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final places = decoded['places'];
    if (places is! List) {
      return const [];
    }

    return places.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Map<String, String> _jsonHeaders(
    String fieldMask, {
    bool includeContentType = true,
    String? languageCode,
  }) {
    return {
      if (includeContentType) 'Content-Type': 'application/json',
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask': fieldMask,
      if (languageCode != null) 'Accept-Language': languageCode,
    };
  }

  String _displayNameFrom(Map<String, dynamic> place) {
    final displayName = place['displayName'];
    if (displayName is Map<String, dynamic>) {
      return displayName['text']?.toString() ?? '';
    }
    return displayName?.toString() ?? '';
  }

  String _cityFromPlace(
    Map<String, dynamic> place, {
    required String fallbackAddress,
  }) {
    final components = place['addressComponents'];
    if (components is List) {
      final postalCode = _firstComponentByType(
        components,
        const ['postal_code'],
      );
      final locality = _firstComponentByType(
        components,
        const [
          'locality',
          'postal_town',
          'administrative_area_level_3',
          'administrative_area_level_2',
        ],
      );

      if (postalCode != null && locality != null) {
        return '$postalCode $locality';
      }
      if (locality != null) return locality;
      if (postalCode != null) return postalCode;
    }

    final addressParts = fallbackAddress
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (addressParts.length >= 2) {
      return addressParts[addressParts.length - 2];
    }
    return fallbackAddress;
  }

  String? _firstComponentByType(List<dynamic> components, List<String> types) {
    for (final component in components.whereType<Map<String, dynamic>>()) {
      final componentTypes = component['types'];
      if (componentTypes is! List) continue;
      final hasType = componentTypes.any((value) => types.contains(value));
      if (!hasType) continue;

      final longText = component['longText']?.toString().trim();
      if (longText?.isNotEmpty == true) return longText;

      final shortText = component['shortText']?.toString().trim();
      if (shortText?.isNotEmpty == true) return shortText;
    }
    return null;
  }

  bool? _openStateFromPlace(Map<String, dynamic> place) {
    final currentOpeningHours = place['currentOpeningHours'];
    if (currentOpeningHours is Map<String, dynamic>) {
      final openNow = currentOpeningHours['openNow'];
      if (openNow is bool) {
        return openNow;
      }
    }

    final businessStatus = place['businessStatus']?.toString();
    if (businessStatus == 'CLOSED_PERMANENTLY' ||
        businessStatus == 'CLOSED_TEMPORARILY') {
      return false;
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String? _firstNonEmptyString(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed?.isNotEmpty == true) {
        return trimmed;
      }
    }
    return null;
  }

  String _normalizedLocale(String locale) {
    switch (locale.toLowerCase()) {
      case 'it':
      case 'de':
      case 'fr':
      case 'en':
        return locale.toLowerCase();
      default:
        return 'en';
    }
  }
}
