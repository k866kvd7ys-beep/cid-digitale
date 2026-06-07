import 'package:flutter/material.dart';

const String workshopServiceInspection = 'service_inspection';
const String workshopServiceRepair = 'service_repair';
const String workshopServiceVehicleCheck = 'vehicle_check';
const String workshopServiceClimate = 'climate_service';
const String workshopServiceAlignment = 'vehicle_alignment';
const String workshopServiceMfk = 'mfk_preparation';
const String workshopServiceBattery = 'battery_check';
const String workshopServiceFluids = 'fluid_level_check';
const String workshopInspectionDetail30000 = 'service_30000';
const String workshopInspectionDetail60000 = 'service_60000';
const String workshopInspectionDetailOver60000 = 'service_over_60000';
const String workshopInspectionDetailOilChange = 'oil_change_service';
const String workshopCleaningPackageBronze = 'bronze';
const String workshopCleaningPackageSilber = 'silber';
const String workshopCleaningPackageGold = 'gold';

const List<String> visibleWorkshopServiceKeys = <String>[
  workshopServiceInspection,
  workshopServiceRepair,
  workshopServiceVehicleCheck,
  workshopServiceClimate,
  workshopServiceAlignment,
  workshopServiceMfk,
  workshopServiceBattery,
  workshopServiceFluids,
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
        de: 'Fahrzeugvermessung',
        it: 'Assetto veicolo',
        en: 'Vehicle alignment',
        fr: 'Géométrie du véhicule',
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
        de: 'Präzise Vermessung für Spur und Fahrverhalten.',
        it: 'Controllo assetto per geometria e guida precisa.',
        en: 'Precise alignment check for steering and handling.',
        fr: 'Contrôle précis de la géométrie et du comportement routier.',
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
      de: 'Leistung hinzufügen',
      it: 'Aggiungi prestazione',
      en: 'Add service',
      fr: 'Ajouter la prestation',
    );

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
