import 'dart:convert';

import 'package:cid_digitale/config/google_places_api_key.dart';
import 'package:cid_digitale/models/workshop_model.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum PlacesSearchIssueType {
  missingApiKey,
  apiError,
  networkError,
  invalidResponse,
}

class PlacesSearchIssue {
  const PlacesSearchIssue({
    required this.type,
    required this.message,
    this.requestType,
    this.query,
    this.statusCode,
    this.responseBody,
  });

  final PlacesSearchIssueType type;
  final String message;
  final String? requestType;
  final String? query;
  final int? statusCode;
  final String? responseBody;
}

class PlacesWorkshopSearchService {
  PlacesWorkshopSearchService({
    http.Client? client,
    String? apiKey,
  })  : _client = client,
        _apiKeyOverride = apiKey;

  static const String _searchCountry = 'Switzerland';
  static const String _searchRegionCode = 'CH';

  static const List<int> _nearbyRadiusMeters = [
    10000,
    25000,
    50000,
  ];

  static const List<String> _manualSearchKeywords = [
    'garage',
    'car repair',
    'auto repair',
    'body shop',
    'car service',
    'autowerkstatt',
    'carrosserie',
    'officina',
    'werkstatt',
    'atelier',
  ];

  final http.Client? _client;
  final String? _apiKeyOverride;

  PlacesSearchIssue? _lastIssue;
  PlacesSearchIssue? _pendingIssue;

  String get _apiKey {
    final override = _apiKeyOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    return kGooglePlacesApiKey.trim();
  }

  bool get isConfigured => _apiKey.isNotEmpty;
  PlacesSearchIssue? get lastIssue => _lastIssue;

  void clearLastIssue() {
    _lastIssue = null;
    _pendingIssue = null;
  }

  Future<List<WorkshopModel>> searchNearbyWorkshops({
    required double latitude,
    required double longitude,
    required String locale,
    String? cityHint,
  }) async {
    _beginSearch();

    final requestQuery =
        'lat=$latitude lng=$longitude radii=${_nearbyRadiusMeters.join(",")}';
    if (!_ensureConfigured(
      requestType: 'searchNearby',
      query: requestQuery,
    )) {
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
          return _finishSuccessfulSearch(nearbyResults);
        }

        final fallbackResults = await _runTextSearchQueries(
          client,
          queries: _buildNearbyFallbackQueries(cityHint),
          locale: locale,
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
        );
        if (fallbackResults.isNotEmpty) {
          return _finishSuccessfulSearch(fallbackResults);
        }
      }

      return _finishEmptySearch();
    } catch (error, stackTrace) {
      _recordIssue(
        PlacesSearchIssue(
          type: PlacesSearchIssueType.networkError,
          message: 'Nearby search failed with an unexpected error.',
          requestType: 'searchNearby',
          query: requestQuery,
          responseBody: error.toString(),
        ),
        stackTrace: stackTrace,
      );
      return _finishEmptySearch();
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
    _beginSearch();

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    if (!_ensureConfigured(
      requestType: 'searchText',
      query: trimmedQuery,
    )) {
      return const [];
    }

    final client = _client ?? http.Client();
    try {
      final results = await _runTextSearchQueries(
        client,
        queries: [
          _buildPrimaryTextQuery(trimmedQuery),
          ..._buildFallbackTextQueries(trimmedQuery),
        ],
        locale: locale,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: latitude != null && longitude != null ? 50000 : null,
      );

      if (results.isNotEmpty) {
        return _finishSuccessfulSearch(results);
      }

      return _finishEmptySearch();
    } catch (error, stackTrace) {
      _recordIssue(
        PlacesSearchIssue(
          type: PlacesSearchIssueType.networkError,
          message: 'Text search failed with an unexpected error.',
          requestType: 'searchText',
          query: trimmedQuery,
          responseBody: error.toString(),
        ),
        stackTrace: stackTrace,
      );
      return _finishEmptySearch();
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  Future<List<WorkshopModel>> _runTextSearchQueries(
    http.Client client, {
    required List<String> queries,
    required String locale,
    double? latitude,
    double? longitude,
    int? radiusMeters,
  }) async {
    final seenQueries = <String>{};

    for (final query in queries) {
      final trimmedQuery = query.trim();
      final normalizedKey = trimmedQuery.toLowerCase();
      if (trimmedQuery.isEmpty || !seenQueries.add(normalizedKey)) {
        continue;
      }

      final places = await _performTextSearch(
        client,
        query: trimmedQuery,
        locale: locale,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        maxResults: 20,
      );

      final results = await _hydratePlaces(
        client,
        places,
        locale: locale,
        originLatitude: latitude,
        originLongitude: longitude,
        radiusMeters: radiusMeters,
      );
      if (results.isNotEmpty) {
        return results;
      }
    }

    return const [];
  }

  Future<List<Map<String, dynamic>>> _performNearbySearch(
    http.Client client, {
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String locale,
  }) async {
    final query =
        'lat=$latitude lng=$longitude radius=$radiusMeters includedTypes=car_repair';
    final response = await _postJson(
      client,
      uri: Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
      headers: _jsonHeaders(_searchFieldMask),
      body: jsonEncode({
        'includedTypes': ['car_repair'],
        'maxResultCount': 20,
        'rankPreference': 'DISTANCE',
        'languageCode': _normalizedLocale(locale),
        'regionCode': _searchRegionCode,
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
      requestType: 'searchNearby',
      query: query,
    );

    if (response == null) {
      return const [];
    }

    return _decodePlacesResponse(
      response,
      requestType: 'searchNearby',
      query: query,
    );
  }

  Future<List<Map<String, dynamic>>> _performTextSearch(
    http.Client client, {
    required String query,
    required String locale,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    int maxResults = 20,
  }) async {
    final body = <String, dynamic>{
      'textQuery': query,
      'languageCode': _normalizedLocale(locale),
      'regionCode': _searchRegionCode,
      'maxResultCount': maxResults,
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

    final response = await _postJson(
      client,
      uri: Uri.parse('https://places.googleapis.com/v1/places:searchText'),
      headers: _jsonHeaders(_searchFieldMask),
      body: jsonEncode(body),
      requestType: 'searchText',
      query: query,
    );

    if (response == null) {
      return const [];
    }

    return _decodePlacesResponse(
      response,
      requestType: 'searchText',
      query: query,
    );
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
      if (uniquePlaces.length >= 20) break;
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
    final response = await _getJson(
      client,
      uri: Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
      headers: _jsonHeaders(
        'id,formattedAddress,addressComponents,location,rating,internationalPhoneNumber,nationalPhoneNumber,currentOpeningHours,businessStatus',
        includeContentType: false,
        languageCode: _normalizedLocale(locale),
      ),
      requestType: 'placeDetails',
      query: placeId,
    );

    if (response == null) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _recordHttpFailure(
        requestType: 'placeDetails',
        query: placeId,
        response: response,
      );
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    _recordIssue(
      PlacesSearchIssue(
        type: PlacesSearchIssueType.invalidResponse,
        message: 'Google Place Details returned an unexpected payload.',
        requestType: 'placeDetails',
        query: placeId,
        statusCode: response.statusCode,
        responseBody: response.body,
      ),
    );
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

  List<Map<String, dynamic>> _decodePlacesResponse(
    http.Response response, {
    required String requestType,
    required String query,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _recordHttpFailure(
        requestType: requestType,
        query: query,
        response: response,
      );
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      _recordIssue(
        PlacesSearchIssue(
          type: PlacesSearchIssueType.invalidResponse,
          message: 'Google Places returned a non-object JSON response.',
          requestType: requestType,
          query: query,
          statusCode: response.statusCode,
          responseBody: response.body,
        ),
      );
      return const [];
    }

    final places = decoded['places'];
    if (places is! List) {
      return const [];
    }

    return places.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<http.Response?> _postJson(
    http.Client client, {
    required Uri uri,
    required Map<String, String> headers,
    required String body,
    required String requestType,
    required String query,
  }) async {
    try {
      debugPrint(
        '[Places] requestHeaders type=$requestType headers=${_maskedHeaders(headers)}',
      );
      debugPrint(
        '[Places] request type=$requestType query="$query" url=$uri body=$body',
      );
      final response = await client.post(
        uri,
        headers: headers,
        body: body,
      );
      debugPrint(
        '[Places] response type=$requestType statusCode=${response.statusCode} body=${response.body}',
      );
      return response;
    } catch (error, stackTrace) {
      _recordIssue(
        PlacesSearchIssue(
          type: PlacesSearchIssueType.networkError,
          message: 'Google Places request failed before receiving a response.',
          requestType: requestType,
          query: query,
          responseBody: error.toString(),
        ),
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<http.Response?> _getJson(
    http.Client client, {
    required Uri uri,
    required Map<String, String> headers,
    required String requestType,
    required String query,
  }) async {
    try {
      debugPrint(
        '[Places] requestHeaders type=$requestType headers=${_maskedHeaders(headers)}',
      );
      debugPrint(
        '[Places] request type=$requestType query="$query" url=$uri',
      );
      final response = await client.get(
        uri,
        headers: headers,
      );
      debugPrint(
        '[Places] response type=$requestType statusCode=${response.statusCode} body=${response.body}',
      );
      return response;
    } catch (error, stackTrace) {
      _recordIssue(
        PlacesSearchIssue(
          type: PlacesSearchIssueType.networkError,
          message: 'Google Places request failed before receiving a response.',
          requestType: requestType,
          query: query,
          responseBody: error.toString(),
        ),
        stackTrace: stackTrace,
      );
      return null;
    }
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

  String get _searchFieldMask =>
      'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.internationalPhoneNumber,places.currentOpeningHours,places.addressComponents,places.businessStatus';

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

  String _buildPrimaryTextQuery(String rawQuery) {
    final normalizedInput = _normalizedSwissLocation(rawQuery);
    final lowerInput = normalizedInput.toLowerCase();
    final hasWorkshopKeyword = _manualSearchKeywords.any(lowerInput.contains);
    final query = hasWorkshopKeyword
        ? normalizedInput
        : 'garage car repair auto repair body shop $normalizedInput';
    return _appendCountry(query);
  }

  List<String> _buildFallbackTextQueries(String rawQuery) {
    final normalizedInput = _normalizedSwissLocation(rawQuery);
    return [
      'Autowerkstatt $normalizedInput Schweiz',
      'Garage $normalizedInput Schweiz',
      'Carrosserie $normalizedInput Schweiz',
    ];
  }

  List<String> _buildNearbyFallbackQueries(String? cityHint) {
    final normalizedCityHint = _normalizedSwissLocation(cityHint ?? '');
    if (normalizedCityHint.isEmpty) {
      return const [
        'garage car repair auto repair body shop Switzerland',
        'Autowerkstatt Schweiz',
        'Garage Schweiz',
        'Carrosserie Schweiz',
      ];
    }

    return [
      'garage car repair auto repair body shop $normalizedCityHint Switzerland',
      'Autowerkstatt $normalizedCityHint Schweiz',
      'Garage $normalizedCityHint Schweiz',
      'Carrosserie $normalizedCityHint Schweiz',
    ];
  }

  String _normalizedSwissLocation(String rawInput) {
    return rawInput
        .replaceAll(
          RegExp(
            r'\b(switzerland|schweiz|svizzera|suisse)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _appendCountry(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return trimmedQuery;
    }

    final lowerQuery = trimmedQuery.toLowerCase();
    const countryTokens = [
      'switzerland',
      'schweiz',
      'svizzera',
      'suisse',
    ];
    if (countryTokens.any(lowerQuery.contains)) {
      return trimmedQuery;
    }

    return '$trimmedQuery $_searchCountry';
  }

  void _beginSearch() {
    _lastIssue = null;
    _pendingIssue = null;
    _logApiKeyDiagnostics();
  }

  void _logApiKeyDiagnostics() {
    final apiKey = _apiKey;
    final firstCharacters = apiKey.isEmpty
        ? ''
        : apiKey.substring(0, apiKey.length < 5 ? apiKey.length : 5);
    final lastCharacters = apiKey.isEmpty
        ? ''
        : apiKey.substring(apiKey.length < 5 ? 0 : apiKey.length - 5);

    debugPrint(
      '[Places] apiKey.isEmpty=${apiKey.isEmpty} apiKey.length=${apiKey.length} apiKey.first5=$firstCharacters apiKey.last5=$lastCharacters',
    );
  }

  Map<String, String> _maskedHeaders(Map<String, String> headers) {
    return headers.map((key, value) {
      if (key.toLowerCase() == 'x-goog-api-key') {
        return MapEntry(key, _maskedKeyPreview(value));
      }
      return MapEntry(key, value);
    });
  }

  String _maskedKeyPreview(String value) {
    if (value.isEmpty) {
      return '<empty>';
    }

    final start = value.substring(0, value.length < 5 ? value.length : 5);
    final end = value.substring(value.length < 5 ? 0 : value.length - 5);
    return '$start...$end';
  }

  bool _ensureConfigured({
    required String requestType,
    required String query,
  }) {
    if (isConfigured) {
      return true;
    }

    final issue = PlacesSearchIssue(
      type: PlacesSearchIssueType.missingApiKey,
      message: 'GOOGLE_PLACES_API_KEY is empty or missing.',
      requestType: requestType,
      query: query,
    );
    _recordIssue(issue);
    _lastIssue = issue;
    _pendingIssue = null;
    return false;
  }

  List<WorkshopModel> _finishSuccessfulSearch(List<WorkshopModel> results) {
    _lastIssue = null;
    _pendingIssue = null;
    return results;
  }

  List<WorkshopModel> _finishEmptySearch() {
    _lastIssue = _pendingIssue;
    _pendingIssue = null;
    return const [];
  }

  void _recordHttpFailure({
    required String requestType,
    required String query,
    required http.Response response,
  }) {
    final issue = PlacesSearchIssue(
      type: PlacesSearchIssueType.apiError,
      message:
          'Google Places returned an HTTP error for $requestType (${response.statusCode}).',
      requestType: requestType,
      query: query,
      statusCode: response.statusCode,
      responseBody: response.body,
    );
    _recordIssue(issue);
  }

  void _recordIssue(
    PlacesSearchIssue issue, {
    StackTrace? stackTrace,
  }) {
    _pendingIssue = issue;

    final buffer = StringBuffer('[Places] ${issue.message}');
    if (issue.requestType?.isNotEmpty == true) {
      buffer.write(' requestType=${issue.requestType}');
    }
    if (issue.query?.isNotEmpty == true) {
      buffer.write(' query="${issue.query}"');
    }
    if (issue.statusCode != null) {
      buffer.write(' statusCode=${issue.statusCode}');
      if (issue.statusCode == 400 ||
          issue.statusCode == 401 ||
          issue.statusCode == 403) {
        buffer.write(' googleError=true');
      }
    }
    if (issue.responseBody?.isNotEmpty == true) {
      buffer.write(' body=${issue.responseBody}');
    }

    debugPrint(buffer.toString());
    if (stackTrace != null) {
      debugPrint('[Places] stackTrace=$stackTrace');
    }
  }
}
