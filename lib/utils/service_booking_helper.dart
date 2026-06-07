import 'package:flutter/material.dart';

const String workshopServiceRepair = 'service_repair';
const String workshopServiceVehicleCheck = 'vehicle_check';
const String workshopServiceClimate = 'climate_service';
const String workshopServiceAlignment = 'vehicle_alignment';
const String workshopServiceMfk = 'mfk_preparation';
const String workshopServiceBattery = 'battery_check';
const String workshopServiceFluids = 'fluid_level_check';
const String workshopCleaningProgramBasis = 'basis';
const String workshopCleaningProgramComfort = 'comfort';
const String workshopCleaningProgramPremium = 'premium';

const List<String> visibleWorkshopServiceKeys = <String>[
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

String normalizeWorkshopCleaningProgram(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case workshopCleaningProgramComfort:
      return workshopCleaningProgramComfort;
    case workshopCleaningProgramPremium:
      return workshopCleaningProgramPremium;
    case workshopCleaningProgramBasis:
    default:
      return workshopCleaningProgramBasis;
  }
}

String workshopCleaningProgramLabel(String locale, String? program) {
  switch (normalizeWorkshopCleaningProgram(program)) {
    case workshopCleaningProgramComfort:
      return 'Comfort';
    case workshopCleaningProgramPremium:
      return 'Premium';
    case workshopCleaningProgramBasis:
    default:
      return 'Basis';
  }
}

String workshopCleaningProgramFieldLabel(String locale) => _copy(
      locale,
      de: 'Reinigungsprogramm',
      it: 'Programma pulizia',
      en: 'Cleaning program',
      fr: 'Programme de nettoyage',
    );
