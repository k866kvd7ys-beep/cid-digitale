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
  String get raeder_wechsel => 'Tire Change';

  @override
  String get raeder_wechsel_title => 'Tire Change';

  @override
  String get raeder_wechsel_sommer => 'Summer Tire Change';

  @override
  String get raeder_wechsel_winter => 'Winter Tire Change';

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
  String get damage_comprehensive => 'Vollkasko';

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
  String get my_requests_filter_tires => 'Tire Change';

  @override
  String get my_requests_filter_damage => 'Damage';

  @override
  String get service_type_service => 'Service appointment';

  @override
  String get service_type_tires => 'Tire Change';

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

  @override
  String get driverPersonalQrPageTitle => 'My personal QR';

  @override
  String get driverPersonalQrIntroTitle => 'Create your driver QR';

  @override
  String get driverPersonalQrIntroBody =>
      'Save customer, vehicle and insurance details in a personal QR ready to be scanned from New claim at the workshop.';

  @override
  String get driverPersonalQrLocalSaveNote =>
      'Data is stored locally on this device/browser.';

  @override
  String get driverPersonalQrPrivacyNote =>
      'The QR contains only customer, vehicle and insurance data.';

  @override
  String get driverPersonalQrStatusReady => 'QR ready / data saved';

  @override
  String get driverPersonalQrStatusReadyMessage =>
      'The QR is up to date and ready to be scanned by the workshop.';

  @override
  String get driverPersonalQrStatusNeedsUpdate => 'Data changed / update QR';

  @override
  String get driverPersonalQrStatusNeedsUpdateMessage =>
      'Your saved data changed. Update the QR to encode the latest version.';

  @override
  String get driverPersonalQrStatusDraftSaved => 'Data saved locally';

  @override
  String get driverPersonalQrStatusDraftSavedMessage =>
      'The data is already saved on this device. Create the QR when you want it to be scannable.';

  @override
  String get driverPersonalQrStatusEmpty => 'No saved data yet';

  @override
  String get driverPersonalQrStatusEmptyMessage =>
      'Fill in customer, vehicle and insurance details to prepare your personal QR.';

  @override
  String get driverPersonalQrCustomerSectionTitle => 'Customer data';

  @override
  String get driverPersonalQrCustomerSectionSubtitle =>
      'Enter the customer or driver details that the workshop should retrieve immediately.';

  @override
  String get driverPersonalQrProfileSourceNote =>
      'These details are automatically taken from your Customer profile.';

  @override
  String get driverPersonalQrProfileIncompleteMessage =>
      'Your Customer profile is not complete yet. Add the missing details so your personal QR contains all customer data.';

  @override
  String get driverPersonalQrProfileMissingFieldsLabel => 'Missing details';

  @override
  String get driverPersonalQrVehicleSectionTitle => 'Vehicle data';

  @override
  String get driverPersonalQrVehicleSectionSubtitle =>
      'Add the essential vehicle details to speed up claim creation.';

  @override
  String get driverPersonalQrInsuranceSectionTitle => 'Insurance data';

  @override
  String get driverPersonalQrInsuranceSectionSubtitle =>
      'Complete the insurance references useful for handling the claim.';

  @override
  String get driverPersonalQrFormActionCreate => 'Create personal QR';

  @override
  String get driverPersonalQrFormActionUpdate => 'Update QR';

  @override
  String get driverPersonalQrEditSavedData => 'Edit saved data';

  @override
  String get driverPersonalQrQrCardTitle => 'Personal driver QR';

  @override
  String get driverPersonalQrQrCardSubtitle =>
      'Show this QR to the workshop to auto-fill the available data.';

  @override
  String get driverPersonalQrQrEmptyTitle => 'QR not created yet';

  @override
  String get driverPersonalQrTapToEnlarge => 'Tap to enlarge';

  @override
  String get driverPersonalQrFullscreenHint => 'Show this QR to the workshop';

  @override
  String get driverPersonalQrCloseFullscreen => 'Close';

  @override
  String get driverPersonalQrMinimumHint =>
      'Fill at least first name, last name and plate to create the QR.';

  @override
  String get driverPersonalQrCreateSuccess => 'QR created successfully';

  @override
  String get driverPersonalQrUpdateSuccess => 'QR updated successfully';

  @override
  String get driverPersonalQrSaveError =>
      'Unable to save the personal QR locally.';

  @override
  String get driverPersonalQrDeleteProfileAction => 'Delete profile';

  @override
  String get driverPersonalQrDeleteProfileTitle => 'Delete profile?';

  @override
  String get driverPersonalQrDeleteProfileMessage =>
      'The saved personal data and personal QR will be deleted from this device.';

  @override
  String get driverPersonalQrDeleteProfileConfirm => 'Delete';

  @override
  String get driverPersonalQrDeleteProfileSuccess => 'Personal profile deleted';

  @override
  String get driverPersonalQrDeleteProfileError =>
      'Unable to delete the personal profile.';

  @override
  String get personalVehiclesTitle => 'My vehicles';

  @override
  String get personalVehicleAdd => 'Add vehicle';

  @override
  String get personalVehicleEdit => 'Edit vehicle';

  @override
  String get personalVehicleSave => 'Save vehicle';

  @override
  String get personalVehicleDelete => 'Delete vehicle';

  @override
  String get personalVehicleDeleteConfirm => 'Delete this vehicle?';

  @override
  String get personalVehicleDeleteMessage =>
      'The vehicle will be permanently removed from your customer account.';

  @override
  String get personalVehiclePrimary => 'Primary vehicle';

  @override
  String get personalVehicleSetPrimary => 'Set as primary';

  @override
  String get personalVehicleSelect => 'Select vehicle';

  @override
  String get personalVehicleContinueWithSelection =>
      'Continue with this vehicle';

  @override
  String get personalVehiclesEmpty => 'No saved vehicles';

  @override
  String get personalVehicleSaved => 'Vehicle saved';

  @override
  String get personalVehicleDeleted => 'Vehicle deleted';

  @override
  String get personalVehiclePlateRequired => 'Enter the vehicle license plate.';

  @override
  String get personalVehicleSaveError => 'Unable to save the vehicle.';

  @override
  String get personalVehicleDeleteError => 'Unable to delete the vehicle.';

  @override
  String get driverPersonalQrSavedDataPreviewTitle => 'Saved data preview';

  @override
  String get driverPersonalQrJsonPreviewTitle => 'QR content (JSON)';

  @override
  String get driverPersonalQrJsonPreviewHint =>
      'This is the readable JSON encoded inside the QR and compatible with the workshop scanner.';

  @override
  String get driverPersonalQrTechnicalDetailsTitle =>
      'Technical details (JSON)';

  @override
  String get driverPersonalQrTechnicalDetailsDescription =>
      'Technical details used by the workshop scanner.\nNormally there is no need to view them.';

  @override
  String get driverPersonalQrTitleLabel => 'Salutation / Title';

  @override
  String get driverPersonalQrStreetLabel => 'Street';

  @override
  String get driverPersonalQrCountryLabel => 'Country';

  @override
  String get driverPersonalQrBrandLabel => 'Brand';

  @override
  String get driverPersonalQrModelLabel => 'Model / Type';

  @override
  String get driverPersonalQrVinLabel => 'VIN';

  @override
  String get driverPersonalQrMileageLabel => 'Mileage';

  @override
  String get driverPersonalQrFirstRegistrationLabel => '1st registration';

  @override
  String get driverPersonalQrInsuranceLabel => 'Insurance';

  @override
  String get driverPersonalQrPolicyNumberLabel => 'Policy number';

  @override
  String get driverPersonalQrClaimNumberLabel => 'Claim number';

  @override
  String get driverPersonalQrLocationLabel => 'ZIP / City / Country';

  @override
  String get driverPersonalQrTitleMr => 'Mr.';

  @override
  String get driverPersonalQrTitleMrs => 'Mrs.';

  @override
  String get driverPersonalQrTitleCompany => 'Company';

  @override
  String get driverPersonalQrUseAsCustomerDriver => 'Use as customer/driver';

  @override
  String get driverPersonalQrUseAsWitness => 'Use as witness';

  @override
  String get driverPersonalQrUseAsInjured => 'Use as injured person';
}
