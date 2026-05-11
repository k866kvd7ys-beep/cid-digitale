import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/services/local_image_cache.dart';
import 'package:flutter/foundation.dart';
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
  Timer? _refreshTimer;
  late AppointmentRequest _request;

  AppointmentRequest get request => _request;
  bool get _isGlassDamageRequest =>
      request.serviceType == 'damage_glass' || request.damageType == 'damage_glass';
  bool get _isHailDamageRequest =>
      request.serviceType == 'damage_hail' || request.damageType == 'damage_hail';
  bool get _hasDamagePhotoSections => _isGlassDamageRequest || _isHailDamageRequest;

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

  String get _photosTitle => _copy(
        de: 'Fotos',
        it: 'Foto',
        en: 'Photos',
        fr: 'Photos',
      );

  String get _vehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _closeGlassPhotosTitle => _copy(
        de: 'Nahaufnahme Glas',
        it: 'Foto vetro vicino',
        en: 'Close-up glass photo',
        fr: 'Photo rapprochee du verre',
      );

  String get _frontVehiclePhotosTitle => _copy(
        de: 'Frontfoto des Fahrzeugs',
        it: 'Foto frontale della macchina',
        en: 'Front vehicle photo',
        fr: 'Photo frontale du vehicule',
      );

  String get _hailDamagePhotosTitle => _copy(
        de: 'Foto Hagelschaden',
        it: 'Foto dei danni da grandine',
        en: 'Hail damage photo',
        fr: 'Photo degats grele',
      );

  String get _hailOverviewPhotosTitle => _copy(
        de: 'Uebersichtsfoto Fahrzeug',
        it: 'Foto panoramica veicolo',
        en: 'Vehicle overview photo',
        fr: 'Photo generale du vehicule',
      );

  String get _hailVehicleDocumentPhotosTitle => _copy(
        de: 'Foto Fahrzeugausweis',
        it: 'Foto libretto',
        en: 'Vehicle document photo',
        fr: 'Photo carte grise',
      );

  String get _hailExtraPhotosTitle => _copy(
        de: 'Zusaetzliches Foto',
        it: 'Foto aggiuntiva',
        en: 'Additional photo',
        fr: 'Photo supplementaire',
      );

  String get _noPhotosText => _copy(
        de: 'Keine Fotos vorhanden.',
        it: 'Nessuna foto disponibile.',
        en: 'No photos available.',
        fr: 'Aucune photo disponible.',
      );

  String get _closePhotoText => _copy(
        de: 'Foto schließen',
        it: 'Chiudi foto',
        en: 'Close photo',
        fr: 'Fermer la photo',
      );

  String _requestStatusLabel(String status) => _copy(
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

  String _statusUpdatedSnackBarText() => _copy(
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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'confirmed':
        return Icons.event_available_outlined;
      case 'in_progress':
        return Icons.autorenew_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'pending':
      default:
        return Icons.schedule_send_outlined;
    }
  }

  String _lastUpdatedLabel() => _copy(
        de: 'Letzte Aktualisierung',
        it: 'Ultimo aggiornamento',
        en: 'Last update',
        fr: 'Derniere mise a jour',
      );

  String _appointmentDateLabel() => _copy(
        de: 'Termindatum',
        it: 'Data appuntamento',
        en: 'Appointment date',
        fr: 'Date du rendez-vous',
      );

  String _glassDamageDateLabel() {
    final raw = request.glassDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _statusUpdatedAtLabel() {
    final raw = request.statusUpdatedAt?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().replaceFirst('T', ' ').substring(0, 16);
  }

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshRequest(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String _hailDamageDateLabel() {
    final raw = request.hailDamageDate?.trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toLocal().toIso8601String().substring(0, 10);
  }

  String _hailDamageTimeLabel() {
    final raw = request.hailDamageTime?.trim() ?? '';
    if (raw.isEmpty) return '-';
    return raw.length == 5 ? raw : raw.substring(0, raw.length >= 5 ? 5 : raw.length);
  }

  String _damageTownValue() {
    if (_isHailDamageRequest) return request.hailDamageTown?.trim() ?? '';
    return request.glassDamageTown?.trim() ?? '';
  }

  String _damageDateValue() {
    if (_isHailDamageRequest) return request.hailDamageDate?.trim() ?? '';
    return request.glassDamageDate?.trim() ?? '';
  }

  String _damageDateLabel() {
    if (_isHailDamageRequest) return _hailDamageDateLabel();
    return _glassDamageDateLabel();
  }

  String _resolvedPhotoUrl(String source) {
    final trimmed = source.trim();
    if (!trimmed.startsWith('http')) return trimmed;
    try {
      return Uri.parse(trimmed).toString();
    } catch (_) {
      return trimmed;
    }
  }

  String _shortUrl(String url) {
    if (url.length <= 90) return url;
    return '${url.substring(0, 87)}...';
  }

  List<String> _readImageListFromNotes(String key) {
    final notes = request.notes?.trim() ?? '';
    if (notes.isEmpty || !notes.startsWith('{')) return const [];
    try {
      final decoded = jsonDecode(notes);
      if (decoded is Map && decoded[key] is List) {
        return (decoded[key] as List)
            .map((image) => image?.toString().trim() ?? '')
            .where((image) => image.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  List<String> _vehicleDocumentImageSources() {
    final direct = request.glassDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageVehicleDocumentImages');
  }

  List<String> _closeGlassImageSources() {
    final direct = request.glassDamageCloseGlassImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageCloseGlassImages');
  }

  List<String> _frontVehicleImageSources() {
    final direct = request.glassDamageFrontVehicleImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('glassDamageFrontVehicleImages');
  }

  List<String> _glassImageSources() {
    final direct = request.glassDamageImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;

    final notes = request.notes?.trim() ?? '';
    if (notes.isEmpty || !notes.startsWith('{')) return const [];

    try {
      final decoded = jsonDecode(notes);
      if (decoded is Map && decoded['glassDamageImages'] is List) {
        return (decoded['glassDamageImages'] as List)
            .map((image) => image?.toString().trim() ?? '')
            .where((image) => image.isNotEmpty)
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  List<String> _hailDamageImageSources() {
    final direct = request.hailDamageDamageImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    final specific = _readImageListFromNotes('hailDamageDamageImages');
    if (specific.isNotEmpty) return specific;
    return _readImageListFromNotes('hailDamageImages');
  }

  List<String> _hailVehicleDocumentImageSources() {
    final direct = request.hailDamageVehicleDocumentImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageVehicleDocumentImages');
  }

  List<String> _hailOverviewImageSources() {
    final direct = request.hailDamageOverviewImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageOverviewImages');
  }

  List<String> _hailExtraImageSources() {
    final direct = request.hailDamageExtraImages
        .map((image) => image.trim())
        .where((image) => image.isNotEmpty)
        .toList();
    if (direct.isNotEmpty) return direct;
    return _readImageListFromNotes('hailDamageExtraImages');
  }

  Widget _photoGrid(List<String> images) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 700 ? 2 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final image = images[index];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openPhotoViewer(image),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _GlassDamageImage(
                  source: image,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                  showLoadingIndicator: true,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _photoSection({
    required String title,
    required List<String> images,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _photoGrid(images),
      ],
    );
  }

  Future<void> _openPhotoViewer(String source) async {
    final url = _resolvedPhotoUrl(source);
    debugPrint('OPEN GLASS PHOTO URL: $url');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: url.startsWith('http')
                            ? Image.network(
                                url,
                                fit: BoxFit.contain,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.white,
                                        size: 42,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Foto non caricata',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _shortUrl(url),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : _GlassDamageImage(
                                source: url,
                                fit: BoxFit.contain,
                                borderRadius: BorderRadius.zero,
                                showLoadingIndicator: true,
                              ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    tooltip: _closePhotoText,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshRequest({bool showSnackBar = false}) async {
    final updated = await _service.fetchRequestById(request.id);
    if (!mounted || updated == null) return;
    setState(() {
      _request = updated;
    });
    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_statusUpdatedSnackBarText())),
      );
    }
  }

  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    final status = request.requestStatus;
    final statusColor = _statusColor(status);
    const progressSteps = ['pending', 'confirmed', 'in_progress', 'completed'];
    final currentIndex = progressSteps.indexOf(status);
    final isCancelled = status == 'cancelled';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: statusColor.withOpacity(0.08),
        border: Border.all(color: statusColor.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(status), color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _requestStatusLabel(status),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_lastUpdatedLabel()}: ${_statusUpdatedAtLabel()}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_appointmentDateLabel()}: ${request.appointmentDate.toLocal().toIso8601String().substring(0, 10)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isCancelled)
            Text(
              _requestStatusLabel(status),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Row(
              children: List.generate(progressSteps.length, (index) {
                final active = currentIndex >= index;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: active
                              ? _statusColor(progressSteps[index])
                              : theme.dividerColor.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index != progressSteps.length - 1)
                        Expanded(
                          child: Container(
                            height: 3,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: currentIndex > index
                                  ? _statusColor(progressSteps[index + 1])
                                      .withOpacity(0.55)
                                  : theme.dividerColor.withOpacity(0.20),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _photosSection() {
    if (_isHailDamageRequest) {
      final hailVehicleDocumentImages = _hailVehicleDocumentImageSources();
      final hailDamageImages = _hailDamageImageSources();
      final hailOverviewImages = _hailOverviewImageSources();
      final hailExtraImages = _hailExtraImageSources();
      final hasSpecificSections =
          hailVehicleDocumentImages.isNotEmpty ||
          hailDamageImages.isNotEmpty ||
          hailOverviewImages.isNotEmpty ||
          hailExtraImages.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (hasSpecificSections) ...[
            if (hailVehicleDocumentImages.isNotEmpty)
              _photoSection(
                title: _hailVehicleDocumentPhotosTitle,
                images: hailVehicleDocumentImages,
              ),
            if (hailVehicleDocumentImages.isNotEmpty &&
                (hailDamageImages.isNotEmpty ||
                    hailOverviewImages.isNotEmpty ||
                    hailExtraImages.isNotEmpty))
              const SizedBox(height: 12),
            if (hailDamageImages.isNotEmpty)
              _photoSection(
                title: _hailDamagePhotosTitle,
                images: hailDamageImages,
              ),
            if (hailDamageImages.isNotEmpty &&
                (hailOverviewImages.isNotEmpty || hailExtraImages.isNotEmpty))
              const SizedBox(height: 12),
            if (hailOverviewImages.isNotEmpty)
              _photoSection(
                title: _hailOverviewPhotosTitle,
                images: hailOverviewImages,
              ),
            if (hailOverviewImages.isNotEmpty && hailExtraImages.isNotEmpty)
              const SizedBox(height: 12),
            if (hailExtraImages.isNotEmpty)
              _photoSection(
                title: _hailExtraPhotosTitle,
                images: hailExtraImages,
              ),
          ] else
            Text(
              _noPhotosText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      );
    }

    final vehicleDocumentImages = _vehicleDocumentImageSources();
    final closeGlassImages = _closeGlassImageSources();
    final frontVehicleImages = _frontVehicleImageSources();
    final fallbackImages = _glassImageSources();
    final categorizedImages = <String>{
      ...vehicleDocumentImages.map((image) => image.trim()),
      ...closeGlassImages.map((image) => image.trim()),
      ...frontVehicleImages.map((image) => image.trim()),
    };
    final fallbackOnlyImages = fallbackImages
        .where((image) => !categorizedImages.contains(image.trim()))
        .toList();
    final hasSpecificSections = vehicleDocumentImages.isNotEmpty ||
        closeGlassImages.isNotEmpty ||
        frontVehicleImages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (hasSpecificSections) ...[
          if (vehicleDocumentImages.isNotEmpty)
            _photoSection(
              title: _vehicleDocumentPhotosTitle,
              images: vehicleDocumentImages,
            ),
          if (vehicleDocumentImages.isNotEmpty &&
              (closeGlassImages.isNotEmpty || frontVehicleImages.isNotEmpty))
            const SizedBox(height: 12),
          if (closeGlassImages.isNotEmpty)
            _photoSection(
              title: _closeGlassPhotosTitle,
              images: closeGlassImages,
            ),
          if (closeGlassImages.isNotEmpty && frontVehicleImages.isNotEmpty)
            const SizedBox(height: 12),
          if (frontVehicleImages.isNotEmpty)
            _photoSection(
              title: _frontVehiclePhotosTitle,
              images: frontVehicleImages,
            ),
          if (fallbackOnlyImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _photoSection(
              title: _photosTitle,
              images: fallbackOnlyImages,
            ),
          ],
        ] else if (fallbackImages.isEmpty)
          Text(
            _noPhotosText,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          _photoSection(
            title: _photosTitle,
            images: fallbackImages,
          ),
      ],
    );
  }

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

    final canCancel = request.id.isNotEmpty && request.requestStatus != 'cancelled';

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
                      _statusCard(context),
                      const SizedBox(height: 16),
                      _row(l10n.service_type_service, serviceLabel()),
                      _row('Datum', dateLabel()),
                      _row('Uhrzeit', timeLabel()),
                      _row('Werkstatt', value('workshop_name')),
                      _row(
                          l10n.license_plate_label, request.licensePlate ?? ''),
                      _row('Name', request.customerName ?? ''),
                      _row('Telefon', request.customerPhone ?? ''),
                      _row('E-Mail', request.customerEmail ?? ''),
                      if (_damageTownValue().isNotEmpty)
                        _row('Ort', _damageTownValue()),
                      if (_damageDateValue().isNotEmpty)
                        _row('Schadentag', _damageDateLabel()),
                      if (_isHailDamageRequest &&
                          (request.hailDamageTime ?? '').trim().isNotEmpty)
                        _row('Schadenzeit', _hailDamageTimeLabel()),
                      _row('Status', _requestStatusLabel(request.requestStatus)),
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
                      if (_hasDamagePhotoSections) _photosSection(),
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
                  Navigator.of(this.context).pop('cancelled');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
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

class _GlassDamageImage extends StatelessWidget {
  const _GlassDamageImage({
    required this.source,
    required this.fit,
    required this.borderRadius,
    this.showLoadingIndicator = false,
  });

  final String source;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    final normalized = source.trim();
    String resolvedNetworkUrl(String value) {
      try {
        return Uri.parse(value).toString();
      } catch (_) {
        return value;
      }
    }

    Widget placeholder() => Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: Colors.black12,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined),
        );

    if (normalized.startsWith('http')) {
      final url = resolvedNetworkUrl(normalized);
      return Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          if (!showLoadingIndicator) return placeholder();
          return Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              color: Colors.black12,
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    if (normalized.startsWith('cache:')) {
      final cacheKey = normalized.substring('cache:'.length);
      return FutureBuilder<Uint8List?>(
        future: LocalImageCache.getImage(cacheKey),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return placeholder();
          return Image.memory(
            bytes,
            fit: fit,
          );
        },
      );
    }

    if (!kIsWeb && normalized.isNotEmpty) {
      return Image.file(
        File(normalized),
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }

    return placeholder();
  }
}
