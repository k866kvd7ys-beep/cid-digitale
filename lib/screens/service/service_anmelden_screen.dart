import 'package:cid_digitale/screens/service/workshop_slot_picker_screen.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/material.dart';

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
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: title,
          serviceType: serviceType,
          serviceSelectionKey: serviceSelectionKey,
          serviceDetail: serviceDetail,
          cleaningPackage: cleaningPackage,
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
                        onContinue: (serviceDetail) => _openBooking(
                          context,
                          workshopServiceLabel(
                            locale,
                            workshopServiceInspection,
                          ),
                          serviceType: workshopServiceInspection,
                          serviceDetail: serviceDetail,
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
    required this.onContinue,
  });

  final String locale;
  final ValueChanged<String> onContinue;

  @override
  State<_ServiceInspectionScreen> createState() =>
      _ServiceInspectionScreenState();
}

class _ServiceInspectionScreenState extends State<_ServiceInspectionScreen> {
  String _selectedDetail = workshopInspectionDetail30000;

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
                        child: ElevatedButton(
                          onPressed: () => widget.onContinue(_selectedDetail),
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
                ],
              ),
            ),
          ),
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
