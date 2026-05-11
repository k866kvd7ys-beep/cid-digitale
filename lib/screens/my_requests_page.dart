import 'dart:async';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/screens/request_detail_screen.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({
    super.key,
    this.incidentsTab = const SizedBox.shrink(),
    this.initialTabIndex = 0,
  });

  final Widget incidentsTab;
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.my_requests_title),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tab_appointments),
              Tab(text: l10n.tab_incidents),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const _AppointmentsTab(),
            incidentsTab,
          ],
        ),
      ),
    );
  }
}

enum _RequestsFilter { all, service, tires, damage }

class _AppointmentsTab extends StatefulWidget {
  const _AppointmentsTab();

  @override
  State<_AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends State<_AppointmentsTab> {
  final _service = AppointmentRequestsService();
  final _df = DateFormat('dd.MM.yyyy');
  final _tf = DateFormat('HH:mm');
  Timer? _refreshTimer;

  _RequestsFilter _filter = _RequestsFilter.all;
  bool _loading = false;
  List<AppointmentRequest> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final list = await _service.fetchMyRequests(serviceFilter: _filter.name);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore caricamento: $e')),
      );
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final chips = [
      _RequestsFilter.all,
      _RequestsFilter.service,
      _RequestsFilter.tires,
      _RequestsFilter.damage,
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: chips.map((f) {
              final selected = _filter == f;
              return ChoiceChip(
                label: Text(_labelForFilter(l10n, f)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _filter = f);
                  _load();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildLists(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLists(AppLocalizations l10n) {
    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(l10n.empty_appointments)),
        ],
      );
    }

    final active =
        _items.where((r) => r.requestStatus != 'cancelled').toList()
      ..sort((a, b) => _sortDate(a).compareTo(_sortDate(b)));
    final cancelled =
        _items.where((r) => r.requestStatus == 'cancelled').toList()
      ..sort((a, b) => _sortDate(b).compareTo(_sortDate(a)));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ...active.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AppointmentCard(
                record: r,
                typeLabel: _typeLabel(l10n, r),
                subtitle: _subtitle(l10n, r),
                icon: _iconFor(r),
                statusLabel: _statusLabel(context, r.requestStatus),
                statusColor: _statusColor(context, r.requestStatus),
                onTap: () async {
                  final res = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RequestDetailScreen(request: r),
                    ),
                  );
                  if (res == 'cancelled') {
                    _load();
                  }
                },
              ),
            )),
        if (cancelled.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _statusLabel(context, 'cancelled'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...cancelled.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AppointmentCard(
                  record: r,
                  typeLabel: _typeLabel(l10n, r),
                  subtitle: _subtitle(l10n, r),
                  icon: _iconFor(r),
                  muted: true,
                  statusLabel: _statusLabel(context, r.requestStatus),
                  statusColor: _statusColor(context, r.requestStatus),
                  onTap: () async {
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(request: r),
                      ),
                    );
                    if (res == 'cancelled') {
                      _load();
                    }
                  },
                ),
              )),
        ],
        const SizedBox(height: 10),
      ],
    );
  }

  DateTime _sortDate(AppointmentRequest r) {
    final base = r.appointmentDate;
    try {
      final t = DateTime.parse(
          '1970-01-01T${r.appointmentTime.length == 5 ? '${r.appointmentTime}:00' : r.appointmentTime}');
      return DateTime(
          base.year, base.month, base.day, t.hour, t.minute, t.second);
    } catch (_) {
      return base;
    }
  }

  String _labelForFilter(AppLocalizations l10n, _RequestsFilter f) {
    switch (f) {
      case _RequestsFilter.all:
        return l10n.my_requests_filter_all;
      case _RequestsFilter.service:
        return l10n.my_requests_filter_service;
      case _RequestsFilter.tires:
        return l10n.my_requests_filter_tires;
      case _RequestsFilter.damage:
        return l10n.my_requests_filter_damage;
    }
  }

  String _typeLabel(AppLocalizations l10n, AppointmentRequest r) {
    final serviceType = r.serviceType;
    final damageType = r.toMap()['damage_type'] as String? ?? '';

    if (serviceType.startsWith('damage_')) {
      return '${l10n.service_type_damage}: ${_damageLabel(l10n, damageType)}';
    }
    if (serviceType == 'service_anmelden') return l10n.service_type_service;
    if (serviceType == 'raeder_sommer' || serviceType == 'raeder_winter') {
      return l10n.service_type_tires;
    }
    return serviceType.isEmpty ? l10n.service_type_service : serviceType;
  }

  String _damageLabel(AppLocalizations l10n, String damageType) {
    switch (damageType) {
      case 'damage_glass':
        return l10n.damage_glass;
      case 'damage_hail':
        return l10n.damage_hail;
      case 'damage_marten':
        return l10n.damage_marten;
      case 'damage_parking':
        return l10n.damage_parking;
      case 'damage_comprehensive':
        return l10n.damage_comprehensive;
      default:
        return l10n.service_type_damage;
    }
  }

  String _subtitle(AppLocalizations l10n, AppointmentRequest r) {
    final name = r.customerName ?? '';
    final plate = r.licensePlate ?? '';
    final dateStr = r.appointmentDate.toIso8601String().substring(0, 10);
    final timeStr = r.appointmentTime;
    String dateTimeLabel = '';
    try {
      final d = DateTime.parse(dateStr);
      dateTimeLabel = _df.format(d.toLocal());
    } catch (_) {}
    try {
      final t = DateTime.parse('1970-01-01T$timeStr');
      dateTimeLabel =
          '${dateTimeLabel.isNotEmpty ? '$dateTimeLabel · ' : ''}${_tf.format(t)}';
    } catch (_) {}
    final parts = [
      if (dateTimeLabel.isNotEmpty) dateTimeLabel,
      if (name.isNotEmpty) name,
      if (plate.isNotEmpty) plate,
      if ((r.customerPhone ?? '').isNotEmpty) r.customerPhone!,
      if ((r.customerEmail ?? '').isNotEmpty) r.customerEmail!,
    ];
    return parts.join(' • ');
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'confirmed':
        return _copy(
          context,
          de: 'Termin bestaetigt',
          it: 'Appuntamento confermato',
          en: 'Appointment confirmed',
          fr: 'Rendez-vous confirme',
        );
      case 'in_progress':
        return _copy(
          context,
          de: 'Fahrzeug in Bearbeitung',
          it: 'Veicolo in lavorazione',
          en: 'Vehicle in progress',
          fr: 'Vehicule en reparation',
        );
      case 'completed':
        return _copy(
          context,
          de: 'Reparatur abgeschlossen',
          it: 'Riparazione completata',
          en: 'Repair completed',
          fr: 'Reparation terminee',
        );
      case 'cancelled':
        return _copy(
          context,
          de: 'Termin storniert',
          it: 'Appuntamento annullato',
          en: 'Appointment cancelled',
          fr: 'Rendez-vous annule',
        );
      case 'pending':
      default:
        return _copy(
          context,
          de: 'Anfrage gesendet',
          it: 'Richiesta inviata',
          en: 'Request sent',
          fr: 'Demande envoyee',
        );
    }
  }

  String _copy(
    BuildContext context, {
    required String de,
    required String it,
    required String en,
    required String fr,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
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

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'in_progress':
        return const Color(0xFF7C3AED);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'pending':
      default:
        return const Color(0xFFEA580C);
    }
  }

  IconData _iconFor(AppointmentRequest r) {
    final serviceType = r.serviceType;
    if (serviceType.startsWith('damage_')) return Icons.car_crash;
    if (serviceType == 'raeder_sommer' || serviceType == 'raeder_winter') {
      return Icons.tire_repair;
    }
    return Icons.build;
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.record,
    required this.typeLabel,
    required this.subtitle,
    required this.icon,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
    this.muted = false,
  });

  final AppointmentRequest record;
  final String typeLabel;
  final String subtitle;
  final IconData icon;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: muted
                ? Colors.grey.withOpacity(0.10)
                : theme.colorScheme.surface.withOpacity(0.4),
            border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted
                            ? theme.textTheme.titleMedium?.color
                                ?.withOpacity(0.6)
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted
                            ? theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.55)
                            : theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.75),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
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
