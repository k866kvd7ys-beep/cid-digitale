import 'package:cid_digitale/models/customer_incident_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all customer event types have stable operational classifications', () {
    const expected = <CustomerIncidentEventType, (String, String)>{
      CustomerIncidentEventType.collision: (
        'collision',
        'comprehensive_or_liability_context_required',
      ),
      CustomerIncidentEventType.parkingDamage: (
        'parking_damage',
        'undetermined',
      ),
      CustomerIncidentEventType.glassDamage: (
        'glass_damage',
        'partial_comprehensive',
      ),
      CustomerIncidentEventType.hail: (
        'natural_event',
        'partial_comprehensive',
      ),
      CustomerIncidentEventType.marten: (
        'marten_damage',
        'partial_comprehensive',
      ),
      CustomerIncidentEventType.theft: (
        'theft',
        'partial_comprehensive',
      ),
      CustomerIncidentEventType.fire: (
        'fire',
        'partial_comprehensive',
      ),
      CustomerIncidentEventType.naturalEvent: (
        'natural_event',
        'partial_comprehensive',
      ),
      CustomerIncidentEventType.animalCollision: (
        'animal_collision',
        'partial_comprehensive_policy_dependent',
      ),
      CustomerIncidentEventType.other: (
        'unclassified',
        'undetermined',
      ),
    };

    expect(customerIncidentEventTypes, hasLength(expected.length));
    for (final entry in expected.entries) {
      final classification = classifyCustomerIncidentEvent(entry.key.code);
      expect(classification.eventCategory, entry.value.$1);
      expect(classification.insuranceArea, entry.value.$2);
      expect(classification.policyVerificationRequired, isTrue);

      final json = classification.toJson();
      expect(json.containsKey('covered'), isFalse);
      expect(json.containsKey('coverage'), isFalse);
      expect(json['policy_verification_required'], isTrue);
    }
  });

  test('natural and theft subtypes stay simple and hail is not duplicated', () {
    expect(
      naturalEventSubtypes.map((subtype) => subtype.code),
      [
        'storm_wind',
        'flood_water',
        'landslide_rockfall',
        'snow_pressure',
        'other_natural_event',
      ],
    );
    expect(
      naturalEventSubtypes.any((subtype) => subtype.code.contains('hail')),
      isFalse,
    );
    expect(
      theftEventSubtypes.map((subtype) => subtype.code),
      [
        'stolen_vehicle',
        'attempted_theft',
        'stolen_parts_accessories',
        'theft_attempt_damage',
      ],
    );
  });

  test('all supported languages expose customer events without policy terms',
      () {
    for (final language in const ['de', 'it', 'fr', 'en']) {
      final eventLabels = customerIncidentEventTypes
          .map((type) => customerIncidentEventLabel(type, language))
          .toList(growable: false);
      final subtypeLabels = CustomerIncidentEventSubtype.values
          .map(
            (subtype) => customerIncidentEventSubtypeLabel(subtype, language),
          )
          .toList(growable: false);
      final visibleText = [...eventLabels, ...subtypeLabels].join(' ');

      expect(eventLabels, hasLength(10));
      expect(eventLabels.every((label) => label.trim().isNotEmpty), isTrue);
      expect(subtypeLabels.every((label) => label.trim().isNotEmpty), isTrue);
      expect(visibleText, isNot(contains('Haftpflicht')));
      expect(visibleText, isNot(contains('Teilkasko')));
      expect(visibleText, isNot(contains('Vollkasko')));
    }
  });

  test('legacy values are safely mapped and unknown values are preserved', () {
    expect(
      customerIncidentEventTypeFromStoredValue('Haftpflichtschaden'),
      CustomerIncidentEventType.collision,
    );
    expect(
      customerIncidentEventTypeFromStoredValue('damage_glass'),
      CustomerIncidentEventType.glassDamage,
    );
    expect(
      normalizeCustomerIncidentEventType('legacy_special_category'),
      'legacy_special_category',
    );
  });
}
