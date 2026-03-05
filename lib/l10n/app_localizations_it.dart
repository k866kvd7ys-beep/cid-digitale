// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA => 'Secondo voi è colpevole il conducente A.';

  @override
  String get faultLiabilityHintB => 'Secondo voi è colpevole il conducente B.';

  @override
  String get integrityNotVerifiedWarning =>
      'Attenzione: integrità non verificata (dati o allegati potrebbero essere cambiati).';

  @override
  String get labelDateTime => 'Data e ora:';

  @override
  String get labelPlace => 'Luogo:';

  @override
  String get labelDriverA => 'Conducente A';

  @override
  String get labelDriverB => 'Conducente B';

  @override
  String get labelDriverAText => 'Conducente A (testo):';

  @override
  String get labelDriverBText => 'Conducente B (testo):';

  @override
  String get labelDriverAVoice => 'Sprachnotiz Conducente A';

  @override
  String get labelDriverBVoice => 'Sprachnotiz Conducente B';

  @override
  String get labelDriverAColon => 'Conducente A:';

  @override
  String get labelDriverBColon => 'Conducente B:';

  @override
  String get driverA => 'Conducente A';

  @override
  String get driverB => 'Conducente B';

  @override
  String get firstName => 'Nome';

  @override
  String get lastName => 'Cognome';

  @override
  String get zip => 'CAP';

  @override
  String get city => 'Città';

  @override
  String get service_anmelden => 'Prenota servizio';

  @override
  String get raeder_wechsel => 'Cambio gomme';

  @override
  String get raeder_wechsel_title => 'Cambio gomme';

  @override
  String get raeder_wechsel_sommer => 'Cambio gomme estive';

  @override
  String get raeder_wechsel_winter => 'Cambio gomme invernali';

  @override
  String get pick_slot => 'Scegli appuntamento';

  @override
  String get slot_taken => 'Questo orario è già occupato.';

  @override
  String get slot_ok => 'Appuntamento prenotato!';

  @override
  String get customer_name => 'Nome e Cognome';

  @override
  String get customer_phone => 'Telefono';

  @override
  String get customer_email => 'E-mail';

  @override
  String get enter_name => 'Inserisci il tuo nome';

  @override
  String get cancel => 'Annulla';

  @override
  String get yes => 'Sì';

  @override
  String get no => 'No';

  @override
  String get damage_type_title => 'Di che tipo di danno si tratta?';

  @override
  String get damage_type_subtitle => 'Seleziona la tipologia di danno.';

  @override
  String get damage_glass => 'Danno vetri';

  @override
  String get damage_hail => 'Danno da grandine';

  @override
  String get damage_marten => 'Danno da martora';

  @override
  String get damage_parking => 'Danno da parcheggio';

  @override
  String get damage_comprehensive => 'Kasko completa';

  @override
  String get license_plate_label => 'Targa';

  @override
  String get license_plate_hint => 'Es. AB 123 CD';

  @override
  String get other_object_damage_q => 'Ci sono danni a oggetti di terzi?';

  @override
  String get other_vehicle_damage_q => 'Ci sono danni ad altri veicoli?';

  @override
  String get workshop_services_title => 'Servizi Officina';

  @override
  String get termin_buchen => 'Prenota appuntamento';

  @override
  String get quick_actions_title => 'Azioni rapide';

  @override
  String get my_requests_title => 'Le mie richieste';

  @override
  String get tab_appointments => 'Appuntamenti';

  @override
  String get tab_incidents => 'Incidenti';

  @override
  String get empty_appointments => 'Nessun appuntamento';

  @override
  String get my_requests_filter_all => 'Tutti';

  @override
  String get my_requests_filter_service => 'Service';

  @override
  String get my_requests_filter_tires => 'Cambio ruote';

  @override
  String get my_requests_filter_damage => 'Danno';

  @override
  String get service_type_service => 'Service anmelden';

  @override
  String get service_type_tires => 'Räder wechsel';

  @override
  String get service_type_damage => 'Schaden';

  @override
  String get damageTitle => 'Danni';

  @override
  String get damageVehicleA => 'Danni del veicolo A';

  @override
  String get damageVehicleB => 'Danni del veicolo B';

  @override
  String get pdfDriverA => 'Conducente A';

  @override
  String get pdfDriverB => 'Conducente B';

  @override
  String get pdfLiabilityHeading => 'Responsabilità (Angabe der Parteien):';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'Secondo le parti il conducente ritenuto colpevole è $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Conducente A';

  @override
  String get pdfDriverLabelB => 'Conducente B';
}
