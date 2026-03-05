import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:flutter/material.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final AppointmentRequest request;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _service = AppointmentRequestsService();
  bool _busy = false;

  AppointmentRequest get request => widget.request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String value(String key) => (request.toMap()[key] ?? '').toString();

    String dateLabel() =>
        request.appointmentDate.toLocal().toIso8601String().substring(0, 10);

    String timeLabel() {
      final v = request.appointmentTime;
      if (v.isEmpty) return '-';
      return v.length == 5 ? '$v:00' : v;
    }

    String serviceLabel() {
      final serviceType = request.serviceType;
      final damageType = value('damage_type');
      if (serviceType.startsWith('damage_')) {
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
      if (serviceType == 'service_anmelden') return l10n.service_type_service;
      if (serviceType == 'raeder_sommer' || serviceType == 'raeder_winter') {
        return l10n.service_type_tires;
      }
      return serviceType.isEmpty ? l10n.my_requests_title : serviceType;
    }

    final canCancel = request.id.isNotEmpty && request.status != 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anfrage Details'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(l10n.service_type_service, serviceLabel()),
                      _row('Datum', dateLabel()),
                      _row('Uhrzeit', timeLabel()),
                      _row('Werkstatt', value('workshop_name')),
                      _row(
                          l10n.license_plate_label, request.licensePlate ?? ''),
                      _row('Name', request.customerName ?? ''),
                      _row('Telefon', request.customerPhone ?? ''),
                      _row('E-Mail', request.customerEmail ?? ''),
                      _row('Status', request.status),
                      if ((request.notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Notizen',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(request.notes ?? ''),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (canCancel) _cancelButton(context),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cancelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Termin stornieren'),
        onPressed: _busy
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Termin stornieren?'),
                    content: const Text(
                        'Möchtest du diese Anfrage wirklich stornieren?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Nein'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Ja'),
                      ),
                    ],
                  ),
                );

                if (ok != true) return;

                setState(() => _busy = true);
                try {
                  await _service.cancelRequest(request.id);
                  if (!mounted) return;
                  Navigator.of(context).pop('cancelled');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Fehler: $e')),
                  );
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}
