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
  String get accidentDetailsLiabilityInstruction =>
      'Seleziona il conducente ritenuto responsabile.';

  @override
  String get accidentDetailsSignAndSendAction =>
      'Firma e invia automaticamente';

  @override
  String get accidentDetailsAutomaticEmailInfo =>
      'Dopo entrambe le firme, la pratica viene inviata automaticamente via e-mail al conducente A e al conducente B.';

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
  String get damage_parking => 'Danno parcheggio';

  @override
  String get damage_comprehensive => 'Danno casco totale';

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
  String get customerIncidentLoading => 'Caricamento incidenti…';

  @override
  String get customerIncidentLoadError =>
      'Impossibile caricare le pratiche incidente. Controlla la connessione e riprova.';

  @override
  String get customerIncidentRetry => 'Riprova';

  @override
  String get customerIncidentEmpty => 'Nessun incidente salvato.';

  @override
  String get customerIncidentLocalDraft => 'Bozza locale';

  @override
  String get customerIncidentRefresh => 'Aggiorna elenco';

  @override
  String get customerIncidentStatusLabel => 'Stato';

  @override
  String get customerIncidentStatusReleased => 'Approvata';

  @override
  String get customerIncidentStatusWaitingApproval =>
      'In attesa di approvazione';

  @override
  String customerIncidentResponsibleDriver(String driver) {
    return 'Conducente ritenuto responsabile: $driver';
  }

  @override
  String get supportTitle => 'Assistenza CID Digitale';

  @override
  String get supportHomeDescription =>
      'Segnala un problema, fai una domanda o inviaci un suggerimento.';

  @override
  String get supportHowCanWeHelp => 'Come possiamo aiutarti?';

  @override
  String get supportIntroDescription =>
      'Descrivi la tua richiesta e il nostro team ti risponderà tramite e-mail.';

  @override
  String get supportRequestType => 'Tipo di richiesta';

  @override
  String get supportRequestProblem => 'Segnala un problema';

  @override
  String get supportRequestQuestion => 'Fai una domanda';

  @override
  String get supportRequestSuggestion => 'Invia un suggerimento';

  @override
  String get supportSubject => 'Oggetto';

  @override
  String get supportDescription => 'Descrizione';

  @override
  String get supportReplyEmail => 'E-mail di risposta';

  @override
  String get supportAttachmentsOptional => 'Allegati facoltativi';

  @override
  String get supportAttachmentRules =>
      'Massimo 3 immagini JPG, JPEG, PNG o WEBP. Dimensione massima: 5 MB per immagine.';

  @override
  String get supportAttachScreenshot => 'Allega screenshot';

  @override
  String get supportTakePhoto => 'Scatta una fotografia';

  @override
  String get supportChooseGallery => 'Scegli dalla galleria';

  @override
  String get supportRemoveAttachment => 'Rimuovi allegato';

  @override
  String get supportAttachmentLimit => 'Puoi allegare al massimo 3 immagini.';

  @override
  String get supportAttachmentTooLarge =>
      'L’immagine supera il limite di 5 MB.';

  @override
  String get supportAttachmentUnsupported =>
      'Formato non supportato. Usa JPG, JPEG, PNG o WEBP.';

  @override
  String get supportAttachmentReadError =>
      'Non è stato possibile leggere l’immagine. Riprova.';

  @override
  String get supportSendRequest => 'Invia richiesta';

  @override
  String get supportRetrySend => 'Riprova invio';

  @override
  String get supportRequestSent => 'Richiesta inviata';

  @override
  String get supportThankYou =>
      'Grazie. Abbiamo ricevuto la tua richiesta e ti risponderemo tramite e-mail.';

  @override
  String get supportBackHome => 'Torna alla Home';

  @override
  String get supportSubmissionError =>
      'Non è stato possibile completare l’invio. Controlla la connessione e riprova.';

  @override
  String get supportValidationRequired => 'Campo obbligatorio.';

  @override
  String supportValidationMinimum(int count) {
    return 'Inserisci almeno $count caratteri.';
  }

  @override
  String supportValidationMaximum(int count) {
    return 'Non superare $count caratteri.';
  }

  @override
  String get supportInvalidEmail => 'Inserisci un indirizzo e-mail valido.';

  @override
  String get my_requests_filter_all => 'Tutti';

  @override
  String get my_requests_filter_service => 'Servizio';

  @override
  String get my_requests_filter_tires => 'Cambio gomme';

  @override
  String get my_requests_filter_damage => 'Danno';

  @override
  String get service_type_service => 'Servizio';

  @override
  String get service_type_tires => 'Cambio gomme';

  @override
  String get service_type_damage => 'Danno';

  @override
  String get request_history_load_error =>
      'Impossibile caricare i dati. Riprova.';

  @override
  String get request_detail_title => 'Dettagli richiesta';

  @override
  String get request_detail_date => 'Data';

  @override
  String get request_detail_time => 'Ora';

  @override
  String get request_detail_workshop => 'Officina';

  @override
  String get request_detail_notes => 'Note';

  @override
  String get request_detail_last_updated => 'Ultimo aggiornamento';

  @override
  String get request_detail_appointment_date => 'Data appuntamento';

  @override
  String get request_detail_cancel_appointment => 'Annulla appuntamento';

  @override
  String get request_detail_cancel_title => 'Annullare l’appuntamento?';

  @override
  String get request_detail_cancel_message =>
      'Desideri davvero annullare questa richiesta?';

  @override
  String get request_detail_cancel_error =>
      'Impossibile annullare l’appuntamento. Riprova.';

  @override
  String get request_detail_photo_unavailable => 'Foto non disponibile';

  @override
  String get request_status_pending => 'Richiesta inviata';

  @override
  String get request_status_confirmed => 'Appuntamento confermato';

  @override
  String get request_status_in_progress => 'Veicolo in lavorazione';

  @override
  String get request_status_completed => 'Riparazione completata';

  @override
  String get request_status_cancelled => 'Appuntamento annullato';

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

  @override
  String get driverPersonalQrPageTitle => 'Mio QR personale';

  @override
  String get driverPersonalQrIntroTitle => 'Crea il tuo QR conducente';

  @override
  String get driverPersonalQrIntroBody =>
      'Salva i tuoi dati cliente, veicolo e assicurazione in un QR personale pronto per la scansione da Nuova pratica in officina.';

  @override
  String get driverPersonalQrLocalSaveNote =>
      'I dati vengono salvati localmente su questo dispositivo/browser.';

  @override
  String get driverPersonalQrPrivacyNote =>
      'Il QR contiene solo dati cliente, veicolo e assicurazione.';

  @override
  String get driverPersonalQrStatusReady => 'QR già pronto / dati salvati';

  @override
  String get driverPersonalQrStatusReadyMessage =>
      'Il QR è aggiornato e pronto per essere scansionato dall’officina.';

  @override
  String get driverPersonalQrStatusNeedsUpdate =>
      'Dati modificati / aggiorna QR';

  @override
  String get driverPersonalQrStatusNeedsUpdateMessage =>
      'Hai modificato i dati salvati. Aggiorna il QR per includere l’ultima versione.';

  @override
  String get driverPersonalQrStatusDraftSaved => 'Dati salvati localmente';

  @override
  String get driverPersonalQrStatusDraftSavedMessage =>
      'I dati sono già presenti su questo dispositivo. Crea il QR quando vuoi renderli scansionabili.';

  @override
  String get driverPersonalQrStatusEmpty => 'Nessun dato salvato';

  @override
  String get driverPersonalQrStatusEmptyMessage =>
      'Compila i dati cliente, veicolo e assicurazione per preparare il tuo QR personale.';

  @override
  String get driverPersonalQrCustomerSectionTitle => 'Dati cliente';

  @override
  String get driverPersonalQrCustomerSectionSubtitle =>
      'Inserisci i dati del cliente o del conducente che l’officina dovrà ritrovare al primo colpo.';

  @override
  String get driverPersonalQrProfileSourceNote =>
      'Questi dati vengono acquisiti automaticamente dal tuo Profilo Cliente.';

  @override
  String get driverPersonalQrProfileIncompleteMessage =>
      'Il tuo Profilo Cliente non è ancora completo. Aggiungi i dati mancanti affinché il QR personale contenga tutti i dati cliente.';

  @override
  String get driverPersonalQrProfileMissingFieldsLabel => 'Dati mancanti';

  @override
  String get driverPersonalQrVehicleSectionTitle => 'Dati veicolo';

  @override
  String get driverPersonalQrVehicleSectionSubtitle =>
      'Aggiungi i dati essenziali del veicolo per velocizzare l’apertura della pratica.';

  @override
  String get driverPersonalQrInsuranceSectionTitle => 'Dati assicurazione';

  @override
  String get driverPersonalQrInsuranceSectionSubtitle =>
      'Completa i riferimenti assicurativi utili per la gestione della pratica.';

  @override
  String get driverPersonalQrFormActionCreate => 'Crea QR personale';

  @override
  String get driverPersonalQrFormActionUpdate => 'Aggiorna QR';

  @override
  String get driverPersonalQrEditSavedData => 'Modifica dati salvati';

  @override
  String get driverPersonalQrQrCardTitle => 'QR personale conducente';

  @override
  String get driverPersonalQrQrCardSubtitle =>
      'Mostra questo QR all’officina per compilare automaticamente i dati disponibili.';

  @override
  String get driverPersonalQrQrEmptyTitle => 'QR non ancora creato';

  @override
  String get driverPersonalQrTapToEnlarge => 'Tocca per ingrandire';

  @override
  String get driverPersonalQrFullscreenHint => 'Mostra questo QR all’officina';

  @override
  String get driverPersonalQrCloseFullscreen => 'Chiudi';

  @override
  String get driverPersonalQrMinimumHint =>
      'Compila almeno nome, cognome e targa per creare il QR.';

  @override
  String get driverPersonalQrCreateSuccess => 'QR creato correttamente';

  @override
  String get driverPersonalQrUpdateSuccess => 'QR aggiornato correttamente';

  @override
  String get driverPersonalQrSaveError =>
      'Impossibile salvare localmente il QR personale.';

  @override
  String get driverPersonalQrDeleteProfileAction => 'Elimina profilo';

  @override
  String get driverPersonalQrDeleteProfileTitle => 'Eliminare il profilo?';

  @override
  String get driverPersonalQrDeleteProfileMessage =>
      'I dati personali salvati e il QR personale verranno eliminati da questo dispositivo.';

  @override
  String get driverPersonalQrDeleteProfileConfirm => 'Elimina';

  @override
  String get driverPersonalQrDeleteProfileSuccess =>
      'Profilo personale eliminato';

  @override
  String get driverPersonalQrDeleteProfileError =>
      'Impossibile eliminare il profilo personale.';

  @override
  String get personalVehiclesTitle => 'I miei veicoli';

  @override
  String get personalVehicleAdd => 'Aggiungi veicolo';

  @override
  String get personalVehicleEdit => 'Modifica veicolo';

  @override
  String get personalVehicleSave => 'Salva veicolo';

  @override
  String get personalVehicleDelete => 'Elimina veicolo';

  @override
  String get personalVehicleDeleteConfirm => 'Eliminare questo veicolo?';

  @override
  String get personalVehicleDeleteMessage =>
      'Il veicolo verrà rimosso definitivamente dal tuo account Cliente.';

  @override
  String get personalVehiclePrimary => 'Veicolo principale';

  @override
  String get personalVehicleSetPrimary => 'Imposta come principale';

  @override
  String get personalVehicleSelect => 'Seleziona il veicolo';

  @override
  String get personalVehicleContinueWithSelection =>
      'Continua con questo veicolo';

  @override
  String get personalVehiclesEmpty => 'Nessun veicolo salvato';

  @override
  String get personalVehicleSaved => 'Veicolo salvato';

  @override
  String get personalVehicleDeleted => 'Veicolo eliminato';

  @override
  String get personalVehiclePlateRequired => 'Inserisci la targa del veicolo.';

  @override
  String get personalVehicleSaveError => 'Impossibile salvare il veicolo.';

  @override
  String get personalVehicleDeleteError => 'Impossibile eliminare il veicolo.';

  @override
  String get driverPersonalQrSavedDataPreviewTitle => 'Anteprima dati salvati';

  @override
  String get driverPersonalQrJsonPreviewTitle => 'Contenuto QR (JSON)';

  @override
  String get driverPersonalQrJsonPreviewHint =>
      'Questo è il JSON leggibile codificato nel QR e compatibile con lo scanner officina.';

  @override
  String get driverPersonalQrTechnicalDetailsTitle => 'Dettagli tecnici (JSON)';

  @override
  String get driverPersonalQrTechnicalDetailsDescription =>
      'Dettagli tecnici utilizzati dallo scanner dell\'officina.\nNormalmente non è necessario visualizzarli.';

  @override
  String get driverPersonalQrTitleLabel => 'Anrede / Titolo';

  @override
  String get driverPersonalQrStreetLabel => 'Via';

  @override
  String get driverPersonalQrCountryLabel => 'Paese';

  @override
  String get driverPersonalQrBrandLabel => 'Marca';

  @override
  String get driverPersonalQrModelLabel => 'Modello / Tipo';

  @override
  String get driverPersonalQrVinLabel => 'Telaio VIN';

  @override
  String get driverPersonalQrMileageLabel => 'Kilometraggio';

  @override
  String get driverPersonalQrFirstRegistrationLabel => '1ª immatricolazione';

  @override
  String get driverPersonalQrInsuranceLabel => 'Assicurazione';

  @override
  String get driverPersonalQrPolicyNumberLabel => 'Numero polizza';

  @override
  String get driverPersonalQrClaimNumberLabel => 'Numero sinistro';

  @override
  String get driverPersonalQrLocationLabel => 'CAP / Città / Paese';

  @override
  String get driverPersonalQrTitleMr => 'Signor';

  @override
  String get driverPersonalQrTitleMrs => 'Signora';

  @override
  String get driverPersonalQrTitleCompany => 'Ditta';

  @override
  String get driverPersonalQrUseAsCustomerDriver =>
      'Usa come cliente/conducente';

  @override
  String get driverPersonalQrUseAsWitness => 'Usa come testimone';

  @override
  String get driverPersonalQrUseAsInjured => 'Usa come ferito';

  @override
  String get preferredWorkshopTitle => 'Officina preferita';

  @override
  String get preferredWorkshopNone => 'Nessuna officina preferita selezionata.';

  @override
  String get preferredWorkshopChoose => 'Scegli officina';

  @override
  String get preferredWorkshopEdit => 'Modifica officina';

  @override
  String get preferredWorkshopRemove => 'Rimuovi';

  @override
  String get preferredWorkshopYours => 'La tua officina preferita';

  @override
  String get preferredWorkshopUse => 'Usa questa officina';

  @override
  String get preferredWorkshopSaved => 'Officina preferita salvata.';

  @override
  String get preferredWorkshopRemoved => 'Officina preferita rimossa.';

  @override
  String get preferredWorkshopLoadError =>
      'Non è stato possibile caricare l\'officina preferita.';

  @override
  String get preferredWorkshopSaveError =>
      'Non è stato possibile salvare l\'officina preferita.';

  @override
  String get preferredWorkshopOpen => 'Aperto';

  @override
  String get preferredWorkshopClosed => 'Chiuso';

  @override
  String get preferredWorkshopStatusUnavailable => 'Stato non disponibile';

  @override
  String get workshopServiceWheelRepairTitle => 'Riparazione cerchi';

  @override
  String get workshopServiceWheelRepairDescription =>
      'Valutazione e ripristino professionale di cerchi danneggiati.';

  @override
  String get workshopServiceOtherTitle => 'Altro';

  @override
  String get workshopServiceOtherDescription =>
      'Descrivi manualmente il servizio di cui hai bisogno.';

  @override
  String get wheelRepairIntro =>
      'Seleziona il tipo di cerchio e carica le fotografie del danno. L’officina scelta potrà esaminare le immagini prima dell’appuntamento.';

  @override
  String get wheelRepairTypeLabel => 'Tipo di cerchio';

  @override
  String get wheelRepairTypeStandardPainted => 'Cerchio verniciato standard';

  @override
  String get wheelRepairTypeDiamondCut => 'Cerchio Diamond Cut';

  @override
  String get wheelRepairTypeTwoTone => 'Cerchio bicolore';

  @override
  String get wheelRepairTypeSpecialFinish => 'Cerchio con finitura speciale';

  @override
  String get wheelRepairTypeAssessmentRequired =>
      'Non so, richiedo una valutazione';

  @override
  String get wheelRepairPhotosTitle => 'Foto del cerchio';

  @override
  String get wheelRepairPhotosInfo =>
      'Carica almeno una foto completa del cerchio e una foto ravvicinata del danno.';

  @override
  String get wheelRepairPhotoFull => 'Foto completa del cerchio';

  @override
  String get wheelRepairPhotoCloseUp => 'Dettaglio ravvicinato del danno';

  @override
  String get wheelRepairPhotoSecondAngle => 'Seconda angolazione';

  @override
  String get wheelRepairPhotoAdditional => 'Foto aggiuntiva facoltativa';

  @override
  String get wheelRepairRecommended => 'Consigliata';

  @override
  String get wheelRepairOptional => 'Facoltativa';

  @override
  String get wheelRepairAddPhoto => 'Aggiungi foto';

  @override
  String get wheelRepairTakePhoto => 'Scatta foto';

  @override
  String get wheelRepairChoosePhoto => 'Seleziona dalla galleria';

  @override
  String get wheelRepairViewPhoto => 'Visualizza foto';

  @override
  String get wheelRepairRemovePhoto => 'Rimuovi foto';

  @override
  String get wheelRepairPhotoLimit => 'Puoi caricare al massimo 6 fotografie.';

  @override
  String get wheelRepairUnsupportedPhoto => 'Formato immagine non supportato.';

  @override
  String get wheelRepairPhotoError =>
      'Non è stato possibile aggiungere la fotografia. Riprova.';

  @override
  String get wheelRepairDamageDescriptionLabel =>
      'Descrivi brevemente il danno';

  @override
  String get continueToWorkshopSelection =>
      'Continua alla scelta dell’officina';

  @override
  String get otherServiceQuestion => 'Che servizio desideri?';

  @override
  String get otherServicePlaceholder =>
      'Descrivi brevemente il servizio richiesto…';

  @override
  String get otherServiceRequired =>
      'Descrivi il servizio richiesto per continuare.';
}
