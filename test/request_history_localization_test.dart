import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:cid_digitale/l10n/app_localizations_de.dart';
import 'package:cid_digitale/l10n/app_localizations_en.dart';
import 'package:cid_digitale/l10n/app_localizations_fr.dart';
import 'package:cid_digitale/l10n/app_localizations_it.dart';
import 'package:cid_digitale/models/appointment_request.dart';
import 'package:cid_digitale/screens/my_requests_page.dart';
import 'package:cid_digitale/screens/request_detail_screen.dart';
import 'package:cid_digitale/services/appointment_requests_service.dart';
import 'package:cid_digitale/utils/service_booking_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppointmentRequestsService implements AppointmentRequestsService {
  _FakeAppointmentRequestsService({
    this.items = const [],
    this.loadError,
    this.cancelError,
  });

  final List<AppointmentRequest> items;
  final Object? loadError;
  final Object? cancelError;

  @override
  Future<List<AppointmentRequest>> fetchMyRequests({
    String? email,
    String? phone,
    String? licensePlate,
    String? serviceFilter,
  }) async {
    if (loadError != null) throw loadError!;
    return items;
  }

  @override
  Future<AppointmentRequest?> fetchRequestById(String id) async => null;

  @override
  Future<void> cancelRequest(String id) async {
    if (cancelError != null) throw cancelError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExpectedCopy {
  const _ExpectedCopy({
    required this.historyTitle,
    required this.serviceType,
    required this.serviceName,
    required this.detailTitle,
    required this.date,
    required this.time,
    required this.workshop,
    required this.notes,
    required this.status,
    required this.cancel,
    required this.cancelTitle,
    required this.cancelMessage,
    required this.yes,
    required this.no,
    required this.loadError,
    required this.cancelError,
    required this.photoUnavailable,
    required this.forbidden,
  });

  final String historyTitle;
  final String serviceType;
  final String serviceName;
  final String detailTitle;
  final String date;
  final String time;
  final String workshop;
  final String notes;
  final String status;
  final String cancel;
  final String cancelTitle;
  final String cancelMessage;
  final String yes;
  final String no;
  final String loadError;
  final String cancelError;
  final String photoUnavailable;
  final List<String> forbidden;
}

const _copies = <String, _ExpectedCopy>{
  'de': _ExpectedCopy(
    historyTitle: 'Meine Anfragen',
    serviceType: 'Service',
    serviceName: 'Wartung und Reparatur',
    detailTitle: 'Anfragedetails',
    date: 'Datum',
    time: 'Uhrzeit',
    workshop: 'Werkstatt',
    notes: 'Notizen',
    status: 'Anfrage gesendet',
    cancel: 'Termin stornieren',
    cancelTitle: 'Termin stornieren?',
    cancelMessage: 'Möchten Sie diese Anfrage wirklich stornieren?',
    yes: 'Ja',
    no: 'Nein',
    loadError:
        'Die Daten konnten nicht geladen werden. Bitte versuchen Sie es erneut.',
    cancelError:
        'Der Termin konnte nicht storniert werden. Bitte versuchen Sie es erneut.',
    photoUnavailable: 'Foto nicht verfügbar',
    forbidden: [
      'Dettagli richiesta',
      'Détails de la demande',
      'Request details'
    ],
  ),
  'it': _ExpectedCopy(
    historyTitle: 'Le mie richieste',
    serviceType: 'Servizio',
    serviceName: 'Manutenzione e riparazione',
    detailTitle: 'Dettagli richiesta',
    date: 'Data',
    time: 'Ora',
    workshop: 'Officina',
    notes: 'Note',
    status: 'Richiesta inviata',
    cancel: 'Annulla appuntamento',
    cancelTitle: 'Annullare l’appuntamento?',
    cancelMessage: 'Desideri davvero annullare questa richiesta?',
    yes: 'Sì',
    no: 'No',
    loadError: 'Impossibile caricare i dati. Riprova.',
    cancelError: 'Impossibile annullare l’appuntamento. Riprova.',
    photoUnavailable: 'Foto non disponibile',
    forbidden: ['Anfrage Details', 'Datum', 'Uhrzeit', 'Termin stornieren'],
  ),
  'fr': _ExpectedCopy(
    historyTitle: 'Mes demandes',
    serviceType: 'Service',
    serviceName: 'Entretien et réparation',
    detailTitle: 'Détails de la demande',
    date: 'Date',
    time: 'Heure',
    workshop: 'Atelier',
    notes: 'Notes',
    status: 'Demande envoyée',
    cancel: 'Annuler le rendez-vous',
    cancelTitle: 'Annuler le rendez-vous ?',
    cancelMessage: 'Voulez-vous vraiment annuler cette demande ?',
    yes: 'Oui',
    no: 'Non',
    loadError: 'Impossible de charger les données. Veuillez réessayer.',
    cancelError: 'Impossible d’annuler le rendez-vous. Veuillez réessayer.',
    photoUnavailable: 'Photo non disponible',
    forbidden: [
      'Anfrage Details',
      'Datum',
      'Uhrzeit',
      'Termin stornieren',
      'Foto non disponibile',
    ],
  ),
  'en': _ExpectedCopy(
    historyTitle: 'My requests',
    serviceType: 'Service',
    serviceName: 'Maintenance and repair',
    detailTitle: 'Request details',
    date: 'Date',
    time: 'Time',
    workshop: 'Workshop',
    notes: 'Notes',
    status: 'Request sent',
    cancel: 'Cancel appointment',
    cancelTitle: 'Cancel appointment?',
    cancelMessage: 'Are you sure you want to cancel this request?',
    yes: 'Yes',
    no: 'No',
    loadError: 'Unable to load the data. Please try again.',
    cancelError: 'Unable to cancel the appointment. Please try again.',
    photoUnavailable: 'Photo unavailable',
    forbidden: [
      'Anfrage Details',
      'Datum',
      'Uhrzeit',
      'Termin stornieren',
      'Foto non disponibile',
    ],
  ),
};

final _localizations = <String, AppLocalizations>{
  'de': AppLocalizationsDe(),
  'it': AppLocalizationsIt(),
  'fr': AppLocalizationsFr(),
  'en': AppLocalizationsEn(),
};

AppointmentRequest _request({
  String serviceType = 'service_anmelden',
  String? damageType,
  List<String> glassDamageImages = const [],
}) {
  final timestamp = DateTime.utc(2026, 8, 31, 10);
  return AppointmentRequest(
    id: 'request-localization-test',
    createdAt: timestamp,
    updatedAt: timestamp,
    serviceType: serviceType,
    appointmentDate: DateTime(2026, 9, 4),
    appointmentTime: '09:30',
    durationMinutes: 60,
    customerName: 'Mario Rossi',
    customerPhone: '+41 79 000 00 00',
    customerEmail: 'mario@example.com',
    licensePlate: 'TI 12345',
    garageName: 'Garage Centrale',
    garageCity: 'Lugano',
    status: 'pending',
    requestStatus: 'pending',
    notes: 'Controllare il veicolo',
    locale: 'de',
    serviceSelectionKey:
        serviceType == 'service_anmelden' ? workshopServiceRepair : null,
    damageType: damageType,
    glassDamageImages: glassDamageImages,
  );
}

Widget _app({
  required Locale locale,
  required Widget home,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(useMaterial3: true),
    home: home,
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required String language,
  required Widget home,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    _app(locale: Locale(language), home: home),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  test('ARB copy is complete and natural in DE, IT, FR and EN', () {
    for (final entry in _copies.entries) {
      final l10n = _localizations[entry.key]!;
      final expected = entry.value;
      expect(l10n.my_requests_title, expected.historyTitle);
      expect(l10n.service_type_service, expected.serviceType);
      expect(l10n.request_detail_title, expected.detailTitle);
      expect(l10n.request_detail_date, expected.date);
      expect(l10n.request_detail_time, expected.time);
      expect(l10n.request_detail_workshop, expected.workshop);
      expect(l10n.request_detail_notes, expected.notes);
      expect(l10n.request_status_pending, expected.status);
      expect(l10n.request_detail_cancel_appointment, expected.cancel);
      expect(l10n.request_detail_cancel_title, expected.cancelTitle);
      expect(l10n.request_detail_cancel_message, expected.cancelMessage);
      expect(l10n.request_history_load_error, expected.loadError);
      expect(l10n.request_detail_cancel_error, expected.cancelError);
      expect(l10n.request_detail_photo_unavailable, expected.photoUnavailable);
    }
    expect(AppLocalizationsIt().service_type_damage, 'Danno');
    expect(AppLocalizationsFr().service_type_damage, 'Dommage');
    expect(AppLocalizationsEn().service_type_damage, 'Damage');
  });

  for (final entry in _copies.entries) {
    testWidgets('history uses ${entry.key} for saved German request',
        (tester) async {
      final expected = entry.value;
      await _pumpApp(
        tester,
        language: entry.key,
        home: MyRequestsPage(
          appointmentRequestsService: _FakeAppointmentRequestsService(
            items: [_request()],
          ),
        ),
      );

      expect(find.text(expected.historyTitle), findsOneWidget);
      expect(
        find.text('${expected.serviceType}: ${expected.serviceName}'),
        findsOneWidget,
      );
      for (final forbidden in expected.forbidden) {
        expect(find.text(forbidden), findsNothing);
      }
    });

    testWidgets('detail and cancel dialog use ${entry.key}', (tester) async {
      final expected = entry.value;
      await _pumpApp(
        tester,
        language: entry.key,
        home: RequestDetailScreen(
          request: _request(),
          appointmentRequestsService: _FakeAppointmentRequestsService(),
        ),
      );

      for (final text in [
        expected.detailTitle,
        expected.date,
        expected.time,
        expected.workshop,
        expected.notes,
        expected.cancel,
        expected.serviceName,
      ]) {
        expect(find.text(text), findsOneWidget, reason: '${entry.key}: $text');
      }
      expect(
        find.text(expected.status),
        findsWidgets,
        reason: '${entry.key}: ${expected.status}',
      );
      for (final forbidden in expected.forbidden) {
        expect(find.text(forbidden), findsNothing);
      }

      final cancelButton = find.text(expected.cancel);
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
      expect(find.text(expected.cancelTitle), findsOneWidget);
      expect(find.text(expected.cancelMessage), findsOneWidget);
      expect(find.text(expected.no), findsOneWidget);
      expect(find.text(expected.yes), findsOneWidget);
      await tester.tap(find.text(expected.no));
      await tester.pumpAndSettle();
    });

    testWidgets('history load error is sanitized in ${entry.key}',
        (tester) async {
      final expected = entry.value;
      await _pumpApp(
        tester,
        language: entry.key,
        home: MyRequestsPage(
          appointmentRequestsService: _FakeAppointmentRequestsService(
            loadError: StateError('RAW_SUPABASE_EXCEPTION'),
          ),
        ),
      );

      expect(find.text(expected.loadError), findsOneWidget);
      expect(find.textContaining('RAW_SUPABASE_EXCEPTION'), findsNothing);
    });

    testWidgets('missing photo uses ${entry.key} without exposing its URL',
        (tester) async {
      final expected = entry.value;
      await _pumpApp(
        tester,
        language: entry.key,
        home: RequestDetailScreen(
          request: _request(
            serviceType: 'damage_glass',
            damageType: 'damage_glass',
            glassDamageImages: const [
              'https://example.invalid/private-photo?token=secret',
            ],
          ),
          appointmentRequestsService: _FakeAppointmentRequestsService(),
        ),
      );

      final photo = find.byKey(const Key('request-photo-0'));
      await tester.ensureVisible(photo);
      await tester.tap(photo);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(expected.photoUnavailable), findsOneWidget);
      expect(find.textContaining('example.invalid'), findsNothing);
      expect(find.textContaining('token=secret'), findsNothing);
    });
  }

  testWidgets('cancel failure is localized and hides raw exception',
      (tester) async {
    final expected = _copies['it']!;
    await _pumpApp(
      tester,
      language: 'it',
      home: RequestDetailScreen(
        request: _request(),
        appointmentRequestsService: _FakeAppointmentRequestsService(
          cancelError: StateError('RAW_CANCEL_EXCEPTION'),
        ),
      ),
    );

    final cancelButton = find.text(expected.cancel);
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(expected.yes));
    await tester.pumpAndSettle();
    expect(find.text(expected.cancelError), findsOneWidget);
    expect(find.textContaining('RAW_CANCEL_EXCEPTION'), findsNothing);
  });
}
