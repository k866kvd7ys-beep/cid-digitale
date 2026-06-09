import 'package:cid_digitale/screens/service/workshop_slot_picker_screen.dart';
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
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: title,
          serviceType: serviceType,
          serviceSelectionKey: serviceSelectionKey,
          serviceDetail: serviceDetail,
          cleaningPackage: cleaningPackage,
          additionalServices: additionalServices,
        ),
      ),
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
          de: 'Innenraum',
          it: 'Abitacolo',
          en: 'Interior',
          fr: 'Habitacle',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: '(u. a. Kontrolleuchten, Heizung, Gebläse, Klimaanlage)',
          it: '(tra cui spie di controllo, riscaldamento, ventilazione, climatizzazione)',
          en: '(including warning lights, heating, blower, air conditioning)',
          fr: '(notamment voyants, chauffage, ventilation, climatisation)',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Motorraum',
          it: 'Vano motore',
          en: 'Engine bay',
          fr: 'Compartiment moteur',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: '(u. a. Batterie, Motorölstand)',
          it: '(tra cui batteria, livello olio motore)',
          en: '(including battery, engine oil level)',
          fr: '(notamment batterie, niveau d’huile moteur)',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Fahrzeugunterseite',
          it: 'Sottoscocca',
          en: 'Vehicle underside',
          fr: 'Partie inférieure du véhicule',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: '(u. a. Auspuff, Bremsen, Fahrwerk)',
          it: '(tra cui scarico, freni, assetto)',
          en: '(including exhaust, brakes, suspension)',
          fr: '(notamment échappement, freins, train roulant)',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Bereifung',
          it: 'Pneumatici',
          en: 'Tires',
          fr: 'Pneumatiques',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: '(u. a. Profiltiefe, Luftdruck)',
          it: '(tra cui profondità battistrada, pressione)',
          en: '(including tread depth, tire pressure)',
          fr: '(notamment profondeur du profil, pression)',
        ),
      ),
      _ServiceInfoBullet(
        title: _serviceFlowCopy(
          locale,
          de: 'Karosserie',
          it: 'Carrozzeria',
          en: 'Bodywork',
          fr: 'Carrosserie',
        ),
        detail: _serviceFlowCopy(
          locale,
          de: '(u. a. Steinschlag, Windschutzscheibe, Wischerblätter)',
          it: '(tra cui scheggiature, parabrezza, tergicristalli)',
          en: '(including stone chips, windshield, wiper blades)',
          fr: '(notamment impacts, pare-brise, balais d’essuie-glace)',
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
                        de: 'Fahrzeug-Check',
                        it: 'Check veicolo',
                        en: 'Vehicle check',
                        fr: 'Contrôle véhicule',
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
                        de: 'Der Fahrzeug-Check für CHF 59.- umfasst folgende Kontrollen:',
                        it: 'Il check veicolo da CHF 59.- comprende i seguenti controlli:',
                        en: 'The vehicle check for CHF 59.- includes the following inspections:',
                        fr: 'Le contrôle véhicule à CHF 59.- comprend les contrôles suivants :',
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
                        de: 'Hier mehr erfahren',
                        it: 'Scopri di più',
                        en: 'Learn more here',
                        fr: 'En savoir plus ici',
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
                    priceLabel: 'CHF 98.-',
                    bullets: [
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Funktionskontrolle der Klimaanlage',
                        it: 'Controllo funzionale dell’impianto climatizzazione',
                        en: 'Functional check of the air conditioning system',
                        fr: 'Contrôle du fonctionnement de la climatisation',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Reinigung des Verdampfers',
                        it: 'Pulizia dell’evaporatore',
                        en: 'Cleaning of the evaporator',
                        fr: 'Nettoyage de l’évaporateur',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Pollenfilter prüfen und eventuell ersetzen (Material nicht eingeschlossen)',
                        it: 'Controllo del filtro antipolline ed eventuale sostituzione (materiale non incluso)',
                        en: 'Check pollen filter and replace if necessary (material not included)',
                        fr: 'Contrôle du filtre à pollen et remplacement éventuel (matériel non inclus)',
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
                    priceLabel: 'CHF 195.-',
                    description: _serviceFlowCopy(
                      widget.locale,
                      de: 'Der Klimaservice Plus umfasst zusätzlich zum normalen Klimaservice:',
                      it: 'Il servizio clima Plus comprende inoltre, rispetto al normale servizio clima:',
                      en: 'In addition to the standard A/C service, the A/C Service Plus includes:',
                      fr: 'En plus du service climatisation standard, le service climatisation Plus comprend :',
                    ),
                    bullets: [
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Druckkontrolle im Kältemittelkreislauf',
                        it: 'Controllo della pressione nel circuito del refrigerante',
                        en: 'Pressure check in the refrigerant circuit',
                        fr: 'Contrôle de pression du circuit de réfrigérant',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Evakuierung und Reinigung',
                        it: 'Evacuazione e pulizia',
                        en: 'Evacuation and cleaning',
                        fr: 'Évacuation et nettoyage',
                      ),
                      _serviceFlowCopy(
                        widget.locale,
                        de: 'Nachfüllen des Kältemittels (wenn nötig)',
                        it: 'Ricarica del refrigerante (se necessario)',
                        en: 'Refill refrigerant (if necessary)',
                        fr: 'Recharge du fluide frigorigène (si nécessaire)',
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
        de: 'Weniger Kraftstoffverbrauch',
        it: 'Minore consumo di carburante',
        en: 'Lower fuel consumption',
        fr: 'Réduction de la consommation de carburant',
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
                        de: 'Vermessung der kompletten Lenkgeometrie',
                        it: 'Controllo completo della geometria dello sterzo',
                        en: 'Complete steering geometry measurement',
                        fr: 'Contrôle complet de la géométrie de direction',
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
        icon: Icons.cleaning_services_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'MFK-Reinigung',
          it: 'Pulizia MFK',
          en: 'MFK cleaning',
          fr: 'Nettoyage MFK',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Motor- und Chassisreinigung',
            it: 'Pulizia motore e telaio',
            en: 'Engine and chassis cleaning',
            fr: 'Nettoyage moteur et châssis',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Maschinenwäsche aussen',
            it: 'Lavaggio esterno automatico',
            en: 'Exterior machine wash',
            fr: 'Lavage extérieur en machine',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.tire_repair_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Räder, Aufhängung, Lenkung',
          it: 'Ruote, sospensioni, sterzo',
          en: 'Wheels, suspension, steering',
          fr: 'Roues, suspension, direction',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Korrekte Bereifung',
            it: 'Pneumatici corretti',
            en: 'Correct tires',
            fr: 'Pneumatiques conformes',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Spiel',
            it: 'Giochi',
            en: 'Play',
            fr: 'Jeu',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Zustand von Gummis',
            it: 'Stato di gommini',
            en: 'Condition of rubber parts',
            fr: 'État des caoutchoucs',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Manschetten usw.',
            it: 'Cuffie ecc.',
            en: 'Boots etc.',
            fr: 'Soufflets, etc.',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.precision_manufacturing_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Motor, Kraftübertragung',
          it: 'Motore, trasmissione',
          en: 'Engine, power transmission',
          fr: 'Moteur, transmission',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Dichtheit',
            it: 'Tenuta',
            en: 'Leak tightness',
            fr: 'Étanchéité',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Funktion',
            it: 'Funzionamento',
            en: 'Function',
            fr: 'Fonctionnement',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Geräusche',
            it: 'Rumori',
            en: 'Noises',
            fr: 'Bruits',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.car_crash_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Bremsen',
          it: 'Freni',
          en: 'Brakes',
          fr: 'Freins',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Kontrolle auf Bremsprüfstand',
            it: 'Controllo al banco freni',
            en: 'Check on brake test bench',
            fr: 'Contrôle au banc de freinage',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Sichtkontrolle',
            it: 'Controllo visivo',
            en: 'Visual inspection',
            fr: 'Contrôle visuel',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.directions_car_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Aufbau inkl. Glas',
          it: 'Carrozzeria incl. vetri',
          en: 'Body incl. glass',
          fr: 'Carrosserie incl. vitrages',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Funktion',
            it: 'Funzionamento',
            en: 'Function',
            fr: 'Fonctionnement',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Spiel',
            it: 'Giochi',
            en: 'Play',
            fr: 'Jeu',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Rost',
            it: 'Ruggine',
            en: 'Rust',
            fr: 'Rouille',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Beschädigungen usw.',
            it: 'Danni ecc.',
            en: 'Damage etc.',
            fr: 'Dommages, etc.',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.lightbulb_outline,
        title: _serviceFlowCopy(
          locale,
          de: 'Elektrische Anlage, Beleuchtung',
          it: 'Impianto elettrico, illuminazione',
          en: 'Electrical system, lighting',
          fr: 'Installation électrique, éclairage',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Funktion',
            it: 'Funzionamento',
            en: 'Function',
            fr: 'Fonctionnement',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Einstellung',
            it: 'Regolazione',
            en: 'Adjustment',
            fr: 'Réglage',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.health_and_safety_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Sicherheitssysteme',
          it: 'Sistemi di sicurezza',
          en: 'Safety systems',
          fr: 'Systèmes de sécurité',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Gurten',
            it: 'Cinture',
            en: 'Seat belts',
            fr: 'Ceintures',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Airbag',
            it: 'Airbag',
            en: 'Airbag',
            fr: 'Airbag',
          ),
          _serviceFlowCopy(
            locale,
            de: 'usw.',
            it: 'ecc.',
            en: 'etc.',
            fr: 'etc.',
          ),
        ],
      ),
      _MfkInfoItem(
        icon: Icons.description_outlined,
        title: _serviceFlowCopy(
          locale,
          de: 'Dokumente, Identifikation',
          it: 'Documenti, identificazione',
          en: 'Documents, identification',
          fr: 'Documents, identification',
        ),
        lines: [
          _serviceFlowCopy(
            locale,
            de: 'Kennzeichen',
            it: 'Targa',
            en: 'License plate',
            fr: 'Plaque d’immatriculation',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Fahrzeugpapiere',
            it: 'Documenti del veicolo',
            en: 'Vehicle documents',
            fr: 'Documents du véhicule',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Beiblätter',
            it: 'Documenti supplementari',
            en: 'Supplementary sheets',
            fr: 'Documents complémentaires',
          ),
          _serviceFlowCopy(
            locale,
            de: 'Fahrgestellnummer',
            it: 'Numero di telaio',
            en: 'Chassis number',
            fr: 'Numéro de châssis',
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1100
        ? 3
        : width >= 720
            ? 2
            : 1;
    const crossSpacing = 16.0;
    const mainSpacing = 8.0;
    final contentWidth = width >= 1100 ? 1040.0 : 960.0;

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
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
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
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _serviceFlowCopy(
                            locale,
                            de: 'Die Vorbereitung für die Motorfahrzeugkontrolle beinhaltet folgende Punkte:',
                            it: 'La preparazione per il controllo dei veicoli a motore comprende i seguenti punti:',
                            en: 'Preparation for the motor vehicle inspection includes the following points:',
                            fr: 'La préparation au contrôle des véhicules automobiles comprend les points suivants :',
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF6B7280),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items().length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: crossSpacing,
                      mainAxisSpacing: mainSpacing,
                      mainAxisExtent: crossAxisCount == 1 ? 204 : 196,
                    ),
                    itemBuilder: (context, index) {
                      return _MfkInfoCard(item: _items()[index]);
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: onBookNow,
                      style: ElevatedButton.styleFrom(
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.14),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
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
  const _MfkInfoCard({required this.item});

  final _MfkInfoItem item;

  @override
  State<_MfkInfoCard> createState() => _MfkInfoCardState();
}

class _MfkInfoCardState extends State<_MfkInfoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
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
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                item.icon,
                color: const Color(0xFF1D4ED8),
                size: 32,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            ...item.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                          height: 1.32,
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
  const _ServiceRepairInfoScreen({required this.onBookNow});

  final ValueChanged<String> onBookNow;

  @override
  State<_ServiceRepairInfoScreen> createState() =>
      _ServiceRepairInfoScreenState();
}

class _ServiceRepairInfoScreenState extends State<_ServiceRepairInfoScreen> {
  String _selectedCleaningPackage = workshopCleaningPackageBronze;

  static const List<_ServiceRepairInfoItem> _items = [
    _ServiceRepairInfoItem(
      icon: Icons.search_outlined,
      title: 'Außenbereich,\nMotor und\nUnterboden',
      subtitle: 'Sichtkontrolle',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.opacity_outlined,
      title: 'Flüssigkeiten',
      subtitle: 'Kontrolle, Ölwechsel (wenn fällig)',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.fact_check_outlined,
      title: 'Bremsen und\nStossdämpfer',
      subtitle: 'Kontrolle und Messung auf dem Prüfstand (bei Bedarf)',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.highlight_outlined,
      title: 'Beleuchtung',
      subtitle: 'Funktionskontrolle und Einstellung',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.car_repair_outlined,
      title: 'Karosserie,\nFahrwerk,\nAufhängung',
      subtitle: 'Sichtkontrolle',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.settings_outlined,
      title: 'Mechanik,\nGetriebe,\nMotor,\nAbgasanlage',
      subtitle: 'Sichtkontrolle',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Service und Reparaturarbeiten',
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
            final crossAxisCount = isDesktop ? 3 : 2;
            final outerPadding = isDesktop ? 28.0 : 16.0;
            final containerPadding = isDesktop ? 40.0 : 24.0;
            final gridSpacingX = isDesktop ? 60.0 : 24.0;
            final gridSpacingY = isDesktop ? 50.0 : 30.0;
            final mainAxisExtent = isDesktop ? 182.0 : 208.0;

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
                            'Was beinhaltet ein Autoservice bei uns',
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
                          itemCount: _items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: gridSpacingX,
                            mainAxisSpacing: gridSpacingY,
                            mainAxisExtent: mainAxisExtent,
                          ),
                          itemBuilder: (context, index) {
                            final item = _items[index];
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
