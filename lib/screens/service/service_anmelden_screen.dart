import 'package:cid_digitale/screens/service/workshop_selector_screen.dart';
import 'package:cid_digitale/screens/service/workshop_service_details_screen.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/material.dart';

String _serviceFlowCopy(
  String locale, {
  required String de,
  required String it,
  required String en,
  required String fr,
}) {
  switch (normalizeWorkshopServiceLocale(locale)) {
    case 'it':
      return it;
    case 'en':
      return en;
    case 'fr':
      return fr;
    case 'de':
    default:
      return de;
  }
}

class ServiceAnmeldenScreen extends StatelessWidget {
  const ServiceAnmeldenScreen({super.key});

  String _locale(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  void _openBooking(
    BuildContext context,
    String title, {
    required String serviceType,
    String? serviceSelectionKey,
    String? serviceDetail,
    String? cleaningPackage,
    List<String> additionalServices = const [],
    List<AppointmentRequestImageInput> wheelRepairImages = const [],
  }) {
    openWorkshopSelectionStep(
      context,
      title: title,
      serviceType: serviceType,
      serviceSelectionKey: serviceSelectionKey,
      serviceDetail: serviceDetail,
      cleaningPackage: cleaningPackage,
      additionalServices: additionalServices,
      wheelRepairImages: wheelRepairImages,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = _locale(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceSelectionTitle(locale),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          itemCount: visibleWorkshopServiceKeys.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  workshopServiceSelectionSubtitle(locale),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
              );
            }

            final serviceKey = visibleWorkshopServiceKeys[index - 1];
            return _ServiceOptionCard(
              icon: workshopServiceIcon(serviceKey),
              title: workshopServiceLabel(locale, serviceKey),
              description: workshopServiceDescription(locale, serviceKey),
              onTap: () {
                if (serviceKey == workshopServiceInspection) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ServiceInspectionScreen(
                        locale: locale,
                        onContinueToBooking: (serviceDetail, cleaningPackage,
                                additionalServices) =>
                            _openBooking(
                          context,
                          workshopServiceLabel(
                            locale,
                            workshopServiceInspection,
                          ),
                          serviceType: workshopServiceInspection,
                          serviceDetail: serviceDetail,
                          cleaningPackage: cleaningPackage,
                          additionalServices: additionalServices,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceRepair) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ServiceRepairInfoScreen(
                        locale: locale,
                        onBookNow: (cleaningPackage) => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                          cleaningPackage: cleaningPackage,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceVehicleCheck) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _VehicleCheckInfoScreen(
                        locale: locale,
                        onBookNow: () => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceClimate) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ClimateServiceScreen(
                        locale: locale,
                        onBookNow: (serviceDetail) => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                          serviceDetail: serviceDetail,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceAlignment) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _VehicleAlignmentInfoScreen(
                        locale: locale,
                        onBookNow: () => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceMfk) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _MfkPreparationInfoScreen(
                        locale: locale,
                        onBookNow: () => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceWheelRepair) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WheelRepairServiceScreen(
                        onContinue: (draft) => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                          serviceDetail: draft.encodedServiceDetail,
                          wheelRepairImages: draft.photos,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                if (serviceKey == workshopServiceOther) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OtherWorkshopServiceScreen(
                        onContinue: (description) => _openBooking(
                          context,
                          workshopServiceLabel(locale, serviceKey),
                          serviceType: 'service_anmelden',
                          serviceSelectionKey: serviceKey,
                          serviceDetail: description,
                        ),
                      ),
                    ),
                  );
                  return;
                }

                _openBooking(
                  context,
                  workshopServiceLabel(locale, serviceKey),
                  serviceType: 'service_anmelden',
                  serviceSelectionKey: serviceKey,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ServiceInspectionScreen extends StatefulWidget {
  const _ServiceInspectionScreen({
    required this.locale,
    required this.onContinueToBooking,
  });

  final String locale;
  final void Function(
    String serviceDetail,
    String cleaningPackage,
    List<String> additionalServices,
  ) onContinueToBooking;

  @override
  State<_ServiceInspectionScreen> createState() =>
      _ServiceInspectionScreenState();
}

class _ServiceInspectionScreenState extends State<_ServiceInspectionScreen> {
  String _selectedDetail = workshopInspectionDetail30000;
  String _selectedCleaningPackage = workshopCleaningPackageBronze;
  List<String> _selectedAdditionalServices = const [];

  List<_InspectionOptionData> _options() {
    return [
      _InspectionOptionData(
        value: workshopInspectionDetail30000,
        primaryLines: workshopInspectionPrimaryLines(
          widget.locale,
          workshopInspectionDetail30000,
        ),
      ),
      _InspectionOptionData(
        value: workshopInspectionDetail60000,
        primaryLines: workshopInspectionPrimaryLines(
          widget.locale,
          workshopInspectionDetail60000,
        ),
      ),
      _InspectionOptionData(
        value: workshopInspectionDetailOver60000,
        primaryLines: workshopInspectionPrimaryLines(
          widget.locale,
          workshopInspectionDetailOver60000,
        ),
      ),
      _InspectionOptionData(
        value: workshopInspectionDetailOilChange,
        primaryLines: workshopInspectionPrimaryLines(
          widget.locale,
          workshopInspectionDetailOilChange,
        ),
        secondaryLine: workshopInspectionSecondaryLine(
          widget.locale,
          workshopInspectionDetailOilChange,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceLabel(widget.locale, workshopServiceInspection),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workshopServiceLabel(
                        widget.locale, workshopServiceInspection),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    workshopInspectionSubtitle(widget.locale),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...options.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _InspectionOptionCard(
                        title: workshopInspectionDetailLabel(
                          widget.locale,
                          option.value,
                        ),
                        primaryLines: option.primaryLines,
                        secondaryLine: option.secondaryLine,
                        selected: _selectedDetail == option.value,
                        onTap: () {
                          setState(() {
                            _selectedDetail = option.value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    workshopInspectionAdditionalNote(widget.locale),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    workshopInspectionCleaningTitle(widget.locale),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    workshopInspectionCleaningSubtitle(widget.locale),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 900;
                      final itemWidth = isMobile
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 32) / 3;

                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _CleaningProgramCard(
                            width: itemWidth,
                            icon: Icons.local_car_wash_outlined,
                            title: 'Bronze',
                            subtitle: workshopCleaningPackageSubtitle(
                              widget.locale,
                              workshopCleaningPackageBronze,
                            ),
                            bullets: workshopCleaningPackageBullets(
                              widget.locale,
                              workshopCleaningPackageBronze,
                            ),
                            badgeText: workshopCleaningPackageBadge(
                              widget.locale,
                              workshopCleaningPackageBronze,
                            ),
                            badgeColor: const Color(0xFF16A34A),
                            selected: _selectedCleaningPackage ==
                                workshopCleaningPackageBronze,
                            onTap: () {
                              setState(() {
                                _selectedCleaningPackage =
                                    workshopCleaningPackageBronze;
                              });
                            },
                          ),
                          _CleaningProgramCard(
                            width: itemWidth,
                            icon: Icons.auto_awesome_outlined,
                            title: 'Silber',
                            subtitle: workshopCleaningPackageSubtitle(
                              widget.locale,
                              workshopCleaningPackageSilber,
                            ),
                            bullets: workshopCleaningPackageBullets(
                              widget.locale,
                              workshopCleaningPackageSilber,
                            ),
                            badgeText: workshopCleaningPackageBadge(
                              widget.locale,
                              workshopCleaningPackageSilber,
                            ),
                            badgeColor: const Color(0xFF2563EB),
                            selected: _selectedCleaningPackage ==
                                workshopCleaningPackageSilber,
                            onTap: () {
                              setState(() {
                                _selectedCleaningPackage =
                                    workshopCleaningPackageSilber;
                              });
                            },
                          ),
                          _CleaningProgramCard(
                            width: itemWidth,
                            icon: Icons.workspace_premium_outlined,
                            title: 'Gold',
                            subtitle: workshopCleaningPackageSubtitle(
                              widget.locale,
                              workshopCleaningPackageGold,
                            ),
                            bullets: workshopCleaningPackageBullets(
                              widget.locale,
                              workshopCleaningPackageGold,
                            ),
                            badgeText: workshopCleaningPackageBadge(
                              widget.locale,
                              workshopCleaningPackageGold,
                            ),
                            badgeColor: const Color(0xFFF59E0B),
                            selected: _selectedCleaningPackage ==
                                workshopCleaningPackageGold,
                            onTap: () {
                              setState(() {
                                _selectedCleaningPackage =
                                    workshopCleaningPackageGold;
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                          child: Text(
                            workshopInspectionBackLabel(widget.locale),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _openAdditionalServicesPicker,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: const BorderSide(
                              color: Color(0xFF2563EB),
                            ),
                            foregroundColor: const Color(0xFF2563EB),
                          ),
                          child: Text(
                            workshopInspectionAddServiceLabel(widget.locale),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedAdditionalServices.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      workshopAdditionalServicesFieldLabel(widget.locale),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._selectedAdditionalServices.map(
                      (service) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '- ${workshopAdditionalServiceLabel(widget.locale, service)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4B5563),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => widget.onContinueToBooking(
                        _selectedDetail,
                        _selectedCleaningPackage,
                        _selectedAdditionalServices,
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        workshopInspectionContinueLabel(widget.locale),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAdditionalServicesPicker() async {
    final tempSelection = List<String>.from(_selectedAdditionalServices);

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshopAdditionalServicesTitle(widget.locale),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: workshopAdditionalServiceOptions()
                              .map(
                                (service) => CheckboxListTile(
                                  value: tempSelection.contains(service),
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text(
                                    workshopAdditionalServiceLabel(
                                      widget.locale,
                                      service,
                                    ),
                                  ),
                                  onChanged: (selected) {
                                    setModalState(() {
                                      if (selected == true) {
                                        if (!tempSelection.contains(service)) {
                                          tempSelection.add(service);
                                        }
                                      } else {
                                        tempSelection.remove(service);
                                      }
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(workshopCancelLabel(widget.locale)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context)
                                .pop(List<String>.from(tempSelection)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: Text(
                              workshopSelectionApplyLabel(widget.locale),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _selectedAdditionalServices = result;
    });
  }
}

class _VehicleCheckInfoScreen extends StatelessWidget {
  const _VehicleCheckInfoScreen({
    required this.locale,
    required this.onBookNow,
  });

  final String locale;
  final VoidCallback onBookNow;

  List<_ServiceInfoBullet> _bullets() {
    return [
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Sicherheit im Alltag',
          it: 'Sicurezza nell’uso quotidiano',
          en: 'Everyday safety',
          fr: 'Sécurité au quotidien',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: 'Bremsen, Beleuchtung, Warnanzeigen und freie Sicht',
          it: 'Freni, illuminazione, spie e visibilità',
          en: 'Brakes, lighting, warning indicators and visibility',
          fr: 'Freins, éclairage, témoins et visibilité',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Reifen und Fahrverhalten',
          it: 'Pneumatici e comportamento di guida',
          en: 'Tires and handling',
          fr: 'Pneumatiques et comportement routier',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: 'Profiltiefe, Luftdruck und auffälliges Verschleissbild',
          it: 'Battistrada, pressione e usura anomala',
          en: 'Tread depth, tire pressure and unusual wear',
          fr: 'Profondeur du profil, pression et usure anormale',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Energie und Betriebsstoffe',
          it: 'Energia e liquidi di esercizio',
          en: 'Energy and operating fluids',
          fr: 'Énergie et liquides de fonctionnement',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: '12-V-Batterie und fahrzeugspezifische Füllstände',
          it: 'Batteria 12 V e livelli specifici del veicolo',
          en: '12 V battery and vehicle-specific fluid levels',
          fr: 'Batterie 12 V et niveaux propres au véhicule',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Karosserie und Verglasung',
          it: 'Carrozzeria e vetri',
          en: 'Bodywork and glazing',
          fr: 'Carrosserie et vitrages',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: 'Scheiben, Wischer und sichtbare äussere Schäden',
          it: 'Vetri, tergicristalli e danni esterni visibili',
          en: 'Windows, wipers and visible exterior damage',
          fr: 'Vitres, essuie-glaces et dommages extérieurs visibles',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Fahrwerk und Unterseite',
          it: 'Assetto e sottoscocca',
          en: 'Suspension and underside',
          fr: 'Train roulant et soubassement',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: 'Zugängliche Bauteile, Befestigungen und sichtbare Undichtigkeiten',
          it: 'Componenti accessibili, fissaggi e perdite visibili',
          en: 'Accessible components, mountings and visible leaks',
          fr: 'Composants accessibles, fixations et fuites visibles',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceLabel(locale, workshopServiceVehicleCheck),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serviceFlowCopy(
                        locale,
                        de: 'Fahrzeug-Kurzcheck',
                        it: 'Controllo rapido del veicolo',
                        en: 'Vehicle quick check',
                        fr: 'Contrôle rapide du véhicule',
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _serviceFlowCopy(
                        locale,
                        de: 'Kompakter Vorsorgecheck für sicherheits- und alltagsrelevante Bereiche.',
                        it: 'Controllo preventivo essenziale delle parti rilevanti per sicurezza e uso quotidiano.',
                        en: 'A concise preventive check of areas relevant to safety and everyday use.',
                        fr: 'Contrôle préventif concis des éléments importants pour la sécurité et l’usage quotidien.',
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._bullets().map(
                      (bullet) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _ServiceInfoBulletTile(bullet: bullet),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _serviceFlowCopy(
                        locale,
                        de: 'Der genaue Umfang richtet sich nach Fahrzeug und Werkstatt.',
                        it: 'L’ambito esatto dipende dal veicolo e dall’officina.',
                        en: 'The exact scope depends on the vehicle and the workshop.',
                        fr: 'L’étendue exacte dépend du véhicule et du garage.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: onBookNow,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _serviceFlowCopy(
                            locale,
                            de: 'Termin buchen',
                            it: 'Prenota appuntamento',
                            en: 'Book appointment',
                            fr: 'Réserver un rendez-vous',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

class _ClimateServiceScreen extends StatefulWidget {
  const _ClimateServiceScreen({
    required this.locale,
    required this.onBookNow,
  });

  final String locale;
  final ValueChanged<String> onBookNow;

  @override
  State<_ClimateServiceScreen> createState() => _ClimateServiceScreenState();
}

class _ClimateServiceScreenState extends State<_ClimateServiceScreen> {
  String _selectedDetail = workshopClimateDetailStandard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceLabel(widget.locale, workshopServiceClimate),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                children: [
                  _ClimateDetailCard(
                    title: workshopClimateDetailLabel(
                      widget.locale,
                      workshopClimateDetailStandard,
                    ),
                    priceLabel: workshopPriceAccordingToWorkshop(widget.locale),
                    bullets: [
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Kühlleistung und Bedienelemente prüfen',
                        it: 'Controllo della resa e dei comandi',
                        en: 'Check cooling performance and controls',
                        fr: 'Contrôle des performances et des commandes',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Zugängliche Komponenten hygienisch behandeln',
                        it: 'Trattamento igienico dei componenti accessibili',
                        en: 'Hygienic treatment of accessible components',
                        fr: 'Traitement hygiénique des composants accessibles',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Pollenfilter beurteilen; Ersatz nur nach Rücksprache',
                        it: 'Valutazione del filtro abitacolo; sostituzione solo previo accordo',
                        en: 'Assess the cabin filter; replacement only after consultation',
                        fr: 'Évaluer le filtre d’habitacle ; remplacement uniquement après accord',
                      ),
                    ],
                    selected: _selectedDetail == workshopClimateDetailStandard,
                    onTap: () {
                      setState(() {
                        _selectedDetail = workshopClimateDetailStandard;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _ClimateDetailCard(
                    title: workshopClimateDetailLabel(
                      widget.locale,
                      workshopClimateDetailPlus,
                    ),
                    priceLabel: workshopPriceAccordingToWorkshop(widget.locale),
                    description: _serviceFlowCopy(
                      widget.locale,
                      de: 'Erweiterte Prüfung nach Anlagenzustand und Werkstattausstattung:',
                      it: 'Controllo esteso secondo lo stato dell’impianto e le dotazioni dell’officina:',
                      en: 'Extended check based on system condition and workshop equipment:',
                      fr: 'Contrôle étendu selon l’état du système et l’équipement du garage :',
                    ),
                    bullets: [
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Druck- und Leistungswerte des Kältemittelkreislaufs prüfen',
                        it: 'Controllo di pressione e prestazioni del circuito refrigerante',
                        en: 'Check refrigerant circuit pressure and performance values',
                        fr: 'Contrôle de la pression et des performances du circuit frigorifique',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Kältemittelservice nach Befund und Fahrzeugvorgabe',
                        it: 'Servizio refrigerante secondo esito e specifiche del veicolo',
                        en: 'Refrigerant service according to findings and vehicle specifications',
                        fr: 'Service du fluide frigorigène selon le diagnostic et le véhicule',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Material und Zusatzarbeiten nur nach Rücksprache',
                        it: 'Materiali e lavori aggiuntivi solo previo accordo',
                        en: 'Materials and additional work only after consultation',
                        fr: 'Matériel et travaux supplémentaires uniquement après accord',
                      ),
                    ],
                    selected: _selectedDetail == workshopClimateDetailPlus,
                    onTap: () {
                      setState(() {
                        _selectedDetail = workshopClimateDetailPlus;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => widget.onBookNow(_selectedDetail),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _serviceFlowCopy(
                          widget.locale,
                          de: 'Termin buchen',
                          it: 'Prenota appuntamento',
                          en: 'Book appointment',
                          fr: 'Réserver un rendez-vous',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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

class _VehicleAlignmentInfoScreen extends StatelessWidget {
  const _VehicleAlignmentInfoScreen({
    required this.locale,
    required this.onBookNow,
  });

  final String locale;
  final VoidCallback onBookNow;

  List<String> _benefits() {
    return [
      _serviceFlowCopy(
        locale,
        de: 'Vermeidung von frühzeitigem Verschleiss der Reifen',
        it: 'Prevenzione dell’usura prematura degli pneumatici',
        en: 'Prevention of premature tyre wear',
        fr: 'Prévention de l’usure prématurée des pneus',
      ),
      _serviceFlowCopy(
        locale,
        de: 'Korrektes Brems- und Lenkverhalten',
        it: 'Comportamento corretto in frenata e sterzata',
        en: 'Correct braking and steering behaviour',
        fr: 'Comportement correct au freinage et à la direction',
      ),
      _serviceFlowCopy(
        locale,
        de: 'Effizienteres Fahren durch korrekte Radstellung',
        it: 'Guida più efficiente grazie al corretto assetto delle ruote',
        en: 'More efficient driving through correct wheel alignment',
        fr: 'Conduite plus efficace grâce au bon alignement des roues',
      ),
      _serviceFlowCopy(
        locale,
        de: 'Sicherheit einer korrekten Einstellung',
        it: 'Sicurezza di una regolazione corretta',
        en: 'Safety through correct adjustment',
        fr: 'Sécurité d’un réglage correct',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceLabel(locale, workshopServiceAlignment),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEAEAEA)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshopServiceLabel(locale, workshopServiceAlignment),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _serviceFlowCopy(
                        locale,
                        de: 'Prüfung von Radstellung, Achsen und Lenkgeometrie',
                        it: 'Controllo di assetto ruote, assi e geometria dello sterzo',
                        en: 'Check of wheel position, axles and steering geometry',
                        fr: 'Contrôle de la position des roues, des essieux et de la direction',
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _serviceFlowCopy(
                        locale,
                        de: 'Ihre Vorteile:',
                        it: 'I vantaggi:',
                        en: 'Your benefits:',
                        fr: 'Vos avantages :',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._benefits().map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Icon(
                                Icons.circle,
                                size: 8,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF4B5563),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _serviceFlowCopy(
                        locale,
                        de: 'Bei Abweichungen muss die Einstellung der Lenkgeometrie gegen gesonderte Verrechnung durchgeführt werden.',
                        it: 'In caso di deviazioni, la regolazione della geometria dello sterzo verrà eseguita con addebito separato.',
                        en: 'In case of deviations, steering geometry adjustment will be carried out and charged separately.',
                        fr: 'En cas d’écarts, le réglage de la géométrie de direction sera effectué avec facturation séparée.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: onBookNow,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _serviceFlowCopy(
                            locale,
                            de: 'Termin buchen',
                            it: 'Prenota appuntamento',
                            en: 'Book appointment',
                            fr: 'Réserver un rendez-vous',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

class _MfkPreparationInfoScreen extends StatelessWidget {
  const _MfkPreparationInfoScreen({
    required this.locale,
    required this.onBookNow,
  });

  final String locale;
  final VoidCallback onBookNow;

  List<_MfkInfoItem> _items() {
    return [
      _MfkInfoItem(
        icon: Icons.car_crash_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Bremsen und Fahrverhalten',
          it: 'Freni e comportamento di guida',
          en: 'Brakes and handling',
          fr: 'Freins et comportement routier',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Bremswirkung nach Werkstattverfahren',
            it: 'Efficacia frenante secondo la procedura dell’officina',
            en: 'Braking performance using the workshop procedure',
            fr: 'Efficacité du freinage selon la procédure du garage',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Sichtbarer Zustand und auffälliges Fahrverhalten',
            it: 'Stato visibile e anomalie nel comportamento di guida',
            en: 'Visible condition and unusual handling',
            fr: 'État visible et comportement routier inhabituel',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.lightbulb_outline,
        title: _serviceFlowCopy(
          locale,
          de: 'Beleuchtung und Signale',
          it: 'Illuminazione e segnalazione',
          en: 'Lighting and signals',
          fr: 'Éclairage et signalisation',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Scheinwerfer, Leuchten und Blinker',
            it: 'Fari, luci e indicatori di direzione',
            en: 'Headlights, lamps and indicators',
            fr: 'Phares, feux et clignotants',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Einstellung und erkennbare Fehlanzeigen',
            it: 'Regolazione e segnalazioni di errore visibili',
            en: 'Adjustment and visible fault indications',
            fr: 'Réglage et indications de défaut visibles',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.description_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Dokumente und Identifikation',
          it: 'Documenti e identificazione',
          en: 'Documents and identification',
          fr: 'Documents et identification',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Kontrollschilder und Fahrzeugausweis',
            it: 'Targhe e licenza di circolazione',
            en: 'License plates and vehicle registration document',
            fr: 'Plaques et permis de circulation',
          ),
          _serviceFlowCopy(
            locale,
            de: 'FIN und erforderliche Zusatzdokumente',
            it: 'VIN e documenti supplementari necessari',
            en: 'VIN and required supplementary documents',
            fr: 'VIN et documents complémentaires requis',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.tire_repair_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Räder, Lenkung und Aufhängung',
          it: 'Ruote, sterzo e sospensioni',
          en: 'Wheels, steering and suspension',
          fr: 'Roues, direction et suspension',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Bereifung und Radbefestigung',
            it: 'Pneumatici e fissaggio delle ruote',
            en: 'Tires and wheel fastening',
            fr: 'Pneumatiques et fixation des roues',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Erkennbare Spiele und zugängliche Bauteile',
            it: 'Giochi rilevabili e componenti accessibili',
            en: 'Detectable play and accessible components',
            fr: 'Jeux détectables et composants accessibles',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.directions_car_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Karosserie und Sicht',
          it: 'Carrozzeria e visibilità',
          en: 'Bodywork and visibility',
          fr: 'Carrosserie et visibilité',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Scheiben, Spiegel und Wischer',
            it: 'Vetri, specchi e tergicristalli',
            en: 'Windows, mirrors and wipers',
            fr: 'Vitres, rétroviseurs et essuie-glaces',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Sichtbare Schäden oder Korrosion',
            it: 'Danni visibili o corrosione',
            en: 'Visible damage or corrosion',
            fr: 'Dommages visibles ou corrosion',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Türen, Hauben und Befestigungen',
            it: 'Porte, cofani e fissaggi',
            en: 'Doors, lids and fastenings',
            fr: 'Portes, capots et fixations',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.precision_manufacturing_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Antrieb und Unterseite',
          it: 'Propulsione e sottoscocca',
          en: 'Drivetrain and underside',
          fr: 'Chaîne cinématique et soubassement',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Sichtprüfung auf Undichtigkeiten',
            it: 'Controllo visivo di eventuali perdite',
            en: 'Visual check for leaks',
            fr: 'Contrôle visuel des fuites',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Befestigungen und zugängliche Komponenten',
            it: 'Fissaggi e componenti accessibili',
            en: 'Fastenings and accessible components',
            fr: 'Fixations et composants accessibles',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Prüfpunkte passend zur Antriebsart',
            it: 'Controlli adeguati al tipo di propulsione',
            en: 'Checks appropriate to the drivetrain type',
            fr: 'Contrôles adaptés au type de motorisation',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.health_and_safety_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Sicherheitsausstattung',
          it: 'Dotazioni di sicurezza',
          en: 'Safety equipment',
          fr: 'Équipements de sécurité',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Sicherheitsgurte und Rückhaltesysteme',
            it: 'Cinture e sistemi di ritenuta',
            en: 'Seat belts and restraint systems',
            fr: 'Ceintures et systèmes de retenue',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Warn- und Sicherheitseinrichtungen',
            it: 'Dispositivi di avviso e sicurezza',
            en: 'Warning and safety devices',
            fr: 'Dispositifs d’alerte et de sécurité',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.cleaning_services_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Prüfbereitschaft',
          it: 'Preparazione al controllo',
          en: 'Inspection readiness',
          fr: 'Préparation au contrôle',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Prüfrelevante Bereiche bei Bedarf reinigen',
            it: 'Pulizia delle zone rilevanti, se necessaria',
            en: 'Clean inspection-relevant areas if required',
            fr: 'Nettoyer les zones utiles au contrôle si nécessaire',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Notwendige Arbeiten nur nach Rücksprache',
            it: 'Lavori necessari solo previo accordo',
            en: 'Required work only after consultation',
            fr: 'Travaux nécessaires uniquement après accord',
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = width < 600;
    final isTablet = width >= 600 && width < 1100;
    final crossAxisCount = isPhone
        ? 1
        : width >= 1100
            ? 3
            : 2;
    final crossSpacing = isPhone ? 10.0 : 16.0;
    final mainSpacing = isPhone ? 10.0 : 12.0;
    final contentWidth = width >= 1100 ? 1120.0 : 980.0;
    final items = _items();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceLabel(locale, workshopServiceMfk),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, isPhone ? 6 : 10, 16, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPhone)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _serviceFlowCopy(
                          locale,
                          de: 'Gezielte Prüfung MFK-relevanter Bereiche; Zusatzarbeiten nur nach Rücksprache.',
                          it: 'Controllo mirato delle parti rilevanti per la MFK; lavori aggiuntivi solo previo accordo.',
                          en: 'Targeted review of MFK-relevant areas; additional work only after consultation.',
                          fr: 'Contrôle ciblé des éléments utiles à la MFK ; travaux supplémentaires uniquement après accord.',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: const Color(0xFF6B7280),
                          height: 1.25,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workshopServiceLabel(locale, workshopServiceMfk),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: isTablet ? 27 : 28,
                              height: 1.05,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _serviceFlowCopy(
                              locale,
                              de: 'Gezielte Prüfung MFK-relevanter Bereiche; Zusatzarbeiten nur nach Rücksprache.',
                              it: 'Controllo mirato delle parti rilevanti per la MFK; lavori aggiuntivi solo previo accordo.',
                              en: 'Targeted review of MFK-relevant areas; additional work only after consultation.',
                              fr: 'Contrôle ciblé des éléments utiles à la MFK ; travaux supplémentaires uniquement après accord.',
                            ),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 17,
                              color: const Color(0xFF6B7280),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: isPhone ? 10 : 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: crossSpacing,
                      mainAxisSpacing: mainSpacing,
                      mainAxisExtent: isPhone
                          ? 220
                          : isTablet
                              ? 320
                              : 360,
                    ),
                    itemBuilder: (context, index) {
                      return _MfkInfoCard(
                        item: items[index],
                        isCompactPhone: isPhone,
                      );
                    },
                  ),
                  SizedBox(height: isPhone ? 12 : 16),
                  SizedBox(
                    width: double.infinity,
                    height: isPhone ? 52 : 62,
                    child: ElevatedButton(
                      onPressed: onBookNow,
                      style: ElevatedButton.styleFrom(
                        elevation: isPhone ? 1 : 4,
                        shadowColor: Colors.black.withOpacity(
                          isPhone ? 0.08 : 0.14,
                        ),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(isPhone ? 16 : 20),
                        ),
                      ),
                      child: Text(
                        _serviceFlowCopy(
                          locale,
                          de: 'Termin buchen',
                          it: 'Prenota appuntamento',
                          en: 'Book appointment',
                          fr: 'Réserver un rendez-vous',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: isPhone ? 15 : null,
                        ),
                      ),
                    ),
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

class _ServiceInfoBullet {
  const _ServiceInfoBullet({
    required this.title,
    required this.detail,
  });

  final String title;
  final String detail;
}

class _ServiceInfoBulletTile extends StatelessWidget {
  const _ServiceInfoBulletTile({required this.bullet});

  final _ServiceInfoBullet bullet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 8,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bullet.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bullet.detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClimateDetailCard extends StatelessWidget {
  const _ClimateDetailCard({
    required this.title,
    required this.priceLabel,
    required this.bullets,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String title;
  final String priceLabel;
  final String? description;
  final List<String> bullets;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2563EB) : const Color(0xFFEAEAEA),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2563EB),
                    ),
                ],
              ),
              if (description != null) ...[
                const SizedBox(height: 10),
                Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4B5563),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  priceLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...bullets.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4B5563),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MfkInfoItem {
  const _MfkInfoItem({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
}

class _MfkInfoCard extends StatefulWidget {
  const _MfkInfoCard({
    required this.item,
    required this.isCompactPhone,
  });

  final _MfkInfoItem item;
  final bool isCompactPhone;

  @override
  State<_MfkInfoCard> createState() => _MfkInfoCardState();
}

class _MfkInfoCardState extends State<_MfkInfoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final isCompactPhone = widget.isCompactPhone;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(isCompactPhone ? 11 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isCompactPhone ? 16 : 22),
          border: Border.all(
            color: _hovered ? const Color(0xFFBFDBFE) : const Color(0xFFEAEAEA),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_hovered ? 0.08 : 0.04),
              blurRadius: _hovered ? 24 : 18,
              offset: Offset(0, _hovered ? 10 : 6),
            ),
            if (_hovered)
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCompactPhone)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      color: const Color(0xFF1D4ED8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        height: 1.08,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: const Color(0xFF1D4ED8),
                  size: 31,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 19.5,
                  height: 1.08,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
            SizedBox(height: isCompactPhone ? 6 : 8),
            ...item.lines.map(
              (line) => Padding(
                padding: EdgeInsets.only(bottom: isCompactPhone ? 3 : 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: isCompactPhone ? 1.5 : 2),
                      child: Icon(
                        Icons.check_rounded,
                        size: isCompactPhone ? 13 : 16,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(width: isCompactPhone ? 6 : 8),
                    Expanded(
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          fontSize: isCompactPhone ? 11.6 : 15.2,
                          height: isCompactPhone ? 1.15 : 1.28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRepairInfoScreen extends StatefulWidget {
  const _ServiceRepairInfoScreen({
    required this.locale,
    required this.onBookNow,
  });

  final String locale;
  final ValueChanged<String> onBookNow;

  @override
  State<_ServiceRepairInfoScreen> createState() =>
      _ServiceRepairInfoScreenState();
}

class _ServiceRepairInfoScreenState extends State<_ServiceRepairInfoScreen> {
  String _selectedCleaningPackage = workshopCleaningPackageBronze;

  List<_ServiceRepairInfoItem> _items() => [
        _ServiceRepairInfoItem(
          icon: Icons.settings_outlined,
          title: _serviceFlowCopy(
            widget.locale,
            de: 'Wartung und\nAntrieb',
            it: 'Manutenzione e\npropulsione',
            en: 'Maintenance and\ndrivetrain',
            fr: 'Entretien et\nmotorisation',
          ),
          subtitle: _serviceFlowCopy(
            widget.locale,
            de: 'Wartung nach Vorgabe',
            it: 'Manutenzione programmata',
            en: 'Scheduled maintenance',
            fr: 'Entretien programmé',
          ),
        ),
        _ServiceRepairInfoItem(
          icon: Icons.fact_check_outlined,
          title: _serviceFlowCopy(
            widget.locale,
            de: 'Bremsen und\nSicherheit',
            it: 'Freni e\nsicurezza',
            en: 'Brakes and\nsafety',
            fr: 'Freins et\nsécurité',
          ),
          subtitle: _serviceFlowCopy(
            widget.locale,
            de: 'Zustand und Funktion',
            it: 'Stato e funzionamento',
            en: 'Condition and function',
            fr: 'État et fonctionnement',
          ),
        ),
        _ServiceRepairInfoItem(
          icon: Icons.tire_repair_outlined,
          title: _serviceFlowCopy(
            widget.locale,
            de: 'Reifen und\nFahrwerk',
            it: 'Pneumatici e\nassetto',
            en: 'Tires and\nsuspension',
            fr: 'Pneumatiques et\ntrain roulant',
          ),
          subtitle: _serviceFlowCopy(
            widget.locale,
            de: 'Reifen, Fahrwerk und Lenkung',
            it: 'Pneumatici, assetto e sterzo',
            en: 'Tires, suspension and steering',
            fr: 'Pneus, châssis et direction',
          ),
        ),
        _ServiceRepairInfoItem(
          icon: Icons.highlight_outlined,
          title: _serviceFlowCopy(
            widget.locale,
            de: 'Elektrik und\nBeleuchtung',
            it: 'Elettrico e\nilluminazione',
            en: 'Electrical and\nlighting',
            fr: 'Électricité et\néclairage',
          ),
          subtitle: _serviceFlowCopy(
            widget.locale,
            de: 'Licht und Elektrik',
            it: 'Luci e impianto elettrico',
            en: 'Lighting and electrical',
            fr: 'Éclairage et électricité',
          ),
        ),
        _ServiceRepairInfoItem(
          icon: Icons.opacity_outlined,
          title: _serviceFlowCopy(
            widget.locale,
            de: 'Flüssigkeiten und\nIntervalle',
            it: 'Liquidi e\nintervalli',
            en: 'Fluids and\nservice intervals',
            fr: 'Fluides et\nintervalles',
          ),
          subtitle: _serviceFlowCopy(
            widget.locale,
            de: 'Füllstände und Intervalle',
            it: 'Livelli e intervalli',
            en: 'Fluid levels and intervals',
            fr: 'Niveaux et intervalles',
          ),
        ),
        _ServiceRepairInfoItem(
          icon: Icons.car_repair_outlined,
          title: _serviceFlowCopy(
            widget.locale,
            de: 'Karosserie und\nSichtprüfung',
            it: 'Carrozzeria e\ncontrollo visivo',
            en: 'Bodywork and\nvisual check',
            fr: 'Carrosserie et\ncontrôle visuel',
          ),
          subtitle: _serviceFlowCopy(
            widget.locale,
            de: 'Verglasung, Schäden und Unterseite',
            it: 'Vetri, danni e sottoscocca',
            en: 'Glazing, damage and underside',
            fr: 'Vitrages, dommages et soubassement',
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          workshopServiceLabel(widget.locale, workshopServiceRepair),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            final isPhone = constraints.maxWidth < 600;
            final crossAxisCount = isDesktop
                ? 3
                : isPhone
                    ? 1
                    : 2;
            final outerPadding = isDesktop ? 28.0 : 16.0;
            final containerPadding = isDesktop ? 40.0 : 24.0;
            final gridSpacingX = isDesktop ? 60.0 : 24.0;
            final gridSpacingY = isDesktop ? 50.0 : 30.0;
            final mainAxisExtent = isDesktop
                ? 182.0
                : isPhone
                    ? 170.0
                    : 208.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                outerPadding,
                16,
                outerPadding,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Container(
                    padding: EdgeInsets.all(containerPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFEAEAEA),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Text(
                            _serviceFlowCopy(
                              widget.locale,
                              de: 'Was wird bei Wartung und Reparatur geprüft?',
                              it: 'Cosa viene controllato per manutenzione e riparazione?',
                              en: 'What is checked during maintenance and repair?',
                              fr: 'Que contrôle-t-on lors de l’entretien et de la réparation ?',
                            ),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: gridSpacingX,
                            mainAxisSpacing: gridSpacingY,
                            mainAxisExtent: mainAxisExtent,
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _ServiceRepairInfoTile(item: item);
                          },
                        ),
                        const SizedBox(height: 40),
                        Text(
                          'Fahrzeugreinigung',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Wählen Sie das gewünschte Reinigungspaket',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, cleaningConstraints) {
                            final isMobile = cleaningConstraints.maxWidth < 900;
                            final itemWidth = isMobile
                                ? cleaningConstraints.maxWidth
                                : (cleaningConstraints.maxWidth - 32) / 3;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _CleaningProgramCard(
                                  width: itemWidth,
                                  icon: Icons.local_car_wash_outlined,
                                  title: 'Bronze',
                                  subtitle: 'Im Service inklusive',
                                  bullets: const [
                                    'Standard-Aussenwäsche',
                                    'Armaturenbrett und Display reinigen',
                                    'Fussraum vorne saugen',
                                    'Front- und Seitenscheiben aussen reinigen',
                                    'Schweller vorne reinigen',
                                  ],
                                  badgeText: 'Im Service kostenlos',
                                  badgeColor: const Color(0xFF16A34A),
                                  selected: _selectedCleaningPackage ==
                                      workshopCleaningPackageBronze,
                                  onTap: () {
                                    setState(() {
                                      _selectedCleaningPackage =
                                          workshopCleaningPackageBronze;
                                    });
                                  },
                                ),
                                _CleaningProgramCard(
                                  width: itemWidth,
                                  icon: Icons.auto_awesome_outlined,
                                  title: 'Silber',
                                  subtitle: 'Zusätzlich zu Bronze',
                                  bullets: const [
                                    'Felgenreinigung',
                                    'Reifenpflege mit Reifenglanz',
                                    'Frontscheibe innen reinigen',
                                    'Seitenscheiben innen reinigen',
                                    'Innenraum komplett saugen',
                                  ],
                                  badgeText: 'Premium Reinigung',
                                  badgeColor: const Color(0xFF2563EB),
                                  selected: _selectedCleaningPackage ==
                                      workshopCleaningPackageSilber,
                                  onTap: () {
                                    setState(() {
                                      _selectedCleaningPackage =
                                          workshopCleaningPackageSilber;
                                    });
                                  },
                                ),
                                _CleaningProgramCard(
                                  width: itemWidth,
                                  icon: Icons.workspace_premium_outlined,
                                  title: 'Gold',
                                  subtitle: 'Zusätzlich zu Silber',
                                  bullets: const [
                                    'Komplette Innenreinigung',
                                    'Erweiterte Premiumwäsche',
                                    'Reinigung aller Türfalze',
                                    'Reinigung aller Innenablagen',
                                    'Reinigung sämtlicher Innenfenster',
                                    'Professionelles Finish',
                                  ],
                                  badgeText: 'Maximale Pflege',
                                  badgeColor: const Color(0xFFF59E0B),
                                  selected: _selectedCleaningPackage ==
                                      workshopCleaningPackageGold,
                                  onTap: () {
                                    setState(() {
                                      _selectedCleaningPackage =
                                          workshopCleaningPackageGold;
                                    });
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () =>
                                widget.onBookNow(_selectedCleaningPackage),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              'Reinigung buchen',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceRepairInfoTile extends StatelessWidget {
  const _ServiceRepairInfoTile({required this.item});

  final _ServiceRepairInfoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          item.icon,
          color: const Color(0xFF334155),
          size: 40,
        ),
        const SizedBox(height: 12),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
            height: 1.28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: const Color(0xFF6B7280),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _CleaningProgramCard extends StatelessWidget {
  const _CleaningProgramCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.selected,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final double width;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final bool selected;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEFF6FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE5E7EB),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF1D4ED8),
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    if (selected && badgeText != null)
                      const SizedBox(width: 10),
                    if (badgeText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? const Color(0xFF16A34A))
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeText!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: badgeColor ?? const Color(0xFF16A34A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                for (final bullet in bullets) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bullet,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4B5563),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (bullet != bullets.last) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectionOptionData {
  const _InspectionOptionData({
    required this.value,
    required this.primaryLines,
    this.secondaryLine,
  });

  final String value;
  final List<String> primaryLines;
  final String? secondaryLine;
}

class _InspectionOptionCard extends StatelessWidget {
  const _InspectionOptionCard({
    required this.title,
    required this.primaryLines,
    required this.selected,
    required this.onTap,
    this.secondaryLine,
  });

  final String title;
  final List<String> primaryLines;
  final String? secondaryLine;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off_outlined,
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF94A3B8),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final line in primaryLines) ...[
                      Text(
                        line,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF4B5563),
                          height: 1.45,
                        ),
                      ),
                      if (line != primaryLines.last) const SizedBox(height: 6),
                    ],
                    if (secondaryLine != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        secondaryLine!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRepairInfoItem {
  const _ServiceRepairInfoItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _ServiceOptionCard extends StatelessWidget {
  const _ServiceOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFEAEAEA),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        height: 1.25,
                      ),
                    ),
                    if (description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
