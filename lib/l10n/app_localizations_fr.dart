// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'CID Digitale';

  @override
  String get faultLiabilityHintA =>
      'Selon vous, le conducteur A est responsable.';

  @override
  String get faultLiabilityHintB =>
      'Selon vous, le conducteur B est responsable.';

  @override
  String get integrityNotVerifiedWarning =>
      'Attention : intégrité non vérifiée (données ou pièces jointes peuvent avoir été modifiées).';

  @override
  String get labelDateTime => 'Date et heure :';

  @override
  String get labelPlace => 'Lieu :';

  @override
  String get labelDriverA => 'Conducteur A';

  @override
  String get labelDriverB => 'Conducteur B';

  @override
  String get labelDriverAText => 'Conducteur A (texte) :';

  @override
  String get labelDriverBText => 'Conducteur B (texte) :';

  @override
  String get labelDriverAVoice => 'Note vocale conducteur A';

  @override
  String get labelDriverBVoice => 'Note vocale conducteur B';

  @override
  String get labelDriverAColon => 'Conducteur A :';

  @override
  String get labelDriverBColon => 'Conducteur B :';

  @override
  String get driverA => 'Conducteur A';

  @override
  String get driverB => 'Conducteur B';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get zip => 'Code postal';

  @override
  String get city => 'Ville';

  @override
  String get service_anmelden => 'Prendre rendez-vous service';

  @override
  String get raeder_wechsel => 'Changement de pneus';

  @override
  String get raeder_wechsel_title => 'Changement de pneus';

  @override
  String get raeder_wechsel_sommer => 'Changement de pneus été';

  @override
  String get raeder_wechsel_winter => 'Changement de pneus hiver';

  @override
  String get pick_slot => 'Choisir un créneau';

  @override
  String get slot_taken => 'Ce créneau est déjà pris.';

  @override
  String get slot_ok => 'Rendez-vous confirmé!';

  @override
  String get customer_name => 'Nom et prénom';

  @override
  String get customer_phone => 'Téléphone';

  @override
  String get customer_email => 'E-mail';

  @override
  String get enter_name => 'Entrez votre nom';

  @override
  String get cancel => 'Annuler';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get damage_type_title => 'De quel type de dommage s’agit-il ?';

  @override
  String get damage_type_subtitle => 'Sélectionnez le type de dommage.';

  @override
  String get damage_glass => 'Bris de glace';

  @override
  String get damage_hail => 'Dommage grêle';

  @override
  String get damage_marten => 'Dommage fouine';

  @override
  String get damage_parking => 'Dommage parking';

  @override
  String get damage_comprehensive => 'Vollkasko';

  @override
  String get license_plate_label => 'Plaque';

  @override
  String get license_plate_hint => 'Ex. AB-123-CD';

  @override
  String get other_object_damage_q =>
      'Y a-t-il des dégâts matériels sur d’autres objets ?';

  @override
  String get other_vehicle_damage_q =>
      'Y a-t-il des dégâts matériels sur d’autres véhicules ?';

  @override
  String get workshop_services_title => 'Services Atelier';

  @override
  String get termin_buchen => 'Réserver un rendez-vous';

  @override
  String get quick_actions_title => 'Actions rapides';

  @override
  String get my_requests_title => 'Mes demandes';

  @override
  String get tab_appointments => 'Rendez-vous';

  @override
  String get tab_incidents => 'Accidents';

  @override
  String get empty_appointments => 'Aucun rendez-vous';

  @override
  String get my_requests_filter_all => 'Tous';

  @override
  String get my_requests_filter_service => 'Service';

  @override
  String get my_requests_filter_tires => 'Changement de pneus';

  @override
  String get my_requests_filter_damage => 'Dommage';

  @override
  String get service_type_service => 'Service anmelden';

  @override
  String get service_type_tires => 'Changement de pneus';

  @override
  String get service_type_damage => 'Schaden';

  @override
  String get damageTitle => 'Dommages';

  @override
  String get damageVehicleA => 'Dommages du véhicule A';

  @override
  String get damageVehicleB => 'Dommages du véhicule B';

  @override
  String get pdfDriverA => 'Conducteur A';

  @override
  String get pdfDriverB => 'Conducteur B';

  @override
  String get pdfLiabilityHeading =>
      'Responsabilité (déclarée par les parties) :';

  @override
  String pdfLiabilityAccordingToParties(Object driver) {
    return 'Selon les parties, le conducteur responsable est $driver.';
  }

  @override
  String get pdfDriverLabelA => 'Conducteur A';

  @override
  String get pdfDriverLabelB => 'Conducteur B';

  @override
  String get driverPersonalQrPageTitle => 'Mon QR personnel';

  @override
  String get driverPersonalQrIntroTitle => 'Crée ton QR conducteur';

  @override
  String get driverPersonalQrIntroBody =>
      'Enregistre les données client, véhicule et assurance dans un QR personnel prêt à être scanné depuis Nouvelle demande à l’atelier.';

  @override
  String get driverPersonalQrLocalSaveNote =>
      'Les données sont enregistrées localement sur cet appareil/navigateur.';

  @override
  String get driverPersonalQrPrivacyNote =>
      'Le QR contient uniquement les données client, véhicule et assurance.';

  @override
  String get driverPersonalQrStatusReady =>
      'QR déjà prêt / données enregistrées';

  @override
  String get driverPersonalQrStatusReadyMessage =>
      'Le QR est à jour et prêt à être scanné par l’atelier.';

  @override
  String get driverPersonalQrStatusNeedsUpdate =>
      'Données modifiées / mettre à jour le QR';

  @override
  String get driverPersonalQrStatusNeedsUpdateMessage =>
      'Les données enregistrées ont changé. Mets à jour le QR pour encoder la dernière version.';

  @override
  String get driverPersonalQrStatusDraftSaved =>
      'Données enregistrées localement';

  @override
  String get driverPersonalQrStatusDraftSavedMessage =>
      'Les données sont déjà présentes sur cet appareil. Crée le QR quand tu veux les rendre scannables.';

  @override
  String get driverPersonalQrStatusEmpty => 'Aucune donnée enregistrée';

  @override
  String get driverPersonalQrStatusEmptyMessage =>
      'Renseigne les données client, véhicule et assurance pour préparer ton QR personnel.';

  @override
  String get driverPersonalQrCustomerSectionTitle => 'Données client';

  @override
  String get driverPersonalQrCustomerSectionSubtitle =>
      'Renseigne les données du client ou du conducteur pour que l’atelier les retrouve immédiatement.';

  @override
  String get driverPersonalQrVehicleSectionTitle => 'Données véhicule';

  @override
  String get driverPersonalQrVehicleSectionSubtitle =>
      'Ajoute les informations essentielles du véhicule pour accélérer l’ouverture du dossier.';

  @override
  String get driverPersonalQrInsuranceSectionTitle => 'Données assurance';

  @override
  String get driverPersonalQrInsuranceSectionSubtitle =>
      'Complète les références assurance utiles pour le traitement du dossier.';

  @override
  String get driverPersonalQrFormActionCreate => 'Créer le QR personnel';

  @override
  String get driverPersonalQrFormActionUpdate => 'Mettre à jour le QR';

  @override
  String get driverPersonalQrEditSavedData =>
      'Modifier les données enregistrées';

  @override
  String get driverPersonalQrQrCardTitle => 'QR personnel conducteur';

  @override
  String get driverPersonalQrQrCardSubtitle =>
      'Présente ce QR à l’atelier pour remplir automatiquement les données disponibles.';

  @override
  String get driverPersonalQrQrEmptyTitle => 'QR pas encore créé';

  @override
  String get driverPersonalQrTapToEnlarge => 'Touchez pour agrandir';

  @override
  String get driverPersonalQrFullscreenHint => 'Montrez ce QR à l’atelier';

  @override
  String get driverPersonalQrCloseFullscreen => 'Fermer';

  @override
  String get driverPersonalQrMinimumHint =>
      'Remplis au minimum prénom, nom et plaque pour créer le QR.';

  @override
  String get driverPersonalQrCreateSuccess => 'QR créé avec succès';

  @override
  String get driverPersonalQrUpdateSuccess => 'QR mis à jour avec succès';

  @override
  String get driverPersonalQrSaveError =>
      'Impossible d’enregistrer localement le QR personnel.';

  @override
  String get driverPersonalQrDeleteProfileAction => 'Supprimer le profil';

  @override
  String get driverPersonalQrDeleteProfileTitle => 'Supprimer le profil ?';

  @override
  String get driverPersonalQrDeleteProfileMessage =>
      'Les données personnelles enregistrées et le QR personnel seront supprimés de cet appareil.';

  @override
  String get driverPersonalQrDeleteProfileConfirm => 'Supprimer';

  @override
  String get driverPersonalQrDeleteProfileSuccess =>
      'Profil personnel supprimé';

  @override
  String get driverPersonalQrDeleteProfileError =>
      'Impossible de supprimer le profil personnel.';

  @override
  String get personalVehiclesTitle => 'Mes véhicules';

  @override
  String get personalVehicleAdd => 'Ajouter un véhicule';

  @override
  String get personalVehicleEdit => 'Modifier le véhicule';

  @override
  String get personalVehicleSave => 'Enregistrer le véhicule';

  @override
  String get personalVehicleDelete => 'Supprimer le véhicule';

  @override
  String get personalVehicleDeleteConfirm => 'Supprimer ce véhicule ?';

  @override
  String get personalVehicleDeleteMessage =>
      'Le véhicule sera supprimé des données enregistrées sur cet appareil.';

  @override
  String get personalVehiclePrimary => 'Véhicule principal';

  @override
  String get personalVehicleSetPrimary => 'Définir comme principal';

  @override
  String get personalVehicleSelect => 'Sélectionner le véhicule';

  @override
  String get personalVehicleContinueWithSelection =>
      'Continuer avec ce véhicule';

  @override
  String get personalVehiclesEmpty => 'Aucun véhicule enregistré';

  @override
  String get personalVehicleSaved => 'Véhicule enregistré';

  @override
  String get personalVehicleDeleted => 'Véhicule supprimé';

  @override
  String get personalVehiclePlateRequired => 'Saisis la plaque du véhicule.';

  @override
  String get personalVehicleSaveError =>
      'Impossible d’enregistrer le véhicule.';

  @override
  String get personalVehicleDeleteError =>
      'Impossible de supprimer le véhicule.';

  @override
  String get driverPersonalQrSavedDataPreviewTitle =>
      'Aperçu des données enregistrées';

  @override
  String get driverPersonalQrJsonPreviewTitle => 'Contenu du QR (JSON)';

  @override
  String get driverPersonalQrJsonPreviewHint =>
      'Voici le JSON lisible encodé dans le QR et compatible avec le scanner atelier.';

  @override
  String get driverPersonalQrTechnicalDetailsTitle =>
      'Détails techniques (JSON)';

  @override
  String get driverPersonalQrTechnicalDetailsDescription =>
      'Détails techniques utilisés par le scanner de l’atelier.\nIl n’est normalement pas nécessaire de les afficher.';

  @override
  String get driverPersonalQrTitleLabel => 'Civilité / Titre';

  @override
  String get driverPersonalQrStreetLabel => 'Rue';

  @override
  String get driverPersonalQrCountryLabel => 'Pays';

  @override
  String get driverPersonalQrBrandLabel => 'Marque';

  @override
  String get driverPersonalQrModelLabel => 'Modèle / Type';

  @override
  String get driverPersonalQrVinLabel => 'VIN / châssis';

  @override
  String get driverPersonalQrMileageLabel => 'Kilométrage';

  @override
  String get driverPersonalQrFirstRegistrationLabel => '1re immatriculation';

  @override
  String get driverPersonalQrInsuranceLabel => 'Assurance';

  @override
  String get driverPersonalQrPolicyNumberLabel => 'Numéro de police';

  @override
  String get driverPersonalQrClaimNumberLabel => 'Numéro de sinistre';

  @override
  String get driverPersonalQrLocationLabel => 'Code postal / Ville / Pays';

  @override
  String get driverPersonalQrTitleMr => 'Monsieur';

  @override
  String get driverPersonalQrTitleMrs => 'Madame';

  @override
  String get driverPersonalQrTitleCompany => 'Société';

  @override
  String get driverPersonalQrUseAsCustomerDriver =>
      'Utiliser comme client/conducteur';

  @override
  String get driverPersonalQrUseAsWitness => 'Utiliser comme témoin';

  @override
  String get driverPersonalQrUseAsInjured => 'Utiliser comme blessé';
}
