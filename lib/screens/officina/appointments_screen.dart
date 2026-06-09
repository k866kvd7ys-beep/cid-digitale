import 'dart:async';

import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:cid_digitale/utils/tire_service_type_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentsScreen extends StatefulWidget {
  final String workshopId;
  const AppointmentsScreen({super.key, required this.workshopId});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _sb = Supabase.instance.client;
  final _requestService = AppointmentRequestsService();
  final _df = DateFormat('dd.MM.yyyy');
  final _tf = DateFormat('HH:mm');
  Timer? _refreshTimer;

  String _copy({
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

  String _statusLabel(String status) => _copy(
        de: switch (status) {
          'confirmed' => 'Termin bestaetigt',
          'in_progress' => 'Fahrzeug in Bearbeitung',
          'completed' => 'Reparatur abgeschlossen',
          'cancelled' => 'Termin storniert',
          _ => 'Anfrage gesendet',
        },
        it: switch (status) {
          'confirmed' => 'Appuntamento confermato',
          'in_progress' => 'Veicolo in lavorazione',
          'completed' => 'Riparazione completata',
          'cancelled' => 'Appuntamento annullato',
          _ => 'Richiesta inviata',
        },
        en: switch (status) {
          'confirmed' => 'Appointment confirmed',
          'in_progress' => 'Vehicle in progress',
          'completed' => 'Repair completed',
          'cancelled' => 'Appointment cancelled',
          _ => 'Request sent',
        },
        fr: switch (status) {
          'confirmed' => 'Rendez-vous confirme',
          'in_progress' => 'Vehicule en reparation',
          'completed' => 'Reparation terminee',
          'cancelled' => 'Rendez-vous annule',
          _ => 'Demande envoyee',
        },
      );

  String get _localeCode => tireLocaleCode(context);

  String _tireServiceLabel(AppointmentRequest request) =>
      localizedTireServiceType(
        _localeCode,
        tireServiceType: request.tireServiceType,
        serviceType: request.serviceType,
      );

  String _serviceLabel(AppointmentRequest request) {
    if (isTireAppointmentService(request.serviceType)) {
      return _tireServiceLabel(request);
    }
    if (request.serviceType == workshopServiceInspection) {
      return workshopServiceLabel(
        normalizeWorkshopServiceLocale(request.locale),
        workshopServiceInspection,
      );
    }
    if (request.serviceType == 'service_anmelden' &&
        request.serviceSelectionKey?.trim().isNotEmpty == true) {
      return workshopServiceLabel(
        normalizeWorkshopServiceLocale(request.locale),
        request.serviceSelectionKey,
      );
    }
    return request.damageType?.isNotEmpty == true
        ? request.damageType!
        : request.serviceType;
  }

  String? _cleaningPackageLabel(AppointmentRequest request) {
    final isRepairFlow = request.serviceType == 'service_anmelden' &&
        request.serviceSelectionKey == workshopServiceRepair;
    final isInspectionFlow = request.serviceType == workshopServiceInspection;
    if (!isRepairFlow && !isInspectionFlow) {
      return null;
    }

    return workshopCleaningPackageLabel(
      normalizeWorkshopServiceLocale(request.locale),
      request.cleaningPackage,
    );
  }

  String? _serviceDetailLabel(AppointmentRequest request) {
    return workshopServiceDetailLabel(
      normalizeWorkshopServiceLocale(request.locale),
      serviceType: request.serviceType,
      serviceSelectionKey: request.serviceSelectionKey,
      serviceDetail: request.serviceDetail,
    );
  }

  String? _additionalServicesLabel(AppointmentRequest request) {
    if (request.additionalServices.isEmpty) return null;
    final locale = normalizeWorkshopServiceLocale(request.locale);
    return request.additionalServices
        .map((service) => workshopAdditionalServiceLabel(locale, service))
        .join(', ');
  }

  String _updatedSnackBar() => _copy(
        de: 'Anfragestatus aktualisiert',
        it: 'Stato richiesta aggiornato',
        en: 'Request status updated',
        fr: 'Statut de la demande mis a jour',
      );

  Color _statusColor(String status) {
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

  Future<List<AppointmentRequest>> _load() async {
    final res = await _sb
        .from('appointment_requests')
        .select('*')
        .order('appointment_date', ascending: true)
        .order('appointment_time', ascending: true)
        .limit(500);
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(AppointmentRequest.fromMap)
        .toList();
  }

  Future<void> _updateStatus(
    AppointmentRequest request,
    String newStatus,
  ) async {
    final updated = await _requestService.updateRequestStatus(
      requestId: request.id,
      requestStatus: newStatus,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_updatedSnackBar())),
    );
    setState(() {
      _future = Future.value(
        _currentItems
            .map((item) => item.id == updated.id ? updated : item)
            .toList(),
      );
    });
  }

  late Future<List<AppointmentRequest>> _future;
  List<AppointmentRequest> _currentItems = const [];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (!mounted) return;
        setState(() {
          _future = _load();
        });
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const statusOptions = [
      'pending',
      'confirmed',
      'in_progress',
      'completed',
      'cancelled',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: FutureBuilder<List<AppointmentRequest>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          _currentItems = items;
          if (items.isEmpty) {
            return const Center(child: Text('Keine Termine'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final request = items[i];
              final start = request.appointmentDate.toLocal();
              final end = DateTime(
                start.year,
                start.month,
                start.day,
                _parseHour(request.appointmentTime),
                _parseMinute(request.appointmentTime),
              ).add(Duration(minutes: request.durationMinutes));
              final status = request.requestStatus;
              final statusColor = _statusColor(status);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.32),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_df.format(start)} • ${_tf.format(start)} - ${_tf.format(end)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
                            _statusLabel(status),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      request.customerName?.trim().isNotEmpty == true
                          ? request.customerName!.trim()
                          : '-',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if ((request.licensePlate ?? '').isNotEmpty)
                          request.licensePlate!,
                        if ((request.customerPhone ?? '').isNotEmpty)
                          request.customerPhone!,
                        if ((request.customerEmail ?? '').isNotEmpty)
                          request.customerEmail!,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _serviceLabel(request),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.70),
                          ),
                    ),
                    if (isTireAppointmentService(request.serviceType)) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${tireServiceSectionLabel(_localeCode)}: ${_tireServiceLabel(request)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.82),
                            ),
                      ),
                    ] else if (request.serviceType == 'service_anmelden' &&
                        request.serviceSelectionKey?.trim().isNotEmpty ==
                            true) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_copy(de: 'Service', it: 'Servizio', en: 'Service', fr: 'Service')}: ${_serviceLabel(request)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.82),
                            ),
                      ),
                      if (_cleaningPackageLabel(request) != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${workshopVehicleCleaningFieldLabel(normalizeWorkshopServiceLocale(request.locale))}: ${workshopPackageShortLabel(normalizeWorkshopServiceLocale(request.locale))}: ${_cleaningPackageLabel(request)!}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.82),
                                  ),
                        ),
                      ],
                      if (request.serviceSelectionKey ==
                              workshopServiceClimate &&
                          _serviceDetailLabel(request) != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${workshopInspectionSelectionFieldLabel(normalizeWorkshopServiceLocale(request.locale))}: ${_serviceDetailLabel(request)!}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.82),
                                  ),
                        ),
                      ],
                    ] else if (request.serviceType ==
                        workshopServiceInspection) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${_copy(de: 'Service', it: 'Servizio', en: 'Service', fr: 'Service')}: ${_serviceLabel(request)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.82),
                            ),
                      ),
                      if (_serviceDetailLabel(request) != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${workshopInspectionSelectionFieldLabel(normalizeWorkshopServiceLocale(request.locale))}: ${_serviceDetailLabel(request)!}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.82),
                                  ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        '${workshopCleaningPackageFieldLabel(normalizeWorkshopServiceLocale(request.locale))}: ${workshopCleaningPackageLabel(normalizeWorkshopServiceLocale(request.locale), request.cleaningPackage)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.82),
                            ),
                      ),
                      if (_additionalServicesLabel(request) != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${workshopAdditionalServicesFieldLabel(normalizeWorkshopServiceLocale(request.locale))}: ${_additionalServicesLabel(request)!}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.82),
                                  ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value:
                          statusOptions.contains(status) ? status : 'pending',
                      decoration: InputDecoration(
                        labelText: _copy(
                          de: 'Status',
                          it: 'Stato',
                          en: 'Status',
                          fr: 'Statut',
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.35),
                          ),
                        ),
                      ),
                      items: statusOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(_statusLabel(item)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null || value == request.requestStatus) {
                          return;
                        }
                        await _updateStatus(request, value);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _parseHour(String raw) {
    final normalized = raw.length == 5 ? '$raw:00' : raw;
    final parts = normalized.split(':');
    return parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  }

  int _parseMinute(String raw) {
    final normalized = raw.length == 5 ? '$raw:00' : raw;
    final parts = normalized.split(':');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  }
}
