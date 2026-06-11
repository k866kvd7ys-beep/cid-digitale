import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/services/workshop_catalog_service.dart';
import 'package:flutter/material.dart';

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
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF2563EB);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textGray = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  final WorkshopCatalogService _catalogService = WorkshopCatalogService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<WorkshopModel>> _workshopsFuture;
  String _query = '';
  WorkshopModel? _selectedWorkshop;

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
        it: 'Cerca officina...',
        de: 'Werkstatt suchen...',
        fr: 'Rechercher un atelier...',
        en: 'Search workshop...',
      );

  String get _useLocationLabel => _copy(
        it: 'Usa la mia posizione',
        de: 'Meinen Standort verwenden',
        fr: 'Utiliser ma position',
        en: 'Use my location',
      );

  String get _useLocationSoonSnack => _copy(
        it: 'La geolocalizzazione verra collegata al GPS in un prossimo aggiornamento.',
        de: 'Die Geolokalisierung wird in einem nächsten Update mit GPS verbunden.',
        fr: 'La géolocalisation sera reliée au GPS dans une prochaine mise à jour.',
        en: 'Geolocation will be connected to GPS in a future update.',
      );

  String get _ratingLabel => _copy(
        it: 'Valutazione',
        de: 'Bewertung',
        fr: 'Évaluation',
        en: 'Rating',
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
    _selectedWorkshop = widget.preselectedWorkshop;
    _workshopsFuture = _catalogService.fetchWorkshops();
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

  void _handleUseLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_useLocationSoonSnack)),
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

  List<WorkshopModel> _filterWorkshops(List<WorkshopModel> workshops) {
    return workshops
        .where((workshop) => workshop.matchesQuery(_query))
        .toList();
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _continueHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _textGray,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed:
                    _selectedWorkshop == null ? null : _continueToCalendar,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: const Color(0xFFBFDBFE),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF6FF), _background],
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

            final workshops = _filterWorkshops(snapshot.data ?? const []);

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
              children: [
                _HeaderCard(
                  title: _screenTitle,
                  subtitle: _screenSubtitle,
                  searchBar: SearchBar(
                    controller: _searchController,
                    hintText: _searchPlaceholder,
                    leading: const Icon(Icons.search_rounded, color: _textGray),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: const WidgetStatePropertyAll(_surface),
                    surfaceTintColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: _border),
                      ),
                    ),
                    hintStyle: const WidgetStatePropertyAll(
                      TextStyle(color: _textGray),
                    ),
                  ),
                  locationButton: OutlinedButton.icon(
                    onPressed: _handleUseLocation,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      _useLocationLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _WorkshopOptionCard(
                        workshop: workshop,
                        selected: workshop.id == _selectedWorkshop?.id,
                        ratingLabel: _ratingLabel,
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
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.searchBar,
    required this.locationButton,
  });

  final String title;
  final String subtitle;
  final Widget searchBar;
  final Widget locationButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 28,
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
                  color: const Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          searchBar,
          const SizedBox(height: 12),
          locationButton,
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
    required this.ratingLabel,
    required this.openLabel,
    required this.closedLabel,
    required this.selectLabel,
    required this.selectedLabel,
    required this.onSelect,
  });

  final WorkshopModel workshop;
  final bool selected;
  final String ratingLabel;
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
    final borderColor =
        widget.selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB);
    final fillColor = widget.selected ? const Color(0xFFF5F9FF) : Colors.white;
    final shadowColor = _hovered || widget.selected
        ? const Color(0x180F172A)
        : const Color(0x100F172A);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          _hovered && !widget.selected ? -2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: borderColor, width: widget.selected ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: _hovered || widget.selected ? 26 : 18,
              offset: Offset(0, _hovered || widget.selected ? 14 : 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onSelect,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.workshop.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF111827),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.workshop.rating.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF92400E),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _WorkshopInfoRow(
                    icon: Icons.location_on_outlined,
                    text: widget.workshop.locationLabel,
                  ),
                  const SizedBox(height: 10),
                  _WorkshopInfoRow(
                    icon: Icons.phone_outlined,
                    text: widget.workshop.phone,
                  ),
                  const SizedBox(height: 10),
                  _WorkshopInfoRow(
                    icon: Icons.mail_outline_rounded,
                    text: widget.workshop.email,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: widget.workshop.isOpen
                              ? const Color(0xFFECFDF3)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: widget.workshop.isOpen
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.workshop.isOpen
                                  ? widget.openLabel
                                  : widget.closedLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: widget.workshop.isOpen
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF475569),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: widget.selected
                            ? Container(
                                key: const ValueKey('selected'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(16),
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
                                            color: const Color(0xFF2563EB),
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : FilledButton(
                                key: const ValueKey('select'),
                                onPressed: widget.onSelect,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(116, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
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
        Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF374151),
                  height: 1.45,
                ),
          ),
        ),
      ],
    );
  }
}
