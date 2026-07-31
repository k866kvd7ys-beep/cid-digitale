import 'dart:convert';

import 'package:cid_digitale/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

const String workshopServiceInspection = 'service_inspection';
const String workshopServiceRepair = 'service_repair';
const String workshopServiceVehicleCheck = 'vehicle_check';
const String workshopServiceClimate = 'climate_service';
const String workshopServiceAlignment = 'vehicle_alignment';
const String workshopServiceMfk = 'mfk_preparation';
const String workshopServiceBattery = 'battery_check';
const String workshopServiceFluids = 'fluid_level_check';
const String workshopServiceWheelRepair = 'wheel_repair';
const String workshopServiceOther = 'other_service_request';
const String workshopWheelTypeStandardPainted = 'standard_painted';
const String workshopWheelTypeDiamondCut = 'diamond_cut';
const String workshopWheelTypeTwoTone = 'two_tone';
const String workshopWheelTypeSpecialFinish = 'special_finish';
const String workshopWheelTypeAssessmentRequired = 'assessment_required';
const String workshopInspectionDetail30000 = 'service_30000';
const String workshopInspectionDetail60000 = 'service_60000';
const String workshopInspectionDetailOver60000 = 'service_over_60000';
const String workshopInspectionDetailOilChange = 'oil_change_service';
const String workshopClimateDetailStandard = 'climate_service_standard';
const String workshopClimateDetailPlus = 'climate_service_plus';
const String workshopCleaningPackageBronze = 'bronze';
const String workshopCleaningPackageSilber = 'silber';
const String workshopCleaningPackageGold = 'gold';
const String workshopAdditionalServiceGlassRepair = 'scheibenreparatur';
const String workshopAdditionalServiceTireChange = 'reifenwechsel';
const String workshopAdditionalServiceSeasonalTireChange =
    'reifenwechsel_sommer_winter';
const String workshopAdditionalServiceCollisionDamage = 'kollisionsschaden';
const String workshopAdditionalServiceParkingDamage = 'parkschaden';
const String workshopAdditionalServiceGlassDamage = 'glasschaden';
const String workshopAdditionalServiceRimRepair = 'felgen_reparieren';

const List<String> visibleWorkshopServiceKeys = <String>[
  workshopServiceInspection,
  workshopServiceRepair,
  workshopServiceVehicleCheck,
  workshopServiceClimate,
  workshopServiceAlignment,
  workshopServiceMfk,
  workshopServiceBattery,
  workshopServiceFluids,
  workshopServiceWheelRepair,
  workshopServiceOther,
];

const List<String> workshopWheelRepairTypeKeys = <String>[
  workshopWheelTypeStandardPainted,
  workshopWheelTypeDiamondCut,
  workshopWheelTypeTwoTone,
  workshopWheelTypeSpecialFinish,
  workshopWheelTypeAssessmentRequired,
];

String normalizeWorkshopServiceLocale(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'it':
    case 'en':
    case 'fr':
    case 'de':
      return raw!.trim().toLowerCase();
    default:
      return 'de';
  }
}

String _copy(
  String locale, {
  required String de,
  required String it,
  required String en,
  required String fr,
}) {
  switch (normalizeWorkshopServiceLocale(locale)) {
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

AppLocalizations _serviceLocalizations(String locale) {
  return lookupAppLocalizations(Locale(normalizeWorkshopServiceLocale(locale)));
}

String workshopServiceSelectionTitle(String locale) => _copy(
      locale,
      de: 'Service auswählen',
      it: 'Scegli servizio',
      en: 'Select service',
      fr: 'Choisir le service',
    );

String workshopServiceSelectionSubtitle(String locale) => _copy(
      locale,
      de: 'Wählen Sie den gewünschten Service, bevor Sie Datum und Uhrzeit auswählen.',
      it: 'Seleziona il servizio desiderato prima di scegliere data e orario.',
      en: 'Select the desired service before choosing date and time.',
      fr: 'Sélectionnez le service souhaité avant de choisir la date et l’heure.',
    );

String workshopServiceLabel(String locale, String? serviceKey) {
  switch (serviceKey) {
    case workshopServiceInspection:
      return _copy(
        locale,
        de: 'Service/Inspektion',
        it: 'Service/Ispezione',
        en: 'Service/Inspection',
        fr: 'Service/Inspection',
      );
    case workshopServiceRepair:
      return _copy(
        locale,
        de: 'Service und Reparaturarbeiten',
        it: 'Service e riparazioni',
        en: 'Service and repair work',
        fr: 'Service et réparations',
      );
    case workshopServiceVehicleCheck:
      return _copy(
        locale,
        de: 'Fahrzeug-Check ab CHF 59.-',
        it: 'Check veicolo da CHF 59.-',
        en: 'Vehicle check from CHF 59.-',
        fr: 'Contrôle véhicule dès CHF 59.-',
      );
    case workshopServiceClimate:
      return _copy(
        locale,
        de: 'Klima Service ab CHF 98.-',
        it: 'Servizio clima da CHF 98.-',
        en: 'A/C service from CHF 98.-',
        fr: 'Service climatisation dès CHF 98.-',
      );
    case workshopServiceAlignment:
      return _copy(
        locale,
        de: 'Fahrzeugvermessung ab CHF 195.-',
        it: 'Geometria ruote da CHF 195.-',
        en: 'Wheel alignment from CHF 195.-',
        fr: 'Géométrie des roues dès CHF 195.-',
      );
    case workshopServiceMfk:
      return _copy(
        locale,
        de: 'MFK-Bereitstellung',
        it: 'Preparazione MFK',
        en: 'MFK preparation',
        fr: 'Préparation MFK',
      );
    case workshopServiceBattery:
      return _copy(
        locale,
        de: 'Batterie-Check',
        it: 'Controllo batteria',
        en: 'Battery check',
        fr: 'Contrôle batterie',
      );
    case workshopServiceFluids:
      return _copy(
        locale,
        de: 'Niveaukontrolle und Flüssigkeiten auffüllen',
        it: 'Controllo livelli e rabbocco liquidi',
        en: 'Level check and fluid top-up',
        fr: 'Contrôle des niveaux et appoint des liquides',
      );
    case workshopServiceWheelRepair:
      return _serviceLocalizations(locale).workshopServiceWheelRepairTitle;
    case workshopServiceOther:
      return _serviceLocalizations(locale).workshopServiceOtherTitle;
    default:
      return _copy(
        locale,
        de: 'Service anmelden',
        it: 'Prenota servizio',
        en: 'Book service',
        fr: 'Prendre rendez-vous service',
      );
  }
}

String workshopServiceDescription(String locale, String serviceKey) {
  switch (serviceKey) {
    case workshopServiceInspection:
      return _copy(
        locale,
        de: 'Service nach Kilometerstand, Ölwechselservice',
        it: 'Service in base al chilometraggio, servizio cambio olio',
        en: 'Service by mileage, oil change service',
        fr: 'Service selon le kilométrage, service vidange',
      );
    case workshopServiceRepair:
      return _copy(
        locale,
        de: 'Wartung, Inspektion und Reparaturarbeiten für Ihr Fahrzeug.',
        it: 'Manutenzione, ispezione e riparazioni per il tuo veicolo.',
        en: 'Maintenance, inspection and repair work for your vehicle.',
        fr: 'Entretien, inspection et réparations pour votre véhicule.',
      );
    case workshopServiceVehicleCheck:
      return _copy(
        locale,
        de: 'Schneller Fahrzeug-Check mit professioneller Kontrolle.',
        it: 'Controllo rapido del veicolo con verifica professionale.',
        en: 'Quick vehicle check with professional inspection.',
        fr: 'Contrôle rapide du véhicule avec vérification professionnelle.',
      );
    case workshopServiceClimate:
      return _copy(
        locale,
        de: 'Prüfung und Service der Klimaanlage.',
        it: 'Controllo e servizio dell’impianto climatizzazione.',
        en: 'Inspection and service of the air conditioning system.',
        fr: 'Contrôle et entretien du système de climatisation.',
      );
    case workshopServiceAlignment:
      return _copy(
        locale,
        de: 'Vermessung der kompletten Lenkgeometrie',
        it: 'Controllo completo della geometria dello sterzo',
        en: 'Complete steering geometry measurement',
        fr: 'Contrôle complet de la géométrie de direction',
      );
    case workshopServiceMfk:
      return _copy(
        locale,
        de: 'Vorbereitung des Fahrzeugs für die MFK.',
        it: 'Preparazione del veicolo per il collaudo MFK.',
        en: 'Vehicle preparation for the MFK inspection.',
        fr: 'Préparation du véhicule pour le contrôle MFK.',
      );
    case workshopServiceBattery:
      return _copy(
        locale,
        de: 'Batteriezustand professionell überprüfen lassen.',
        it: 'Verifica professionale dello stato della batteria.',
        en: 'Professional check of your battery condition.',
        fr: 'Contrôle professionnel de l’état de la batterie.',
      );
    case workshopServiceFluids:
      return _copy(
        locale,
        de: 'Füllstände prüfen und Betriebsflüssigkeiten auffüllen.',
        it: 'Controllo livelli e rabbocco dei liquidi di esercizio.',
        en: 'Check fluid levels and top up operating fluids.',
        fr: 'Contrôle des niveaux et appoint des liquides essentiels.',
      );
    case workshopServiceWheelRepair:
      return _serviceLocalizations(locale)
          .workshopServiceWheelRepairDescription;
    case workshopServiceOther:
      return _serviceLocalizations(locale).workshopServiceOtherDescription;
    default:
      return '';
  }
}

IconData workshopServiceIcon(String serviceKey) {
  switch (serviceKey) {
    case workshopServiceInspection:
      return Icons.handyman_outlined;
    case workshopServiceRepair:
      return Icons.build_circle_outlined;
    case workshopServiceVehicleCheck:
      return Icons.fact_check_outlined;
    case workshopServiceClimate:
      return Icons.ac_unit_rounded;
    case workshopServiceAlignment:
      return Icons.straighten_rounded;
    case workshopServiceMfk:
      return Icons.assignment_turned_in_outlined;
    case workshopServiceBattery:
      return Icons.battery_charging_full_rounded;
    case workshopServiceFluids:
      return Icons.opacity_rounded;
    case workshopServiceWheelRepair:
      return Icons.tire_repair_outlined;
    case workshopServiceOther:
      return Icons.more_horiz_rounded;
    default:
      return Icons.build_rounded;
  }
}

String normalizeWorkshopInspectionDetail(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case workshopInspectionDetail60000:
      return workshopInspectionDetail60000;
    case workshopInspectionDetailOver60000:
      return workshopInspectionDetailOver60000;
    case workshopInspectionDetailOilChange:
      return workshopInspectionDetailOilChange;
    case workshopInspectionDetail30000:
    default:
      return workshopInspectionDetail30000;
  }
}

String workshopInspectionSubtitle(String locale) => _copy(
      locale,
      de: 'Bitte wählen Sie den Service aus, der zum Kilometerstand Ihres Fahrzeugs passt.',
      it: 'Seleziona il servizio adatto al chilometraggio del tuo veicolo.',
      en: 'Please choose the service that matches your vehicle mileage.',
      fr: 'Veuillez choisir le service correspondant au kilométrage de votre véhicule.',
    );

String workshopInspectionDetailLabel(String locale, String? detail) {
  switch (normalizeWorkshopInspectionDetail(detail)) {
    case workshopInspectionDetail60000:
      return _copy(
        locale,
        de: "Service 60'000 km",
        it: 'Service 60.000 km',
        en: 'Service 60,000 km',
        fr: 'Service 60 000 km',
      );
    case workshopInspectionDetailOver60000:
      return _copy(
        locale,
        de: "Service über 60'000 km",
        it: 'Service oltre 60.000 km',
        en: 'Service over 60,000 km',
        fr: 'Service au-delà de 60 000 km',
      );
    case workshopInspectionDetailOilChange:
      return _copy(
        locale,
        de: 'Ölwechselservice',
        it: 'Servizio cambio olio',
        en: 'Oil change service',
        fr: 'Service vidange',
      );
    case workshopInspectionDetail30000:
    default:
      return _copy(
        locale,
        de: "Service 30'000 km",
        it: 'Service 30.000 km',
        en: 'Service 30,000 km',
        fr: 'Service 30 000 km',
      );
  }
}

String workshopInspectionSelectionFieldLabel(String locale) => _copy(
      locale,
      de: 'Auswahl',
      it: 'Selezione',
      en: 'Selection',
      fr: 'Sélection',
    );

String normalizeWorkshopClimateDetail(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case workshopClimateDetailPlus:
      return workshopClimateDetailPlus;
    case workshopClimateDetailStandard:
    default:
      return workshopClimateDetailStandard;
  }
}

String workshopClimateDetailLabel(String locale, String? detail) {
  switch (normalizeWorkshopClimateDetail(detail)) {
    case workshopClimateDetailPlus:
      return _copy(
        locale,
        de: 'Klima-Service Plus',
        it: 'Servizio clima Plus',
        en: 'A/C Service Plus',
        fr: 'Service climatisation Plus',
      );
    case workshopClimateDetailStandard:
    default:
      return _copy(
        locale,
        de: 'Klima-Service',
        it: 'Servizio clima',
        en: 'A/C Service',
        fr: 'Service climatisation',
      );
  }
}

String? workshopServiceDetailLabel(
  String locale, {
  String? serviceType,
  String? serviceSelectionKey,
  String? serviceDetail,
}) {
  if (serviceDetail?.trim().isNotEmpty != true) {
    return null;
  }

  if (serviceType == workshopServiceInspection) {
    return workshopInspectionDetailLabel(locale, serviceDetail);
  }

  if (serviceSelectionKey == workshopServiceClimate) {
    return workshopClimateDetailLabel(locale, serviceDetail);
  }

  if (serviceSelectionKey == workshopServiceWheelRepair) {
    final wheelType = workshopWheelTypeFromServiceDetail(serviceDetail);
    return wheelType == null
        ? null
        : workshopWheelRepairTypeLabel(locale, wheelType);
  }

  if (serviceSelectionKey == workshopServiceOther) {
    return serviceDetail!.trim();
  }

  return null;
}

String workshopServiceDetailFieldLabel(
  String locale,
  String? serviceSelectionKey,
) {
  final l10n = _serviceLocalizations(locale);
  if (serviceSelectionKey == workshopServiceWheelRepair) {
    return l10n.wheelRepairTypeLabel;
  }
  if (serviceSelectionKey == workshopServiceOther) {
    return l10n.otherServiceQuestion;
  }
  return workshopInspectionSelectionFieldLabel(locale);
}

String workshopWheelRepairTypeLabel(String locale, String wheelType) {
  final l10n = _serviceLocalizations(locale);
  switch (wheelType) {
    case workshopWheelTypeStandardPainted:
      return l10n.wheelRepairTypeStandardPainted;
    case workshopWheelTypeDiamondCut:
      return l10n.wheelRepairTypeDiamondCut;
    case workshopWheelTypeTwoTone:
      return l10n.wheelRepairTypeTwoTone;
    case workshopWheelTypeSpecialFinish:
      return l10n.wheelRepairTypeSpecialFinish;
    case workshopWheelTypeAssessmentRequired:
    default:
      return l10n.wheelRepairTypeAssessmentRequired;
  }
}

String encodeWorkshopWheelRepairDetail({
  required String wheelType,
  String? description,
}) {
  final normalizedType = workshopWheelRepairTypeKeys.contains(wheelType)
      ? wheelType
      : workshopWheelTypeAssessmentRequired;
  final normalizedDescription = description?.trim() ?? '';
  return jsonEncode({
    'wheelType': normalizedType,
    if (normalizedDescription.isNotEmpty) 'description': normalizedDescription,
  });
}

Map<String, dynamic> _decodeWorkshopWheelRepairDetail(String? detail) {
  final raw = detail?.trim() ?? '';
  if (raw.isEmpty) return const <String, dynamic>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return <String, dynamic>{'wheelType': raw};
}

String? workshopWheelTypeFromServiceDetail(String? detail) {
  final decoded = _decodeWorkshopWheelRepairDetail(detail);
  final wheelType = decoded['wheelType']?.toString().trim() ?? '';
  return wheelType.isEmpty ? null : wheelType;
}

String? workshopWheelDescriptionFromServiceDetail(String? detail) {
  final decoded = _decodeWorkshopWheelRepairDetail(detail);
  final description = decoded['description']?.toString().trim() ?? '';
  return description.isEmpty ? null : description;
}

String workshopWheelDescriptionFieldLabel(String locale) =>
    _serviceLocalizations(locale).wheelRepairDamageDescriptionLabel;

String workshopInspectionAdditionalNote(String locale) => _copy(
      locale,
      de: 'Zusätzliche Wünsche bitte im Anschluss als Anmerkung hinzufügen.',
      it: 'Eventuali richieste aggiuntive possono essere aggiunte successivamente come nota.',
      en: 'Please add any additional requests afterwards as a note.',
      fr: 'Veuillez ajouter ensuite toute demande supplémentaire comme remarque.',
    );

String workshopInspectionBackLabel(String locale) => _copy(
      locale,
      de: 'Zurück',
      it: 'Indietro',
      en: 'Back',
      fr: 'Retour',
    );

String workshopInspectionContinueLabel(String locale) => _copy(
      locale,
      de: 'Weiter zur Terminbuchung',
      it: 'Continua alla prenotazione',
      en: 'Continue to appointment booking',
      fr: 'Continuer vers la réservation',
    );

String workshopInspectionAddServiceLabel(String locale) => _copy(
      locale,
      de: 'Leistung hinzufügen',
      it: 'Aggiungi prestazione',
      en: 'Add service',
      fr: 'Ajouter la prestation',
    );

String workshopInspectionCleaningTitle(String locale) => _copy(
      locale,
      de: 'Fahrzeugreinigung',
      it: 'Pulizia veicolo',
      en: 'Vehicle cleaning',
      fr: 'Nettoyage du véhicule',
    );

String workshopInspectionCleaningSubtitle(String locale) => _copy(
      locale,
      de: 'Wählen Sie Ihr Reinigungsprogramm',
      it: 'Scegli il tuo programma di pulizia',
      en: 'Choose your cleaning program',
      fr: 'Choisissez votre programme de nettoyage',
    );

String workshopInspectionCleaningOptionSubtitle(
  String locale,
  String package,
) {
  switch (normalizeWorkshopCleaningPackage(package)) {
    case workshopCleaningPackageSilber:
      return _copy(
        locale,
        de: 'zusätzliche Innen- und Felgenreinigung',
        it: 'pulizia interna e cerchi aggiuntiva',
        en: 'additional interior and wheel cleaning',
        fr: 'nettoyage supplémentaire intérieur et jantes',
      );
    case workshopCleaningPackageGold:
      return _copy(
        locale,
        de: 'komplette Premium-Innenreinigung',
        it: 'pulizia interna premium completa',
        en: 'complete premium interior cleaning',
        fr: 'nettoyage intérieur premium complet',
      );
    case workshopCleaningPackageBronze:
    default:
      return _copy(
        locale,
        de: 'inkl. Reinigung Bronze-Programm',
        it: 'incl. programma pulizia Bronze',
        en: 'incl. Bronze cleaning program',
        fr: 'incl. programme de nettoyage Bronze',
      );
  }
}

String workshopInspectionCleaningOptionDetail(
  String locale,
  String package,
) {
  switch (normalizeWorkshopCleaningPackage(package)) {
    case workshopCleaningPackageSilber:
    case workshopCleaningPackageGold:
      return _copy(
        locale,
        de: 'Supplement',
        it: 'Supplemento',
        en: 'Supplement',
        fr: 'Supplément',
      );
    case workshopCleaningPackageBronze:
    default:
      return _copy(
        locale,
        de: 'im Service inklusive',
        it: 'incluso nel servizio',
        en: 'included in the service',
        fr: 'inclus dans le service',
      );
  }
}

String workshopAdditionalServicesTitle(String locale) => _copy(
      locale,
      de: 'Weitere Leistungen hinzufügen',
      it: 'Aggiungi altre prestazioni',
      en: 'Add additional services',
      fr: 'Ajouter d’autres prestations',
    );

String workshopAdditionalServicesFieldLabel(String locale) => _copy(
      locale,
      de: 'Zusätzliche Leistungen',
      it: 'Prestazioni aggiuntive',
      en: 'Additional services',
      fr: 'Prestations supplémentaires',
    );

String workshopSelectionApplyLabel(String locale) => _copy(
      locale,
      de: 'Auswahl übernehmen',
      it: 'Conferma selezione',
      en: 'Apply selection',
      fr: 'Valider la sélection',
    );

String workshopCancelLabel(String locale) => _copy(
      locale,
      de: 'Abbrechen',
      it: 'Annulla',
      en: 'Cancel',
      fr: 'Annuler',
    );

List<String> workshopAdditionalServiceOptions() => const [
      workshopServiceVehicleCheck,
      workshopServiceClimate,
      workshopServiceBattery,
      workshopServiceAlignment,
      workshopAdditionalServiceSeasonalTireChange,
      workshopAdditionalServiceCollisionDamage,
      workshopAdditionalServiceParkingDamage,
      workshopAdditionalServiceGlassDamage,
      workshopAdditionalServiceRimRepair,
    ];

String workshopAdditionalServiceLabel(String locale, String key) {
  switch (key) {
    case workshopServiceVehicleCheck:
      return workshopServiceLabel(locale, workshopServiceVehicleCheck);
    case workshopServiceClimate:
      return workshopServiceLabel(locale, workshopServiceClimate);
    case workshopServiceBattery:
      return workshopServiceLabel(locale, workshopServiceBattery);
    case workshopServiceAlignment:
      return workshopServiceLabel(locale, workshopServiceAlignment);
    case workshopAdditionalServiceSeasonalTireChange:
      return _copy(
        locale,
        de: 'Reifenwechsel Sommer oder Winter',
        it: 'Cambio gomme estive o invernali',
        en: 'Summer or winter tire change',
        fr: 'Changement de pneus été ou hiver',
      );
    case workshopAdditionalServiceCollisionDamage:
      return _copy(
        locale,
        de: 'Kollisionsschaden',
        it: 'Danno da collisione',
        en: 'Collision damage',
        fr: 'Dommage de collision',
      );
    case workshopAdditionalServiceParkingDamage:
      return _copy(
        locale,
        de: 'Parkschaden',
        it: 'Danno da parcheggio',
        en: 'Parking damage',
        fr: 'Dommage de stationnement',
      );
    case workshopAdditionalServiceGlassDamage:
      return _copy(
        locale,
        de: 'Glasschaden',
        it: 'Danno vetro',
        en: 'Glass damage',
        fr: 'Dommage vitrage',
      );
    case workshopAdditionalServiceRimRepair:
      return _copy(
        locale,
        de: 'Felgen reparieren',
        it: 'Riparazione cerchi',
        en: 'Rim repair',
        fr: 'Réparation des jantes',
      );
    case workshopAdditionalServiceTireChange:
      return _copy(
        locale,
        de: 'Reifenwechsel',
        it: 'Cambio gomme',
        en: 'Tire change',
        fr: 'Changement de pneus',
      );
    default:
      return key;
  }
}

List<String> workshopInspectionPrimaryLines(String locale, String? detail) {
  switch (normalizeWorkshopInspectionDetail(detail)) {
    case workshopInspectionDetail60000:
      return [
        _copy(
          locale,
          de: "KM-Stand zwischen 30'000 - 60'000 km",
          it: 'Chilometraggio compreso tra 30.000 e 60.000 km',
          en: 'Mileage between 30,000 and 60,000 km',
          fr: 'Kilométrage entre 30 000 et 60 000 km',
        ),
        _copy(
          locale,
          de: 'inkl. Ölservice (bei Fälligkeit)',
          it: 'incl. servizio olio (se dovuto)',
          en: 'incl. oil service (if due)',
          fr: 'incl. service d’huile (si nécessaire)',
        ),
        _copy(
          locale,
          de: 'inkl. Reinigung Bronze-Programm',
          it: 'incl. pulizia programma Bronze',
          en: 'incl. Bronze cleaning program',
          fr: 'incl. programme de nettoyage Bronze',
        ),
      ];
    case workshopInspectionDetailOver60000:
      return [
        _copy(
          locale,
          de: "KM-Stand ist über 60'000 km",
          it: 'Il chilometraggio è superiore a 60.000 km',
          en: 'Mileage is over 60,000 km',
          fr: 'Le kilométrage est supérieur à 60 000 km',
        ),
        _copy(
          locale,
          de: 'inkl. Ölservice (bei Fälligkeit)',
          it: 'incl. servizio olio (se dovuto)',
          en: 'incl. oil service (if due)',
          fr: 'incl. service d’huile (si nécessaire)',
        ),
        _copy(
          locale,
          de: 'inkl. Reinigung Bronze-Programm',
          it: 'incl. pulizia programma Bronze',
          en: 'incl. Bronze cleaning program',
          fr: 'incl. programme de nettoyage Bronze',
        ),
      ];
    case workshopInspectionDetailOilChange:
      return [
        _copy(
          locale,
          de: 'Damit der Motor möglichst lange reibungslos läuft, ist ein regelmässiger Ölwechselservice notwendig. Dabei wird das Altöl abgelassen, fachgerecht entsorgt und durch frisches Motorenöl aufgefüllt. Ebenfalls wird der Ölfilter und die Dichtung ersetzt.',
          it: 'Per far funzionare il motore il più a lungo possibile senza problemi, è necessario un regolare servizio cambio olio. L’olio esausto viene scaricato, smaltito correttamente e sostituito con olio motore nuovo. Inoltre vengono sostituiti il filtro dell’olio e la guarnizione.',
          en: 'To keep the engine running smoothly for as long as possible, a regular oil change service is necessary. The used oil is drained, disposed of properly and replaced with fresh engine oil. The oil filter and gasket are also replaced.',
          fr: 'Pour que le moteur fonctionne le plus longtemps possible sans problème, un service de vidange régulier est nécessaire. L’huile usagée est vidangée, éliminée correctement et remplacée par de l’huile moteur neuve. Le filtre à huile et le joint sont également remplacés.',
        ),
      ];
    case workshopInspectionDetail30000:
    default:
      return [
        _copy(
          locale,
          de: "KM-Stand zwischen 0 - 30'000 km",
          it: 'Chilometraggio compreso tra 0 e 30.000 km',
          en: 'Mileage between 0 and 30,000 km',
          fr: 'Kilométrage entre 0 et 30 000 km',
        ),
        _copy(
          locale,
          de: 'inkl. Ölservice (bei Fälligkeit)',
          it: 'incl. servizio olio (se dovuto)',
          en: 'incl. oil service (if due)',
          fr: 'incl. service d’huile (si nécessaire)',
        ),
        _copy(
          locale,
          de: 'inkl. Reinigung Bronze-Programm',
          it: 'incl. pulizia programma Bronze',
          en: 'incl. Bronze cleaning program',
          fr: 'incl. programme de nettoyage Bronze',
        ),
      ];
  }
}

String? workshopInspectionSecondaryLine(String locale, String? detail) {
  if (normalizeWorkshopInspectionDetail(detail) !=
      workshopInspectionDetailOilChange) {
    return null;
  }

  return _copy(
    locale,
    de: 'inkl. Reinigung Bronze-Programm',
    it: 'incl. pulizia programma Bronze',
    en: 'incl. Bronze cleaning program',
    fr: 'incl. programme de nettoyage Bronze',
  );
}

String normalizeWorkshopCleaningPackage(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case workshopCleaningPackageSilber:
    case 'comfort':
      return workshopCleaningPackageSilber;
    case workshopCleaningPackageGold:
    case 'premium':
      return workshopCleaningPackageGold;
    case workshopCleaningPackageBronze:
    case 'basis':
    default:
      return workshopCleaningPackageBronze;
  }
}

String workshopCleaningPackageLabel(String locale, String? program) {
  switch (normalizeWorkshopCleaningPackage(program)) {
    case workshopCleaningPackageSilber:
      return 'Silber';
    case workshopCleaningPackageGold:
      return 'Gold';
    case workshopCleaningPackageBronze:
    default:
      return 'Bronze';
  }
}

String workshopCleaningPackageFieldLabel(String locale) => _copy(
      locale,
      de: 'Reinigungspaket',
      it: 'Pacchetto pulizia',
      en: 'Cleaning package',
      fr: 'Forfait nettoyage',
    );

String workshopCleaningPackageSubtitle(String locale, String? program) {
  switch (normalizeWorkshopCleaningPackage(program)) {
    case workshopCleaningPackageSilber:
      return _copy(
        locale,
        de: 'Zusätzlich zu Bronze',
        it: 'In aggiunta a Bronze',
        en: 'In addition to Bronze',
        fr: 'En plus de Bronze',
      );
    case workshopCleaningPackageGold:
      return _copy(
        locale,
        de: 'Zusätzlich zu Silber',
        it: 'In aggiunta a Silber',
        en: 'In addition to Silber',
        fr: 'En plus de Silber',
      );
    case workshopCleaningPackageBronze:
    default:
      return _copy(
        locale,
        de: 'Im Service inklusive',
        it: 'Incluso nel servizio',
        en: 'Included in the service',
        fr: 'Inclus dans le service',
      );
  }
}

String workshopCleaningPackageBadge(String locale, String? program) {
  switch (normalizeWorkshopCleaningPackage(program)) {
    case workshopCleaningPackageSilber:
      return _copy(
        locale,
        de: 'Premium Reinigung',
        it: 'Pulizia premium',
        en: 'Premium cleaning',
        fr: 'Nettoyage premium',
      );
    case workshopCleaningPackageGold:
      return _copy(
        locale,
        de: 'Maximale Pflege',
        it: 'Massima cura',
        en: 'Maximum care',
        fr: 'Soin maximal',
      );
    case workshopCleaningPackageBronze:
    default:
      return _copy(
        locale,
        de: 'Im Service kostenlos',
        it: 'Gratuito nel servizio',
        en: 'Free with service',
        fr: 'Inclus dans le service',
      );
  }
}

List<String> workshopCleaningPackageBullets(String locale, String? program) {
  switch (normalizeWorkshopCleaningPackage(program)) {
    case workshopCleaningPackageSilber:
      return [
        _copy(
          locale,
          de: 'Felgenreinigung',
          it: 'Pulizia cerchi',
          en: 'Wheel cleaning',
          fr: 'Nettoyage des jantes',
        ),
        _copy(
          locale,
          de: 'Reifenpflege mit Reifenglanz',
          it: 'Trattamento pneumatici con effetto lucido',
          en: 'Tire care with tire shine',
          fr: 'Entretien des pneus avec effet brillant',
        ),
        _copy(
          locale,
          de: 'Frontscheibe innen reinigen',
          it: 'Pulizia interna parabrezza',
          en: 'Clean windshield inside',
          fr: 'Nettoyage intérieur du pare-brise',
        ),
        _copy(
          locale,
          de: 'Seitenscheiben vorne innen reinigen',
          it: 'Pulizia interna vetri laterali anteriori',
          en: 'Clean front side windows inside',
          fr: 'Nettoyage intérieur des vitres latérales avant',
        ),
        _copy(
          locale,
          de: 'Innenraum komplett saugen',
          it: 'Aspirazione completa abitacolo',
          en: 'Vacuum complete interior',
          fr: 'Aspiration complète de l’habitacle',
        ),
        _copy(
          locale,
          de: 'Alle Sitze saugen',
          it: 'Aspirazione di tutti i sedili',
          en: 'Vacuum all seats',
          fr: 'Aspiration de tous les sièges',
        ),
      ];
    case workshopCleaningPackageGold:
      return [
        _copy(
          locale,
          de: 'Komplette Innenreinigung',
          it: 'Pulizia completa interna',
          en: 'Complete interior cleaning',
          fr: 'Nettoyage complet intérieur',
        ),
        _copy(
          locale,
          de: 'Erweiterte Premiumwäsche',
          it: 'Lavaggio premium esteso',
          en: 'Extended premium wash',
          fr: 'Lavage premium étendu',
        ),
        _copy(
          locale,
          de: 'Reinigung aller Türfalze',
          it: 'Pulizia di tutte le battute porta',
          en: 'Cleaning of all door jambs',
          fr: 'Nettoyage de tous les seuils de porte',
        ),
        _copy(
          locale,
          de: 'Reinigung aller Innenablagen',
          it: 'Pulizia di tutti i vani interni',
          en: 'Cleaning of all interior compartments',
          fr: 'Nettoyage de tous les rangements intérieurs',
        ),
        _copy(
          locale,
          de: 'Reinigung sämtlicher Innenfenster',
          it: 'Pulizia di tutti i vetri interni',
          en: 'Cleaning of all interior windows',
          fr: 'Nettoyage de toutes les vitres intérieures',
        ),
        _copy(
          locale,
          de: 'Professionelles Finish',
          it: 'Finitura professionale',
          en: 'Professional finish',
          fr: 'Finition professionnelle',
        ),
      ];
    case workshopCleaningPackageBronze:
    default:
      return [
        _copy(
          locale,
          de: 'Standard-Aussenwäsche',
          it: 'Lavaggio esterno standard',
          en: 'Standard exterior wash',
          fr: 'Lavage extérieur standard',
        ),
        _copy(
          locale,
          de: 'Armaturenbrett und Display reinigen',
          it: 'Pulizia cruscotto e display',
          en: 'Clean dashboard and display',
          fr: 'Nettoyage tableau de bord et écran',
        ),
        _copy(
          locale,
          de: 'Fussraum vorne saugen',
          it: 'Aspirazione vano piedi anteriore',
          en: 'Vacuum front footwell',
          fr: 'Aspiration de l’espace avant pour les pieds',
        ),
        _copy(
          locale,
          de: 'Front- und Seitenscheiben aussen reinigen',
          it: 'Pulizia esterna parabrezza e vetri laterali',
          en: 'Clean windshield and side windows outside',
          fr: 'Nettoyage extérieur pare-brise et vitres latérales',
        ),
        _copy(
          locale,
          de: 'Schweller vorne reinigen',
          it: 'Pulizia soglie anteriori',
          en: 'Clean front sills',
          fr: 'Nettoyage des seuils avant',
        ),
      ];
  }
}

String workshopVehicleCleaningFieldLabel(String locale) => _copy(
      locale,
      de: 'Fahrzeugreinigung',
      it: 'Pulizia veicolo',
      en: 'Vehicle cleaning',
      fr: 'Nettoyage du véhicule',
    );

String workshopPackageShortLabel(String locale) => _copy(
      locale,
      de: 'Paket',
      it: 'Pacchetto',
      en: 'Package',
      fr: 'Forfait',
    );
