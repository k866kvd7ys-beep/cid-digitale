import 'dart:async';

import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/services/workshop_catalog_service.dart';
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
  final TextEditingController _searchController = TextEditingController();

  late Future<List<WorkshopModel>> _workshopsFuture;
  List<WorkshopModel> _loadedWorkshops = const [];
  Map<String, double> _distanceMetersByWorkshopId = const {};
  String _query = '';
  WorkshopModel? _selectedWorkshop;
  bool _isResolvingLocation = false;

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

  Future<List<WorkshopModel>> _loadWorkshops() async {
    final workshops = await _catalogService.fetchWorkshops();
    _loadedWorkshops = workshops;
    return workshops;
  }

  @override
  void initState() {
    super.initState();
    _selectedWorkshop = widget.preselectedWorkshop;
    _workshopsFuture = _loadWorkshops();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleUseLocation() async {
    if (_isResolvingLocation) return;

    setState(() {
      _isResolvingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isResolvingLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isResolvingLocation = false;
        });
        _showLocationErrorSnack();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      final distanceMap = _buildDistanceMap(position);
      setState(() {
        _isResolvingLocation = false;
        if (distanceMap.isNotEmpty) {
          _distanceMetersByWorkshopId = distanceMap;
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isResolvingLocation = false;
      });
      _showLocationErrorSnack();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResolvingLocation = false;
      });
      _showLocationErrorSnack();
    }
  }

  Map<String, double> _buildDistanceMap(Position position) {
    final distances = <String, double>{};

    for (final workshop in _loadedWorkshops) {
      if (!workshop.hasCoordinates) continue;
      distances[workshop.id] = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        workshop.latitude!,
        workshop.longitude!,
      );
    }

    return distances;
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

  List<WorkshopModel> _visibleWorkshops(List<WorkshopModel> workshops) {
    final filtered = workshops
        .where((workshop) => workshop.matchesQuery(_query))
        .toList(growable: true);

    if (_distanceMetersByWorkshopId.isEmpty) {
      return filtered;
    }

    final originalIndex = <String, int>{
      for (var index = 0; index < filtered.length; index++)
        filtered[index].id: index,
    };

    filtered.sort((left, right) {
      final leftDistance = _distanceMetersByWorkshopId[left.id];
      final rightDistance = _distanceMetersByWorkshopId[right.id];

      if (leftDistance == null && rightDistance == null) {
        return originalIndex[left.id]!.compareTo(originalIndex[right.id]!);
      }
      if (leftDistance == null) return 1;
      if (rightDistance == null) return -1;

      final comparison = leftDistance.compareTo(rightDistance);
      if (comparison != 0) return comparison;

      return originalIndex[left.id]!.compareTo(originalIndex[right.id]!);
    });

    return filtered;
  }

  String? _distanceLabelFor(WorkshopModel workshop) {
    final meters = _distanceMetersByWorkshopId[workshop.id];
    if (meters == null) {
      return null;
    }

    final locale = Localizations.localeOf(context).languageCode;
    if (meters < 1000) {
      final metersLabel = NumberFormat.decimalPattern(locale).format(
        meters.round(),
      );
      return '$metersLabel m';
    }

    final km = meters / 1000;
    final decimalDigits = km >= 10 ? 0 : 1;
    final kmLabel = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimalDigits,
    ).format(km);
    return '$kmLabel km';
  }

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: SafeArea(
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
              child: FutureBuilder<List<WorkshopModel>>(
                future: _workshopsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _primary),
                    );
                  }

                  final workshops = _visibleWorkshops(
                    snapshot.data ?? _loadedWorkshops,
                  );

                  return ListView(
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
                          onPressed:
                              _isResolvingLocation ? null : _handleUseLocation,
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
                                  _distanceMetersByWorkshopId.isNotEmpty
                                      ? Icons.near_me_rounded
                                      : Icons.my_location_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _useLocationLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
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
                              if (_distanceMetersByWorkshopId.isNotEmpty) {
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
                            overlayColor: WidgetStateProperty.resolveWith(
                              (states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return _primary.withValues(alpha: 0.10);
                                }
                                if (states.contains(WidgetState.hovered)) {
                                  return _primary.withValues(alpha: 0.06);
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (workshops.isEmpty)
                        _EmptyStateCard(
                          title: _emptyTitle,
                          subtitle: _emptySubtitle,
                        )
                      else
                        ...workshops.map(
                          (workshop) => Padding(
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
                                setState(() {
                                  _selectedWorkshop = workshop;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
                        const SizedBox(width: 12),
                        _WorkshopStatusBadge(
                          isOpen: widget.workshop.isOpen,
                          openLabel: widget.openLabel,
                          closedLabel: widget.closedLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _WorkshopInfoRow(
                      icon: Icons.location_on_outlined,
                      text: widget.workshop.locationLabel,
                    ),
                    const SizedBox(height: 8),
                    _WorkshopInfoRow(
                      icon: Icons.phone_outlined,
                      text: widget.workshop.phone,
                    ),
                    const SizedBox(height: 8),
                    _WorkshopInfoRow(
                      icon: Icons.alternate_email_rounded,
                      text: widget.workshop.email,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _WorkshopMetricPill(
                                icon: Icons.star_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                text: widget.workshop.rating.toStringAsFixed(1),
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
