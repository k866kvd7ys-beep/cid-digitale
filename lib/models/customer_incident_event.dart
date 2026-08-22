enum CustomerIncidentEventType {
  collision('collision'),
  parkingDamage('parking_damage'),
  glassDamage('glass_damage'),
  hail('hail'),
  marten('marten'),
  theft('theft'),
  fire('fire'),
  naturalEvent('natural_event'),
  animalCollision('animal_collision'),
  other('other');

  const CustomerIncidentEventType(this.code);

  final String code;
}

enum CustomerIncidentEventSubtype {
  stormWind('storm_wind'),
  floodWater('flood_water'),
  landslideRockfall('landslide_rockfall'),
  snowPressure('snow_pressure'),
  otherNaturalEvent('other_natural_event'),
  stolenVehicle('stolen_vehicle'),
  attemptedTheft('attempted_theft'),
  stolenPartsAccessories('stolen_parts_accessories'),
  theftAttemptDamage('theft_attempt_damage');

  const CustomerIncidentEventSubtype(this.code);

  final String code;
}

const customerIncidentEventTypes = CustomerIncidentEventType.values;

const naturalEventSubtypes = <CustomerIncidentEventSubtype>[
  CustomerIncidentEventSubtype.stormWind,
  CustomerIncidentEventSubtype.floodWater,
  CustomerIncidentEventSubtype.landslideRockfall,
  CustomerIncidentEventSubtype.snowPressure,
  CustomerIncidentEventSubtype.otherNaturalEvent,
];

const theftEventSubtypes = <CustomerIncidentEventSubtype>[
  CustomerIncidentEventSubtype.stolenVehicle,
  CustomerIncidentEventSubtype.attemptedTheft,
  CustomerIncidentEventSubtype.stolenPartsAccessories,
  CustomerIncidentEventSubtype.theftAttemptDamage,
];

List<CustomerIncidentEventSubtype> customerIncidentSubtypesFor(
  CustomerIncidentEventType type,
) {
  return switch (type) {
    CustomerIncidentEventType.naturalEvent => naturalEventSubtypes,
    CustomerIncidentEventType.theft => theftEventSubtypes,
    _ => const [],
  };
}

CustomerIncidentEventType? customerIncidentEventTypeFromStoredValue(
  Object? value,
) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return switch (normalized) {
    'collision' ||
    'incident' ||
    'accident' ||
    'incident_collision' ||
    'damage_comprehensive' ||
    'haftpflichtschaden' =>
      CustomerIncidentEventType.collision,
    'parking_damage' ||
    'damage_parking' ||
    'parking' =>
      CustomerIncidentEventType.parkingDamage,
    'glass_damage' ||
    'damage_glass' ||
    'glass' =>
      CustomerIncidentEventType.glassDamage,
    'hail' || 'damage_hail' => CustomerIncidentEventType.hail,
    'marten' || 'damage_marten' => CustomerIncidentEventType.marten,
    'theft' || 'attempted_theft' => CustomerIncidentEventType.theft,
    'fire' => CustomerIncidentEventType.fire,
    'natural_event' ||
    'natural_damage' =>
      CustomerIncidentEventType.naturalEvent,
    'animal_collision' ||
    'collision_with_animal' =>
      CustomerIncidentEventType.animalCollision,
    'other' || 'damage_other' => CustomerIncidentEventType.other,
    _ => null,
  };
}

CustomerIncidentEventSubtype? customerIncidentEventSubtypeFromStoredValue(
  Object? value,
) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  for (final subtype in CustomerIncidentEventSubtype.values) {
    if (subtype.code == normalized) return subtype;
  }
  return null;
}

String normalizeCustomerIncidentEventType(Object? value) {
  final original = value?.toString().trim() ?? '';
  return customerIncidentEventTypeFromStoredValue(original)?.code ?? original;
}

String normalizeCustomerIncidentEventSubtype(Object? value) {
  final original = value?.toString().trim() ?? '';
  return customerIncidentEventSubtypeFromStoredValue(original)?.code ??
      original;
}

String customerIncidentEventLabel(
  CustomerIncidentEventType type,
  String languageCode,
) {
  final language = _supportedLanguage(languageCode);
  return switch ((type, language)) {
    (CustomerIncidentEventType.collision, 'it') => 'Incidente / Collisione',
    (CustomerIncidentEventType.collision, 'fr') => 'Accident / Collision',
    (CustomerIncidentEventType.collision, 'en') => 'Accident / Collision',
    (CustomerIncidentEventType.collision, _) => 'Unfall / Kollision',
    (CustomerIncidentEventType.parkingDamage, 'it') => 'Danno da parcheggio',
    (CustomerIncidentEventType.parkingDamage, 'fr') =>
      'Dommage de stationnement',
    (CustomerIncidentEventType.parkingDamage, 'en') => 'Parking damage',
    (CustomerIncidentEventType.parkingDamage, _) => 'Parkschaden',
    (CustomerIncidentEventType.glassDamage, 'it') => 'Danno vetri',
    (CustomerIncidentEventType.glassDamage, 'fr') => 'Dommage aux vitres',
    (CustomerIncidentEventType.glassDamage, 'en') => 'Glass damage',
    (CustomerIncidentEventType.glassDamage, _) => 'Glasschaden',
    (CustomerIncidentEventType.hail, 'it') => 'Grandine',
    (CustomerIncidentEventType.hail, 'fr') => 'Grêle',
    (CustomerIncidentEventType.hail, 'en') => 'Hail',
    (CustomerIncidentEventType.hail, _) => 'Hagelschaden',
    (CustomerIncidentEventType.marten, 'it') => 'Martora',
    (CustomerIncidentEventType.marten, 'fr') => 'Fouine',
    (CustomerIncidentEventType.marten, 'en') => 'Marten',
    (CustomerIncidentEventType.marten, _) => 'Marderschaden',
    (CustomerIncidentEventType.theft, 'it') => 'Furto / tentato furto',
    (CustomerIncidentEventType.theft, 'fr') => 'Vol / tentative de vol',
    (CustomerIncidentEventType.theft, 'en') => 'Theft / attempted theft',
    (CustomerIncidentEventType.theft, _) => 'Diebstahl / versuchter Diebstahl',
    (CustomerIncidentEventType.fire, 'it') => 'Incendio',
    (CustomerIncidentEventType.fire, 'fr') => 'Incendie',
    (CustomerIncidentEventType.fire, 'en') => 'Fire',
    (CustomerIncidentEventType.fire, _) => 'Brand',
    (CustomerIncidentEventType.naturalEvent, 'it') => 'Danno naturale',
    (CustomerIncidentEventType.naturalEvent, 'fr') => 'Dommage naturel',
    (CustomerIncidentEventType.naturalEvent, 'en') => 'Natural event damage',
    (CustomerIncidentEventType.naturalEvent, _) => 'Naturereignis',
    (CustomerIncidentEventType.animalCollision, 'it') =>
      'Collisione con animale',
    (CustomerIncidentEventType.animalCollision, 'fr') =>
      'Collision avec un animal',
    (CustomerIncidentEventType.animalCollision, 'en') =>
      'Collision with an animal',
    (CustomerIncidentEventType.animalCollision, _) => 'Kollision mit Tier',
    (CustomerIncidentEventType.other, 'it') => 'Altro',
    (CustomerIncidentEventType.other, 'fr') => 'Autre',
    (CustomerIncidentEventType.other, 'en') => 'Other',
    (CustomerIncidentEventType.other, _) => 'Sonstiges',
  };
}

String customerIncidentEventSubtypeLabel(
  CustomerIncidentEventSubtype subtype,
  String languageCode,
) {
  final language = _supportedLanguage(languageCode);
  return switch ((subtype, language)) {
    (CustomerIncidentEventSubtype.stormWind, 'it') => 'Tempesta / vento forte',
    (CustomerIncidentEventSubtype.stormWind, 'fr') => 'Tempête / vent fort',
    (CustomerIncidentEventSubtype.stormWind, 'en') => 'Storm / strong wind',
    (CustomerIncidentEventSubtype.stormWind, _) => 'Sturm / starker Wind',
    (CustomerIncidentEventSubtype.floodWater, 'it') => 'Alluvione / acqua',
    (CustomerIncidentEventSubtype.floodWater, 'fr') => 'Inondation / eau',
    (CustomerIncidentEventSubtype.floodWater, 'en') => 'Flood / water',
    (CustomerIncidentEventSubtype.floodWater, _) => 'Überschwemmung / Wasser',
    (CustomerIncidentEventSubtype.landslideRockfall, 'it') =>
      'Frana / caduta massi',
    (CustomerIncidentEventSubtype.landslideRockfall, 'fr') =>
      'Glissement de terrain / chute de pierres',
    (CustomerIncidentEventSubtype.landslideRockfall, 'en') =>
      'Landslide / rockfall',
    (CustomerIncidentEventSubtype.landslideRockfall, _) =>
      'Erdrutsch / Steinschlag',
    (CustomerIncidentEventSubtype.snowPressure, 'it') =>
      'Neve / pressione della neve',
    (CustomerIncidentEventSubtype.snowPressure, 'fr') =>
      'Neige / pression de la neige',
    (CustomerIncidentEventSubtype.snowPressure, 'en') => 'Snow / snow pressure',
    (CustomerIncidentEventSubtype.snowPressure, _) => 'Schnee / Schneedruck',
    (CustomerIncidentEventSubtype.otherNaturalEvent, 'it') =>
      'Altro evento naturale',
    (CustomerIncidentEventSubtype.otherNaturalEvent, 'fr') =>
      'Autre événement naturel',
    (CustomerIncidentEventSubtype.otherNaturalEvent, 'en') =>
      'Other natural event',
    (CustomerIncidentEventSubtype.otherNaturalEvent, _) =>
      'Anderes Naturereignis',
    (CustomerIncidentEventSubtype.stolenVehicle, 'it') => 'Veicolo rubato',
    (CustomerIncidentEventSubtype.stolenVehicle, 'fr') => 'Véhicule volé',
    (CustomerIncidentEventSubtype.stolenVehicle, 'en') => 'Stolen vehicle',
    (CustomerIncidentEventSubtype.stolenVehicle, _) => 'Gestohlenes Fahrzeug',
    (CustomerIncidentEventSubtype.attemptedTheft, 'it') => 'Tentato furto',
    (CustomerIncidentEventSubtype.attemptedTheft, 'fr') => 'Tentative de vol',
    (CustomerIncidentEventSubtype.attemptedTheft, 'en') => 'Attempted theft',
    (CustomerIncidentEventSubtype.attemptedTheft, _) => 'Diebstahlversuch',
    (CustomerIncidentEventSubtype.stolenPartsAccessories, 'it') =>
      'Parti/accessori rubati',
    (CustomerIncidentEventSubtype.stolenPartsAccessories, 'fr') =>
      'Pièces/accessoires volés',
    (CustomerIncidentEventSubtype.stolenPartsAccessories, 'en') =>
      'Stolen parts/accessories',
    (CustomerIncidentEventSubtype.stolenPartsAccessories, _) =>
      'Gestohlene Teile/Zubehör',
    (CustomerIncidentEventSubtype.theftAttemptDamage, 'it') =>
      'Danni causati durante il furto/tentato furto',
    (CustomerIncidentEventSubtype.theftAttemptDamage, 'fr') =>
      'Dommages causés pendant le vol/la tentative',
    (CustomerIncidentEventSubtype.theftAttemptDamage, 'en') =>
      'Damage caused during theft/attempted theft',
    (CustomerIncidentEventSubtype.theftAttemptDamage, _) =>
      'Schäden durch Diebstahl/Diebstahlversuch',
  };
}

class CustomerIncidentOperationalClassification {
  const CustomerIncidentOperationalClassification({
    required this.eventCategory,
    required this.insuranceArea,
    required this.policyVerificationRequired,
    required this.liabilityContextRequired,
  });

  final String eventCategory;
  final String insuranceArea;
  final bool policyVerificationRequired;
  final bool liabilityContextRequired;

  Map<String, dynamic> toJson() => {
        'event_category': eventCategory,
        'insurance_area': insuranceArea,
        'policy_verification_required': policyVerificationRequired,
        'liability_context_required': liabilityContextRequired,
      };
}

CustomerIncidentOperationalClassification classifyCustomerIncidentEvent(
  Object? storedEventType,
) {
  final type = customerIncidentEventTypeFromStoredValue(storedEventType);
  return switch (type) {
    CustomerIncidentEventType.collision =>
      const CustomerIncidentOperationalClassification(
        eventCategory: 'collision',
        insuranceArea: 'comprehensive_or_liability_context_required',
        policyVerificationRequired: true,
        liabilityContextRequired: true,
      ),
    CustomerIncidentEventType.parkingDamage =>
      const CustomerIncidentOperationalClassification(
        eventCategory: 'parking_damage',
        insuranceArea: 'undetermined',
        policyVerificationRequired: true,
        liabilityContextRequired: true,
      ),
    CustomerIncidentEventType.glassDamage =>
      _partialComprehensiveClassification('glass_damage'),
    CustomerIncidentEventType.hail =>
      _partialComprehensiveClassification('natural_event'),
    CustomerIncidentEventType.marten =>
      _partialComprehensiveClassification('marten_damage'),
    CustomerIncidentEventType.theft =>
      _partialComprehensiveClassification('theft'),
    CustomerIncidentEventType.fire =>
      _partialComprehensiveClassification('fire'),
    CustomerIncidentEventType.naturalEvent =>
      _partialComprehensiveClassification('natural_event'),
    CustomerIncidentEventType.animalCollision =>
      const CustomerIncidentOperationalClassification(
        eventCategory: 'animal_collision',
        insuranceArea: 'partial_comprehensive_policy_dependent',
        policyVerificationRequired: true,
        liabilityContextRequired: false,
      ),
    CustomerIncidentEventType.other ||
    null =>
      const CustomerIncidentOperationalClassification(
        eventCategory: 'unclassified',
        insuranceArea: 'undetermined',
        policyVerificationRequired: true,
        liabilityContextRequired: false,
      ),
  };
}

CustomerIncidentOperationalClassification _partialComprehensiveClassification(
  String eventCategory,
) {
  return CustomerIncidentOperationalClassification(
    eventCategory: eventCategory,
    insuranceArea: 'partial_comprehensive',
    policyVerificationRequired: true,
    liabilityContextRequired: false,
  );
}

String _supportedLanguage(String languageCode) {
  final normalized = languageCode.trim().toLowerCase();
  return const {'de', 'it', 'fr', 'en'}.contains(normalized)
      ? normalized
      : 'de';
}
