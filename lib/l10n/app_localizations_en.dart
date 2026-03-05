// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA => 'In your opinion, driver A is at fault.';

  @override
  String get faultLiabilityHintB => 'In your opinion, driver B is at fault.';

  @override
  String get integrityNotVerifiedWarning =>
      'Warning: integrity not verified (data or attachments may have been changed).';

  @override
  String get labelDateTime => 'Date and time:';

  @override
  String get labelPlace => 'Place:';

  @override
  String get labelDriverA => 'Driver A';

  @override
  String get labelDriverB => 'Driver B';

  @override
  String get labelDriverAText => 'Driver A (text):';

  @override
  String get labelDriverBText => 'Driver B (text):';

  @override
  String get labelDriverAVoice => 'Driver A voice note';

  @override
  String get labelDriverBVoice => 'Driver B voice note';

  @override
  String get labelDriverAColon => 'Driver A:';

  @override
  String get labelDriverBColon => 'Driver B:';

  @override
  String get driverA => 'Driver A';

  @override
  String get driverB => 'Driver B';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get zip => 'ZIP';

  @override
  String get city => 'City';

  @override
  String get service_anmelden => 'Book service';

  @override
  String get raeder_wechsel => 'Wheel change';

  @override
  String get raeder_wechsel_title => 'Wheel change';

  @override
  String get raeder_wechsel_sommer => 'Summer wheel change';

  @override
  String get raeder_wechsel_winter => 'Winter wheel change';

  @override
  String get pick_slot => 'Pick appointment';

  @override
  String get slot_taken => 'This time slot is already taken.';

  @override
  String get slot_ok => 'Appointment booked!';

  @override
  String get customer_name => 'Full name';

  @override
  String get customer_phone => 'Phone';

  @override
  String get customer_email => 'Email';

  @override
  String get enter_name => 'Please enter your name';

  @override
  String get cancel => 'Cancel';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get damage_type_title => 'What type of damage is it?';

  @override
  String get damage_type_subtitle => 'Select the type of damage.';

  @override
  String get damage_glass => 'Glass damage';

  @override
  String get damage_hail => 'Hail damage';

  @override
  String get damage_marten => 'Marten damage';

  @override
  String get damage_parking => 'Parking damage';

  @override
  String get damage_comprehensive => 'Comprehensive';

  @override
  String get license_plate_label => 'License plate';

  @override
  String get license_plate_hint => 'e.g. ZH 123456';

  @override
  String get other_object_damage_q =>
      'Is there property damage to other objects?';

  @override
  String get other_vehicle_damage_q =>
      'Is there property damage to other vehicles?';

  @override
  String get workshop_services_title => 'Workshop Services';

  @override
  String get termin_buchen => 'Book appointment';

  @override
  String get quick_actions_title => 'Quick actions';

  @override
  String get my_requests_title => 'My requests';

  @override
  String get tab_appointments => 'Appointments';

  @override
  String get tab_incidents => 'Accidents';

  @override
  String get empty_appointments => 'No appointments yet';

  @override
  String get my_requests_filter_all => 'All';

  @override
  String get my_requests_filter_service => 'Service';

  @override
  String get my_requests_filter_tires => 'Tires';

  @override
  String get my_requests_filter_damage => 'Damage';

  @override
  String get service_type_service => 'Service appointment';

  @override
  String get service_type_tires => 'Tire change';

  @override
  String get service_type_damage => 'Damage assessment';

  @override
  String get damageTitle => 'Damage';

  @override
  String get damageVehicleA => 'Damage to vehicle A';

  @override
  String get damageVehicleB => 'Damage to vehicle B';

  @override
  String get pdfDriverA => 'Driver A';

  @override
  String get pdfDriverB => 'Driver B';

  @override
  String get pdfLiabilityHeading => 'Liability (as stated by the parties):';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'According to the parties, the liable driver is $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Driver A';

  @override
  String get pdfDriverLabelB => 'Driver B';
}
