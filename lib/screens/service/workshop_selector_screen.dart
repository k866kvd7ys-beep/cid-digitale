import 'dart:async';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/services/device_location_service.dart';
import 'package:cid_digitale/services/places_workshop_search_service.dart';
import 'package:cid_digitale/services/preferred_workshop_repository.dart';
import 'package:cid_digitale/services/workshop_catalog_service.dart';
import 'package:cid_digitale/widgets/preferred_workshop_card.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'workshop_slot_picker_screen.dart';

Future<void> openWorkshopSelectionStep(
  BuildContext context, {
  required String title,
  required String serviceType,
  String? damageType,
  String? tireServiceType,
  String? serviceSelectionKey,
  String? serviceDetail,
  String? cleaningPackage,
  List<String> additionalServices = const [],
  WorkshopModel? preselectedWorkshop,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => WorkshopSelectorScreen(
        title: title,
        serviceType: serviceType,
        damageType: damageType,
        tireServiceType: tireServiceType,
        serviceSelectionKey: serviceSelectionKey,
        serviceDetail: serviceDetail,
        cleaningPackage: cleaningPackage,
        additionalServices: additionalServices,
        preselectedWorkshop: preselectedWorkshop,
      ),
    ),
  );
}

class WorkshopSelectorScreen extends StatefulWidget {
  const WorkshopSelectorScreen({
    super.key,
    required this.title,
    required this.serviceType,
    this.damageType,
    this.tireServiceType,
    this.serviceSelectionKey,
    this.serviceDetail,
    this.cleaningPackage,
    this.additionalServices = const [],
    this.preselectedWorkshop,
    this.selectionOnly = false,
    this.preferredWorkshopRepository,
  });

  final String title;
  final String serviceType;
  final String? damageType;
  final String? tireServiceType;
  final String? serviceSelectionKey;
  final String? serviceDetail;
  final String? cleaningPackage;
  final List<String> additionalServices;
  final WorkshopModel? preselectedWorkshop;
  final bool selectionOnly;
  final PreferredWorkshopRepository? preferredWorkshopRepository;

  @override
  State<WorkshopSelectorScreen> createState() => _WorkshopSelectorScreenState();
}

class _WorkshopSelectorScreenState extends State<WorkshopSelectorScreen> {
  static const Color _background = Color(0xFFF6FAFE);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textGray = Color(0xFF64748B);
  static const Color _border = Color(0xFFDCE7F5);

  final WorkshopCatalogService _catalogService = WorkshopCatalogService();
  final DeviceLocationService _deviceLocationService =
      const DeviceLocationService();
  final PlacesWorkshopSearchService _placesService =
      PlacesWorkshopSearchService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<WorkshopModel> _catalogWorkshops = const [];
  List<WorkshopModel> _nearbyRemoteWorkshops = const [];
  List<WorkshopModel> _textRemoteWorkshops = const [];
  WorkshopModel? _selectedWorkshop;
  WorkshopModel? _preferredWorkshop;
  Position? _currentPosition;
  PreferredWorkshopRepository? _preferredWorkshopRepository;

  String _query = '';
  bool _isLoadingCatalog = true;
  bool _isResolvingLocation = false;
  bool _isSearchingNearby = false;
  bool _isSearchingText = false;
  bool _didRunNearbySearch = false;

  String _copy({
    required String it,
    required String de,
    required String fr,
    required String en,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'it':
        return it;
      case 'fr':
        return fr;
      case 'en':
        return en;
      case 'de':
      default:
        return de;
    }
  }

  String get _localeCode => Localizations.localeOf(context).languageCode;

  String get _screenTitle => _copy(
        it: 'Scegli la tua officina',
        de: 'Werkstatt auswählen',
        fr: 'Choisissez votre atelier',
        en: 'Choose your workshop',
      );

  String get _screenSubtitle => _copy(
        it: 'Seleziona l\'officina dove desideri effettuare il servizio.',
        de: 'Wählen Sie die Werkstatt aus, bei der Sie den Service durchführen möchten.',
        fr: 'Sélectionnez l\'atelier dans lequel vous souhaitez effectuer le service.',
        en: 'Select the workshop where you would like the service to be performed.',
      );

  String get _searchPlaceholder => _copy(
        it: 'Cerca un\'officina...',
        de: 'Werkstatt suchen...',
        fr: 'Rechercher un atelier...',
        en: 'Search for a workshop...',
      );

  String get _useLocationLabel => _copy(
        it: 'Usa la mia posizione',
        de: 'Meinen Standort verwenden',
        fr: 'Utiliser ma position',
        en: 'Use my location',
      );

  String get _locationUnavailableSnack => _copy(
        it: 'Impossibile ottenere la posizione corrente.',
        de: 'Aktueller Standort konnte nicht ermittelt werden.',
        fr: 'Impossible d\'obtenir la position actuelle.',
        en: 'Unable to get your current location.',
      );

  String get _searchingNearbyLabel => _copy(
        it: 'Ricerca officine vicino a te...',
        de: 'Werkstätten in deiner Nähe werden gesucht...',
        fr: 'Recherche d\'ateliers près de vous...',
        en: 'Searching workshops near you...',
      );

  String get _searchingTextLabel => _copy(
        it: 'Ricerca officine...',
        de: 'Werkstätten werden gesucht...',
        fr: 'Recherche d\'ateliers...',
        en: 'Searching workshops...',
      );

  String get _noNearbyResultsLabel => _copy(
        it: 'Nessuna officina trovata entro 50 km. Prova a cercare per città o nome officina.',
        de: 'Keine Werkstatt innerhalb von 50 km gefunden. Suche stattdessen nach Stadt oder Werkstattname.',
        fr: 'Aucun atelier trouvé dans un rayon de 50 km. Essayez une recherche par ville ou nom d\'atelier.',
        en: 'No workshop found within 50 km. Try searching by city or workshop name.',
      );

  String get _placesUnavailableNotice => _copy(
        it: 'Ricerca officine temporaneamente non disponibile. Verifica configurazione Google Places.',
        de: 'Die Werkstattsuche ist vorübergehend nicht verfügbar. Bitte prüfe die Google-Places-Konfiguration.',
        fr: 'La recherche d\'ateliers est temporairement indisponible. Vérifiez la configuration Google Places.',
        en: 'Workshop search is temporarily unavailable. Check the Google Places configuration.',
      );

  String get _placesUnavailableEmptyState => _copy(
        it: 'Ricerca officine temporaneamente non disponibile. Verifica configurazione Google Places.',
        de: 'Die Werkstattsuche ist vorübergehend nicht verfügbar. Bitte prüfe die Google-Places-Konfiguration.',
        fr: 'La recherche d\'ateliers est temporairement indisponible. Vérifiez la configuration Google Places.',
        en: 'Workshop search is temporarily unavailable. Check the Google Places configuration.',
      );

  String get _openLabel => _copy(
        it: 'Aperto',
        de: 'Geöffnet',
        fr: 'Ouvert',
        en: 'Open',
      );

  String get _closedLabel => _copy(
        it: 'Chiuso',
        de: 'Geschlossen',
        fr: 'Fermé',
        en: 'Closed',
      );

  String get _selectLabel => _copy(
        it: 'Seleziona',
        de: 'Auswählen',
        fr: 'Sélectionner',
        en: 'Select',
      );

  String get _selectedLabel => _copy(
        it: 'Officina selezionata',
        de: 'Werkstatt ausgewählt',
        fr: 'Atelier sélectionné',
        en: 'Workshop selected',
      );

  String get _continueLabel => _copy(
        it: 'Continua',
        de: 'Weiter',
        fr: 'Continuer',
        en: 'Continue',
      );

  String get _emptyTitle => _copy(
        it: 'Nessuna officina trovata',
        de: 'Keine Werkstatt gefunden',
        fr: 'Aucun atelier trouvé',
        en: 'No workshop found',
      );

  String get _emptySubtitle => _copy(
        it: 'Prova con un altro nome, indirizzo o città.',
        de: 'Versuchen Sie es mit einem anderen Namen, einer Adresse oder einer Stadt.',
        fr: 'Essayez avec un autre nom, une autre adresse ou une autre ville.',
        en: 'Try another name, address or city.',
      );

  String get _continueHint => _copy(
        it: 'Seleziona un\'officina per scegliere data e orario.',
        de: 'Wählen Sie eine Werkstatt aus, um Datum und Uhrzeit festzulegen.',
        fr: 'Sélectionnez un atelier pour choisir la date et l’heure.',
        en: 'Select a workshop to choose date and time.',
      );

  @override
  void initState() {
    super.initState();
    _selectedWorkshop =
        widget.selectionOnly ? null : widget.preselectedWorkshop;
    _searchController.addListener(_handleSearchChanged);
    _loadCatalog();
    if (!widget.selectionOnly) {
      _preferredWorkshopRepository = widget.preferredWorkshopRepository ??
          SupabasePreferredWorkshopRepository();
      unawaited(_loadPreferredWorkshop());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final workshops = await _catalogService.fetchWorkshops();
    if (!mounted) return;

    setState(() {
      _catalogWorkshops = _withDistance(workshops, _currentPosition);
      _isLoadingCatalog = false;
    });
  }

  Future<void> _loadPreferredWorkshop() async {
    try {
      final workshop = await _preferredWorkshopRepository!.load();
      if (!mounted) return;
      setState(() => _preferredWorkshop = workshop);
    } catch (_) {
      // The normal workshop search remains fully available.
    }
  }

  void _handleSearchChanged() {
    final nextQuery = _searchController.text;
    _searchDebounce?.cancel();

    setState(() {
      _query = nextQuery;
    });

    final trimmedQuery = nextQuery.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _textRemoteWorkshops = const [];
        _isSearchingText = false;
      });
      return;
    }

    setState(() {
      _placesService.clearLastIssue();
      _isSearchingText = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 420), () {
      _searchRemoteByText(trimmedQuery);
    });
  }

  Future<void> _searchRemoteByText(String query) async {
    final results = await _placesService.searchWorkshopsByText(
      query: query,
      locale: _localeCode,
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );

    if (!mounted || _query.trim() != query) return;

    setState(() {
      _textRemoteWorkshops = results;
      _isSearchingText = false;
    });
  }

  Future<void> _handleUseLocation() async {
    if (_isResolvingLocation) return;

    debugPrint('[WorkshopGPS] start');

    _searchDebounce?.cancel();
    if (_query.trim().isNotEmpty) {
      _searchController.clear();
    }

    setState(() {
      _placesService.clearLastIssue();
      _isResolvingLocation = true;
      _isSearchingNearby = true;
      _didRunNearbySearch = false;
      _textRemoteWorkshops = const [];
      _isSearchingText = false;
    });

    try {
      final locationResult =
          await _deviceLocationService.requestCurrentPosition();
      if (!locationResult.serviceEnabled) {
        debugPrint('[WorkshopGPS] permission denied service-disabled');
        if (!mounted) return;
        setState(() {
          _isResolvingLocation = false;
          _isSearchingNearby = false;
        });
        return;
      }

      if (!locationResult.permissionGranted || locationResult.position == null) {
        debugPrint(
          locationResult.permissionGranted
              ? '[WorkshopGPS] permission granted but coordinates unavailable'
              : '[WorkshopGPS] permission denied ${locationResult.permission}',
        );
        if (!mounted) return;
        setState(() {
          _isResolvingLocation = false;
          _isSearchingNearby = false;
        });
        _showLocationErrorSnack();
        return;
      }

      final position = locationResult.position!;
      debugPrint(
        '[WorkshopGPS] permission granted ${locationResult.permission}',
      );
      debugPrint(
        '[WorkshopGPS] coordinates received lat=${position.latitude}, lng=${position.longitude}',
      );

      final localWithDistance = _withDistance(_catalogWorkshops, position);
      final cityHint = await _deviceLocationService.resolveCityHint(position);
      debugPrint('[WorkshopGPS] search nearby started');

      List<WorkshopModel> nearbyResults = const [];
      try {
        nearbyResults = await _placesService.searchNearbyWorkshops(
          latitude: position.latitude,
          longitude: position.longitude,
          locale: _localeCode,
          cityHint: cityHint,
        );
        final issue = _placesService.lastIssue;
        if (issue != null) {
          debugPrint(
            '[WorkshopGPS] search nearby fail ${issue.type} ${issue.message}',
          );
        } else {
          debugPrint(
            '[WorkshopGPS] search nearby success count=${nearbyResults.length}',
          );
        }
      } catch (error, stackTrace) {
        debugPrint('[WorkshopGPS] search nearby fail $error\n$stackTrace');
      }

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _catalogWorkshops = localWithDistance;
        _nearbyRemoteWorkshops = nearbyResults;
        _didRunNearbySearch = true;
        _isResolvingLocation = false;
        _isSearchingNearby = false;
      });
    } on TimeoutException {
      debugPrint('[WorkshopGPS] search nearby fail timeout while requesting coordinates');
      if (!mounted) return;
      setState(() {
        _isResolvingLocation = false;
        _isSearchingNearby = false;
      });
      _showLocationErrorSnack();
    } catch (error, stackTrace) {
      debugPrint('[WorkshopGPS] search nearby fail $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isResolvingLocation = false;
        _isSearchingNearby = false;
      });
      _showLocationErrorSnack();
    }
  }

  List<WorkshopModel> _withDistance(
    List<WorkshopModel> workshops,
    Position? position,
  ) {
    return workshops.map((workshop) {
      if (position == null || !workshop.hasCoordinates) {
        return workshop.copyWith(clearDistanceKm: true);
      }

      final distanceKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            workshop.latitude!,
            workshop.longitude!,
          ) /
          1000;

      return workshop.copyWith(distanceKm: distanceKm);
    }).toList(growable: false);
  }

  void _showLocationErrorSnack() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _locationUnavailableSnack,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _continueToCalendar() {
    final workshop = _selectedWorkshop;
    if (workshop == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: widget.title,
          serviceType: widget.serviceType,
          damageType: widget.damageType,
          tireServiceType: widget.tireServiceType,
          serviceSelectionKey: widget.serviceSelectionKey,
          serviceDetail: widget.serviceDetail,
          cleaningPackage: widget.cleaningPackage,
          additionalServices: widget.additionalServices,
          selectedWorkshop: workshop,
        ),
      ),
    );
  }

  void _usePreferredWorkshop() {
    final workshop = _preferredWorkshop;
    if (workshop == null) return;
    setState(() => _selectedWorkshop = workshop);
  }

  List<WorkshopModel> _visibleWorkshops() {
    final localMatches = _query.trim().isEmpty
        ? _catalogWorkshops
        : _catalogWorkshops
            .where((workshop) => workshop.matchesQuery(_query))
            .toList(growable: false);

    final remoteMatches =
        _query.trim().isEmpty ? _nearbyRemoteWorkshops : _textRemoteWorkshops;

    final merged = <String, WorkshopModel>{};
    for (final workshop in [...remoteMatches, ...localMatches]) {
      final key = _mergeKey(workshop);
      final existing = merged[key];
      merged[key] = existing == null
          ? workshop
          : _mergeWorkshopRecords(existing, workshop);
    }

    final results = merged.values.toList(growable: false);
    results.sort((left, right) {
      final leftDistance = left.distanceKm;
      final rightDistance = right.distanceKm;
      if (leftDistance != null && rightDistance != null) {
        final distanceCompare = leftDistance.compareTo(rightDistance);
        if (distanceCompare != 0) return distanceCompare;
      } else if (leftDistance != null) {
        return -1;
      } else if (rightDistance != null) {
        return 1;
      }

      final leftRating = left.rating;
      final rightRating = right.rating;
      if (leftRating != null && rightRating != null) {
        final ratingCompare = rightRating.compareTo(leftRating);
        if (ratingCompare != 0) return ratingCompare;
      } else if (leftRating != null) {
        return -1;
      } else if (rightRating != null) {
        return 1;
      }

      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return results;
  }

  WorkshopModel _mergeWorkshopRecords(
    WorkshopModel primary,
    WorkshopModel secondary,
  ) {
    final preferredDistance =
        switch ((primary.distanceKm, secondary.distanceKm)) {
      (final double left, final double right) => left < right ? left : right,
      (final double left, null) => left,
      (null, final double right) => right,
      _ => null,
    };

    return primary.copyWith(
      email: primary.hasEmail ? primary.email : secondary.email,
      phone: primary.hasPhone ? primary.phone : secondary.phone,
      address: primary.address.trim().isNotEmpty
          ? primary.address
          : secondary.address,
      city: primary.city.trim().isNotEmpty ? primary.city : secondary.city,
      rating: primary.rating ?? secondary.rating,
      isOpen: primary.isOpen ?? secondary.isOpen,
      latitude: primary.latitude ?? secondary.latitude,
      longitude: primary.longitude ?? secondary.longitude,
      distanceKm: preferredDistance,
    );
  }

  String _mergeKey(WorkshopModel workshop) {
    final normalizedName = workshop.name.trim().toLowerCase();
    final normalizedAddress = workshop.address.trim().toLowerCase();
    if (normalizedName.isNotEmpty && normalizedAddress.isNotEmpty) {
      return '$normalizedName|$normalizedAddress';
    }
    return workshop.id.trim().toLowerCase();
  }

  String? _distanceLabelFor(WorkshopModel workshop) {
    final distanceKm = workshop.distanceKm;
    if (distanceKm == null) {
      return null;
    }

    final meters = distanceKm * 1000;
    if (meters < 1000) {
      final metersLabel = NumberFormat.decimalPattern(_localeCode).format(
        meters.round(),
      );
      return '$metersLabel m';
    }

    final decimalDigits = distanceKm >= 10 ? 0 : 1;
    final kmLabel = NumberFormat.decimalPatternDigits(
      locale: _localeCode,
      decimalDigits: decimalDigits,
    ).format(distanceKm);
    return '$kmLabel km';
  }

  bool get _showNoNearbyResultNotice =>
      _didRunNearbySearch &&
      !_isSearchingNearby &&
      _query.trim().isEmpty &&
      _currentPosition != null &&
      _placesService.isConfigured &&
      _placesService.lastIssue == null &&
      _nearbyRemoteWorkshops.isEmpty;

  bool get _showPlacesUnavailableNotice =>
      _placesService.lastIssue != null &&
      (_query.trim().isNotEmpty || _didRunNearbySearch);

  @override
  Widget build(BuildContext context) {
    final workshops = _visibleWorkshops();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        title: Text(
          _screenTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
        ),
      ),
      bottomNavigationBar: widget.selectionOnly ? null : SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 26,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Text(
                  _selectedWorkshop?.name ?? _continueHint,
                  key: ValueKey(_selectedWorkshop?.id ?? 'continue-hint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _selectedWorkshop == null
                            ? _textGray
                            : const Color(0xFF1E3A8A),
                        fontWeight: _selectedWorkshop == null
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    _selectedWorkshop == null ? null : _continueToCalendar,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(
                    Size.fromHeight(56),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFFBFDBFE);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return _primaryDark;
                    }
                    if (states.contains(WidgetState.pressed)) {
                      return const Color(0xFF1E40AF);
                    }
                    return _primary;
                  }),
                  foregroundColor:
                      const WidgetStatePropertyAll<Color>(Colors.white),
                  elevation: const WidgetStatePropertyAll(0),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                child: Text(
                  _continueLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned(
            top: -110,
            right: -50,
            child: _AmbientGlow(
              diameter: 250,
              color: Color(0x332563EB),
            ),
          ),
          const Positioned(
            top: 190,
            left: -70,
            child: _AmbientGlow(
              diameter: 210,
              color: Color(0x1A38BDF8),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEEF6FF),
                    _background,
                  ],
                ),
              ),
              child: _isLoadingCatalog
                  ? const Center(
                      child: CircularProgressIndicator(color: _primary),
                    )
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 136),
                      children: [
                        _HeaderCard(
                          title: _screenTitle,
                          subtitle: _screenSubtitle,
                          searchField: _SearchField(
                            controller: _searchController,
                            hintText: _searchPlaceholder,
                          ),
                          locationButton: OutlinedButton.icon(
                            onPressed: _isResolvingLocation
                                ? null
                                : _handleUseLocation,
                            icon: _isResolvingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.1,
                                      color: _primary,
                                    ),
                                  )
                                : Icon(
                                    _currentPosition != null
                                        ? Icons.near_me_rounded
                                        : Icons.my_location_rounded,
                                    size: 18,
                                  ),
                            label: Text(
                              _useLocationLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ButtonStyle(
                              minimumSize: const WidgetStatePropertyAll(
                                Size.fromHeight(50),
                              ),
                              foregroundColor:
                                  const WidgetStatePropertyAll(_primary),
                              backgroundColor:
                                  const WidgetStatePropertyAll(Colors.white),
                              elevation: const WidgetStatePropertyAll(0),
                              side: WidgetStateProperty.resolveWith((states) {
                                if (_currentPosition != null) {
                                  return const BorderSide(
                                    color: Color(0xFF93C5FD),
                                  );
                                }
                                return const BorderSide(
                                  color: Color(0xFFD6E4FF),
                                );
                              }),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              overlayColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return _primary.withValues(alpha: 0.10);
                                }
                                if (states.contains(WidgetState.hovered)) {
                                  return _primary.withValues(alpha: 0.06);
                                }
                                return null;
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_preferredWorkshop != null) ...[
                          PreferredWorkshopCard(
                            key: const Key(
                              'booking_preferred_workshop_card',
                            ),
                            title: AppLocalizations.of(context)!
                                .preferredWorkshopYours,
                            workshop: _preferredWorkshop,
                            emptyMessage: AppLocalizations.of(context)!
                                .preferredWorkshopNone,
                            primaryActionLabel: AppLocalizations.of(context)!
                                .preferredWorkshopUse,
                            onPrimaryAction: _usePreferredWorkshop,
                            openLabel: AppLocalizations.of(context)!
                                .preferredWorkshopOpen,
                            closedLabel: AppLocalizations.of(context)!
                                .preferredWorkshopClosed,
                            statusUnavailableLabel:
                                AppLocalizations.of(context)!
                                    .preferredWorkshopStatusUnavailable,
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (_isSearchingNearby)
                          _NoticeCard(
                            icon: Icons.radar_rounded,
                            title: _searchingNearbyLabel,
                            accent: const Color(0xFFDBEAFE),
                            iconColor: _primary,
                            trailing: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _primary,
                              ),
                            ),
                          ),
                        if (_isSearchingText && !_isSearchingNearby)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _NoticeCard(
                              icon: Icons.travel_explore_rounded,
                              title: _searchingTextLabel,
                              accent: const Color(0xFFEFF6FF),
                              iconColor: _primary,
                              trailing: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              ),
                            ),
                          ),
                        if (_showNoNearbyResultNotice)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _NoticeCard(
                              icon: Icons.location_searching_rounded,
                              title: _noNearbyResultsLabel,
                              accent: const Color(0xFFFFF7ED),
                              iconColor: const Color(0xFFF59E0B),
                            ),
                          ),
                        if (_showPlacesUnavailableNotice)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _NoticeCard(
                              icon: Icons.sync_problem_rounded,
                              title: _placesUnavailableNotice,
                              accent: const Color(0xFFFFF7ED),
                              iconColor: const Color(0xFFF59E0B),
                            ),
                          ),
                        if (_isSearchingNearby ||
                            _isSearchingText ||
                            _showNoNearbyResultNotice ||
                            _showPlacesUnavailableNotice)
                          const SizedBox(height: 14),
                        if (workshops.isEmpty)
                          _EmptyStateCard(
                            title: _emptyTitle,
                            subtitle: _showNoNearbyResultNotice
                                ? _noNearbyResultsLabel
                                : _showPlacesUnavailableNotice
                                    ? _placesUnavailableEmptyState
                                    : _emptySubtitle,
                          )
                        else
                          ...workshops.map(
                            (workshop) => Padding(
                              key: Key('workshop_option_${workshop.id}'),
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _WorkshopOptionCard(
                                workshop: workshop,
                                distanceLabel: _distanceLabelFor(workshop),
                                selected: workshop.id == _selectedWorkshop?.id,
                                openLabel: _openLabel,
                                closedLabel: _closedLabel,
                                selectLabel: _selectLabel,
                                selectedLabel: _selectedLabel,
                                onSelect: () {
                                  if (widget.selectionOnly) {
                                    Navigator.of(context).pop(workshop);
                                  } else {
                                    setState(() {
                                      _selectedWorkshop = workshop;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 90,
              spreadRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.searchField,
    required this.locationButton,
  });

  final String title;
  final String subtitle;
  final Widget searchField;
  final Widget locationButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF9FBFF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE7F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  height: 1.42,
                ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 620) {
                return Row(
                  children: [
                    Expanded(flex: 5, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: locationButton),
                  ],
                );
              }

              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  locationButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF94A3B8),
              ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF64748B),
          ),
          suffixIcon: controller.text.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFFD5E2F2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFF60A5FA),
              width: 1.4,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Color(0xFFD5E2F2),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.accent,
    required this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE7F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE7F5)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.travel_explore_rounded,
            size: 42,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111827),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopOptionCard extends StatefulWidget {
  const _WorkshopOptionCard({
    required this.workshop,
    required this.selected,
    required this.openLabel,
    required this.closedLabel,
    required this.selectLabel,
    required this.selectedLabel,
    required this.onSelect,
    this.distanceLabel,
  });

  final WorkshopModel workshop;
  final String? distanceLabel;
  final bool selected;
  final String openLabel;
  final String closedLabel;
  final String selectLabel;
  final String selectedLabel;
  final VoidCallback onSelect;

  @override
  State<_WorkshopOptionCard> createState() => _WorkshopOptionCardState();
}

class _WorkshopOptionCardState extends State<_WorkshopOptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? const Color(0xFF93C5FD)
        : (_hovered ? const Color(0xFFBFDBFE) : const Color(0xFFDCE7F5));
    final fillColor = widget.selected
        ? const Color(0xFFF4F9FF)
        : Colors.white.withValues(alpha: 0.98);
    final shadowColor = widget.selected
        ? const Color(0x182563EB)
        : (_hovered ? const Color(0x160F172A) : const Color(0x0F0F172A));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: widget.selected ? 1 : (_hovered ? 1.008 : 1),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: borderColor,
              width: widget.selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: widget.selected ? 28 : 20,
                offset: Offset(0, widget.selected ? 16 : 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: widget.onSelect,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            widget.workshop.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                          ),
                        ),
                        if (widget.workshop.isOpen != null) ...[
                          const SizedBox(width: 12),
                          _WorkshopStatusBadge(
                            isOpen: widget.workshop.isOpen!,
                            openLabel: widget.openLabel,
                            closedLabel: widget.closedLabel,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _WorkshopInfoRow(
                      icon: Icons.location_on_outlined,
                      text: widget.workshop.locationLabel,
                    ),
                    if (widget.workshop.hasPhone) ...[
                      const SizedBox(height: 8),
                      _WorkshopInfoRow(
                        icon: Icons.phone_outlined,
                        text: widget.workshop.phone!.trim(),
                      ),
                    ],
                    if (widget.workshop.hasEmail) ...[
                      const SizedBox(height: 8),
                      _WorkshopInfoRow(
                        icon: Icons.alternate_email_rounded,
                        text: widget.workshop.email!.trim(),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (widget.workshop.rating != null)
                                _WorkshopMetricPill(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFF59E0B),
                                  text: widget.workshop.rating!
                                      .toStringAsFixed(1),
                                  textColor: const Color(0xFF92400E),
                                  backgroundColor: const Color(0xFFFFF7ED),
                                ),
                              if (widget.distanceLabel != null)
                                _WorkshopMetricPill(
                                  icon: Icons.near_me_rounded,
                                  iconColor: const Color(0xFF2563EB),
                                  text: widget.distanceLabel!,
                                  textColor: const Color(0xFF1D4ED8),
                                  backgroundColor: const Color(0xFFEFF6FF),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.96,
                                  end: 1,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: widget.selected
                              ? Container(
                                  key: const ValueKey('selected'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFBFDBFE),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.selectedLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: const Color(0xFF1D4ED8),
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                )
                              : FilledButton(
                                  key: const ValueKey('select'),
                                  onPressed: widget.onSelect,
                                  style: ButtonStyle(
                                    minimumSize: const WidgetStatePropertyAll(
                                      Size(128, 50),
                                    ),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(horizontal: 18),
                                    ),
                                    elevation: const WidgetStatePropertyAll(0),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.hovered)) {
                                          return const Color(0xFF1D4ED8);
                                        }
                                        if (states
                                            .contains(WidgetState.pressed)) {
                                          return const Color(0xFF1E40AF);
                                        }
                                        return const Color(0xFF2563EB);
                                      },
                                    ),
                                    foregroundColor:
                                        const WidgetStatePropertyAll(
                                      Colors.white,
                                    ),
                                  ),
                                  child: Text(
                                    widget.selectLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkshopStatusBadge extends StatelessWidget {
  const _WorkshopStatusBadge({
    required this.isOpen,
    required this.openLabel,
    required this.closedLabel,
  });

  final bool isOpen;
  final String openLabel;
  final String closedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFEAFBF1) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOpen ? const Color(0xFFCDEFD9) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 10,
            color: isOpen ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(
            isOpen ? openLabel : closedLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isOpen
                      ? const Color(0xFF166534)
                      : const Color(0xFF475569),
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopMetricPill extends StatelessWidget {
  const _WorkshopMetricPill({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.textColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkshopInfoRow extends StatelessWidget {
  const _WorkshopInfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                  height: 1.32,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
