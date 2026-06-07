import 'package:cid_digitale/screens/service/workshop_slot_picker_screen.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/material.dart';

class ServiceAnmeldenScreen extends StatelessWidget {
  const ServiceAnmeldenScreen({super.key});

  String _locale(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  void _openBooking(
    BuildContext context,
    String locale,
    String serviceKey,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopSlotPickerScreen(
          title: workshopServiceLabel(locale, serviceKey),
          serviceType: 'service_anmelden',
          serviceSelectionKey: serviceKey,
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
                if (serviceKey == workshopServiceRepair) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ServiceRepairInfoScreen(
                        onBookNow: () =>
                            _openBooking(context, locale, serviceKey),
                      ),
                    ),
                  );
                  return;
                }

                _openBooking(context, locale, serviceKey);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ServiceRepairInfoScreen extends StatelessWidget {
  const _ServiceRepairInfoScreen({required this.onBookNow});

  final VoidCallback onBookNow;

  static const List<_ServiceRepairInfoItem> _items = [
    _ServiceRepairInfoItem(
      icon: Icons.search,
      title: 'Außenbereich,\nMotor und\nUnterboden',
      subtitle: 'Sichtkontrolle',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.opacity,
      title: 'Flüssigkeiten',
      subtitle: 'Kontrolle, Ölwechsel (wenn fällig)',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.fact_check,
      title: 'Bremsen und\nStossdämpfer',
      subtitle: 'Kontrolle und Messung auf dem Prüfstand (bei Bedarf)',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.lightbulb_outline,
      title: 'Beleuchtung',
      subtitle: 'Funktionskontrolle und Einstellung',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.car_repair,
      title: 'Karosserie,\nFahrwerk,\nAufhängung',
      subtitle: 'Sichtkontrolle',
    ),
    _ServiceRepairInfoItem(
      icon: Icons.settings,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Was beinhaltet ein Autoservice bei uns',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.builder(
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
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
                          Icon(
                            item.icon,
                            color: const Color(0xFF1E3A8A),
                            size: 36,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
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
                    'Termin buchen',
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
