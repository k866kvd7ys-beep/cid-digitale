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
  String get accidentDetailsLiabilityInstruction =>
      'Sélectionnez le conducteur considéré comme responsable.';

  @override
  String get accidentDetailsSignAndSendAction =>
      'Signer et envoyer automatiquement';

  @override
  String get accidentDetailsAutomaticEmailInfo =>
      'Après les deux signatures, le dossier est automatiquement envoyé par e-mail au conducteur A et au conducteur B.';

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
  String get damage_comprehensive => 'Dommage casco complète';

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
  String get customerIncidentLoading => 'Chargement des accidents…';

  @override
  String get customerIncidentLoadError =>
      'Impossible de charger les dossiers d’accident. Vérifiez votre connexion et réessayez.';

  @override
  String get customerIncidentRetry => 'Réessayer';

  @override
  String get customerIncidentEmpty => 'Aucun accident enregistré.';

  @override
  String get customerIncidentLocalDraft => 'Brouillon local';

  @override
  String get customerIncidentRefresh => 'Actualiser la liste';

  @override
  String get customerIncidentStatusLabel => 'Statut';

  @override
  String get customerIncidentStatusReleased => 'Validé';

  @override
  String get customerIncidentStatusWaitingApproval =>
      'En attente de validation';

  @override
  String customerIncidentResponsibleDriver(String driver) {
    return 'Conducteur considéré comme responsable : $driver';
  }

  @override
  String get supportTitle => 'Assistance CID Digitale';

  @override
  String get supportHomeDescription =>
      'Signalez un problème, posez une question ou envoyez-nous une suggestion.';

  @override
  String get supportHowCanWeHelp => 'Comment pouvons-nous vous aider ?';

  @override
  String get supportIntroDescription =>
      'Décrivez votre demande. Notre équipe vous répondra par e-mail.';

  @override
  String get supportRequestType => 'Type de demande';

  @override
  String get supportRequestProblem => 'Signaler un problème';

  @override
  String get supportRequestQuestion => 'Poser une question';

  @override
  String get supportRequestSuggestion => 'Envoyer une suggestion';

  @override
  String get supportSubject => 'Objet';

  @override
  String get supportDescription => 'Description';

  @override
  String get supportReplyEmail => 'E-mail de réponse';

  @override
  String get supportAttachmentsOptional => 'Pièces jointes facultatives';

  @override
  String get supportAttachmentRules =>
      'Maximum 3 images JPG, JPEG, PNG ou WEBP. Taille maximale : 5 Mo par image.';

  @override
  String get supportAttachScreenshot => 'Joindre une capture d’écran';

  @override
  String get supportTakePhoto => 'Prendre une photo';

  @override
  String get supportChooseGallery => 'Choisir dans la galerie';

  @override
  String get supportRemoveAttachment => 'Supprimer la pièce jointe';

  @override
  String get supportAttachmentLimit =>
      'Vous pouvez joindre au maximum 3 images.';

  @override
  String get supportAttachmentTooLarge => 'L’image dépasse la limite de 5 Mo.';

  @override
  String get supportAttachmentUnsupported =>
      'Format non pris en charge. Utilisez JPG, JPEG, PNG ou WEBP.';

  @override
  String get supportAttachmentReadError =>
      'Impossible de lire l’image. Réessayez.';

  @override
  String get supportSendRequest => 'Envoyer la demande';

  @override
  String get supportRetrySend => 'Réessayer l’envoi';

  @override
  String get supportRequestSent => 'Demande envoyée';

  @override
  String get supportThankYou =>
      'Merci. Nous avons reçu votre demande et vous répondrons par e-mail.';

  @override
  String get supportBackHome => 'Retour à l’accueil';

  @override
  String get supportSubmissionError =>
      'Impossible de terminer l’envoi. Vérifiez votre connexion et réessayez.';

  @override
  String get supportValidationRequired => 'Champ obligatoire.';

  @override
  String supportValidationMinimum(int count) {
    return 'Saisissez au moins $count caractères.';
  }

  @override
  String supportValidationMaximum(int count) {
    return 'Ne dépassez pas $count caractères.';
  }

  @override
  String get supportInvalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get my_requests_filter_all => 'Tous';

  @override
  String get my_requests_filter_service => 'Service';

  @override
  String get my_requests_filter_tires => 'Changement de pneus';

  @override
  String get my_requests_filter_damage => 'Dommage';

  @override
  String get service_type_service => 'Service';

  @override
  String get service_type_tires => 'Changement de pneus';

  @override
  String get service_type_damage => 'Dommage';

  @override
  String get request_history_load_error =>
      'Impossible de charger les données. Veuillez réessayer.';

  @override
  String get request_detail_title => 'Détails de la demande';

  @override
  String get request_detail_date => 'Date';

  @override
  String get request_detail_time => 'Heure';

  @override
  String get request_detail_workshop => 'Atelier';

  @override
  String get request_detail_notes => 'Notes';

  @override
  String get request_detail_last_updated => 'Dernière mise à jour';

  @override
  String get request_detail_appointment_date => 'Date du rendez-vous';

  @override
  String get request_detail_cancel_appointment => 'Annuler le rendez-vous';

  @override
  String get request_detail_cancel_title => 'Annuler le rendez-vous ?';

  @override
  String get request_detail_cancel_message =>
      'Voulez-vous vraiment annuler cette demande ?';

  @override
  String get request_detail_cancel_error =>
      'Impossible d’annuler le rendez-vous. Veuillez réessayer.';

  @override
  String get request_detail_photo_unavailable => 'Photo non disponible';

  @override
  String get request_status_pending => 'Demande envoyée';

  @override
  String get request_status_confirmed => 'Rendez-vous confirmé';

  @override
  String get request_status_in_progress => 'Véhicule en réparation';

  @override
  String get request_status_completed => 'Réparation terminée';

  @override
  String get request_status_cancelled => 'Rendez-vous annulé';

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
  String get driverPersonalQrProfileSourceNote =>
      'Ces données sont reprises automatiquement depuis votre profil Client.';

  @override
  String get driverPersonalQrProfileIncompleteMessage =>
      'Votre profil Client n’est pas encore complet. Ajoutez les informations manquantes afin que votre QR personnel contienne toutes les données client.';

  @override
  String get driverPersonalQrProfileMissingFieldsLabel =>
      'Informations manquantes';

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
      'Le véhicule sera définitivement supprimé de ton compte client.';

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

  @override
  String get preferredWorkshopTitle => 'Atelier préféré';

  @override
  String get preferredWorkshopNone => 'Aucun atelier préféré sélectionné.';

  @override
  String get preferredWorkshopChoose => 'Choisir un atelier';

  @override
  String get preferredWorkshopEdit => 'Modifier l’atelier';

  @override
  String get preferredWorkshopRemove => 'Supprimer';

  @override
  String get preferredWorkshopYours => 'Votre atelier préféré';

  @override
  String get preferredWorkshopUse => 'Utiliser cet atelier';

  @override
  String get preferredWorkshopSaved => 'Atelier préféré enregistré.';

  @override
  String get preferredWorkshopRemoved => 'Atelier préféré supprimé.';

  @override
  String get preferredWorkshopLoadError =>
      'Impossible de charger l’atelier préféré.';

  @override
  String get preferredWorkshopSaveError =>
      'Impossible d’enregistrer l’atelier préféré.';

  @override
  String get preferredWorkshopOpen => 'Ouvert';

  @override
  String get preferredWorkshopClosed => 'Fermé';

  @override
  String get preferredWorkshopStatusUnavailable => 'Statut indisponible';

  @override
  String get workshopServiceWheelRepairTitle => 'Réparation de jantes';

  @override
  String get workshopServiceWheelRepairDescription =>
      'Évaluation et remise en état professionnelle des jantes endommagées.';

  @override
  String get workshopServiceOtherTitle => 'Autre';

  @override
  String get workshopServiceOtherDescription =>
      'Décrivez manuellement le service souhaité.';

  @override
  String get wheelRepairIntro =>
      'Sélectionnez le type de jante et téléchargez des photos du dommage. L’atelier choisi pourra examiner les images avant le rendez-vous.';

  @override
  String get wheelRepairTypeLabel => 'Type de jante';

  @override
  String get wheelRepairTypeStandardPainted => 'Jante peinte standard';

  @override
  String get wheelRepairTypeDiamondCut => 'Jante Diamond Cut';

  @override
  String get wheelRepairTypeTwoTone => 'Jante bicolore';

  @override
  String get wheelRepairTypeSpecialFinish => 'Jante avec finition spéciale';

  @override
  String get wheelRepairTypeAssessmentRequired =>
      'Je ne sais pas, évaluation demandée';

  @override
  String get wheelRepairPhotosTitle => 'Photos de la jante';

  @override
  String get wheelRepairPhotosInfo =>
      'Téléchargez au moins une photo complète de la jante et une photo rapprochée du dommage.';

  @override
  String get wheelRepairPhotoFull => 'Photo complète de la jante';

  @override
  String get wheelRepairPhotoCloseUp => 'Photo rapprochée du dommage';

  @override
  String get wheelRepairPhotoSecondAngle => 'Deuxième angle';

  @override
  String get wheelRepairPhotoAdditional => 'Photo supplémentaire facultative';

  @override
  String get wheelRepairRecommended => 'Recommandée';

  @override
  String get wheelRepairOptional => 'Facultative';

  @override
  String get wheelRepairAddPhoto => 'Ajouter une photo';

  @override
  String get wheelRepairTakePhoto => 'Prendre une photo';

  @override
  String get wheelRepairChoosePhoto => 'Choisir dans la galerie';

  @override
  String get wheelRepairViewPhoto => 'Afficher la photo';

  @override
  String get wheelRepairRemovePhoto => 'Supprimer la photo';

  @override
  String get wheelRepairPhotoLimit =>
      'Vous pouvez télécharger au maximum 6 photos.';

  @override
  String get wheelRepairUnsupportedPhoto =>
      'Ce format d’image n’est pas pris en charge.';

  @override
  String get wheelRepairPhotoError =>
      'Impossible d’ajouter la photo. Veuillez réessayer.';

  @override
  String get wheelRepairDamageDescriptionLabel =>
      'Décrivez brièvement le dommage';

  @override
  String get continueToWorkshopSelection =>
      'Continuer vers le choix de l’atelier';

  @override
  String get otherServiceQuestion => 'Quel service souhaitez-vous ?';

  @override
  String get otherServicePlaceholder =>
      'Décrivez brièvement le service demandé…';

  @override
  String get otherServiceRequired =>
      'Décrivez le service souhaité pour continuer.';
}
