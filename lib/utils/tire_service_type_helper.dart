import 'package:flutter/material.dart';

const tireServiceSummerCompleteWheels = 'summer_complete_wheels';
const tireServiceSummerTiresOnly = 'summer_tires_only';
const tireServiceWinterCompleteWheels = 'winter_complete_wheels';
const tireServiceWinterTiresOnly = 'winter_tires_only';

String tireLocaleCode(BuildContext context) =>
    tireLocaleFromString(Localizations.localeOf(context).languageCode);

String tireLocaleFromString(String? raw) {
  final value = raw?.trim().toLowerCase() ?? '';
  if (value.startsWith('it')) return 'it';
  if (value.startsWith('en')) return 'en';
  if (value.startsWith('fr')) return 'fr';
  return 'de';
}

bool isTireAppointmentService(String serviceType) =>
    serviceType == 'raeder_sommer' || serviceType == 'raeder_winter';

bool isSummerTireServiceType(String tireServiceType) =>
    tireServiceType == tireServiceSummerCompleteWheels ||
    tireServiceType == tireServiceSummerTiresOnly;

String tireServiceSectionLabel(String locale) => _copy(
      locale,
      de: 'Typ Reifenservice',
      it: 'Tipo servizio gomme',
      en: 'Tire service type',
      fr: 'Type de service pneus',
    );

String tireSeasonGroupTitle(String locale) => _copy(
      locale,
      de: 'Reifenwechsel',
      it: 'Cambio gomme',
      en: 'Tire Change',
      fr: 'Changement de pneus',
    );

String tireSeasonTitle(String locale, {required bool summer}) => summer
    ? _copy(
        locale,
        de: 'Sommerreifenwechsel',
        it: 'Cambio gomme estive',
        en: 'Summer Tire Change',
        fr: 'Changement de pneus été',
      )
    : _copy(
        locale,
        de: 'Winterreifenwechsel',
        it: 'Cambio gomme invernali',
        en: 'Winter Tire Change',
        fr: 'Changement de pneus hiver',
      );

String tireSeasonCardTitle(String locale, {required bool summer}) => summer
    ? _copy(
        locale,
        de: 'Sommerreifenwechsel',
        it: 'Cambio gomme estive',
        en: 'Summer Tire Change',
        fr: 'Changement de pneus été',
      )
    : _copy(
        locale,
        de: 'Winterreifenwechsel',
        it: 'Cambio gomme invernali',
        en: 'Winter Tire Change',
        fr: 'Pneus hiver',
      );

String tireSeasonCardSubtitle(String locale, {required bool summer}) => summer
    ? _copy(
        locale,
        de: 'Wählen Sie zwischen Sommer-Kompletträdern oder nur Sommerreifen.',
        it: 'Scegli tra cerchi completi estivi o solo pneumatici estivi.',
        en: 'Choose between summer complete wheels or summer tires only.',
        fr: 'Choisissez entre roues complètes été ou pneus été uniquement.',
      )
    : _copy(
        locale,
        de: 'Wählen Sie zwischen Winter-Kompletträdern oder nur Winterreifen.',
        it: 'Scegli tra cerchi completi invernali o solo pneumatici invernali.',
        en: 'Choose between winter complete wheels or winter tires only.',
        fr: 'Choisissez entre roues complètes hiver ou pneus hiver uniquement.',
      );

String tireOptionTitle(String locale, String tireServiceType) {
  switch (tireServiceType) {
    case tireServiceSummerCompleteWheels:
      return _copy(
        locale,
        de: 'Sommer-Kompletträder',
        it: 'Cerchi completi estivi',
        en: 'Summer Complete Wheels',
        fr: 'Roues complètes été',
      );
    case tireServiceSummerTiresOnly:
      return _copy(
        locale,
        de: 'Nur Sommerreifen',
        it: 'Solo pneumatici estivi',
        en: 'Summer Tires Only',
        fr: 'Pneus été uniquement',
      );
    case tireServiceWinterCompleteWheels:
      return _copy(
        locale,
        de: 'Winter-Kompletträder',
        it: 'Cerchi completi invernali',
        en: 'Winter Complete Wheels',
        fr: 'Roues complètes hiver',
      );
    case tireServiceWinterTiresOnly:
      return _copy(
        locale,
        de: 'Nur Winterreifen',
        it: 'Solo pneumatici invernali',
        en: 'Winter Tires Only',
        fr: 'Pneus hiver uniquement',
      );
    default:
      return '';
  }
}

String tireOptionDescription(String locale, String tireServiceType) {
  final isComplete = tireServiceType == tireServiceSummerCompleteWheels ||
      tireServiceType == tireServiceWinterCompleteWheels;
  if (isComplete) {
    return _copy(
      locale,
      de: 'Austausch kompletter, bereits montierter Räder.',
      it: 'Sostituzione ruote complete già montate.',
      en: 'Replacement of complete wheels already mounted.',
      fr: 'Remplacement de roues complètes déjà montées.',
    );
  }
  return _copy(
    locale,
    de: 'Montage der Reifen auf die vorhandenen Felgen.',
    it: 'Montaggio pneumatici sui cerchi esistenti.',
    en: 'Mounting tires on the existing rims.',
    fr: 'Montage des pneus sur les jantes existantes.',
  );
}

String tireStepTitle(String locale, {required bool summer}) => summer
    ? _copy(
        locale,
        de: 'Sommer-Service auswählen',
        it: 'Seleziona il servizio estivo',
        en: 'Select the summer service',
        fr: 'Sélectionnez le service été',
      )
    : _copy(
        locale,
        de: 'Winter-Service auswählen',
        it: 'Seleziona il servizio invernale',
        en: 'Select the winter service',
        fr: 'Sélectionnez le service hiver',
      );

String tireStepSubtitle(String locale) => _copy(
      locale,
      de: 'Nur zur korrekten Terminbuchung bei der Werkstatt. Keine Preise, kein Verkauf.',
      it: 'Serve solo per prenotare il servizio corretto in officina. Nessun prezzo, nessuna vendita.',
      en: 'Only used to book the correct workshop service. No prices, no sales.',
      fr: 'Utilisé uniquement pour réserver le bon service atelier. Aucun prix, aucune vente.',
    );

String tireBackToSeasonLabel(String locale) => _copy(
      locale,
      de: 'Andere Saison wählen',
      it: 'Scegli un\'altra stagione',
      en: 'Choose another season',
      fr: 'Choisir une autre saison',
    );

String tireContinueLabel(String locale) => _copy(
      locale,
      de: 'Weiter',
      it: 'Continua',
      en: 'Continue',
      fr: 'Continuer',
    );

String localizedTireServiceType(
  String locale, {
  required String? tireServiceType,
  String? serviceType,
}) {
  final normalized = tireServiceType?.trim() ?? '';
  if (normalized.isNotEmpty) {
    final label = tireOptionTitle(locale, normalized);
    if (label.isNotEmpty) return label;
  }

  if (serviceType == 'raeder_sommer') {
    return tireSeasonTitle(locale, summer: true);
  }
  if (serviceType == 'raeder_winter') {
    return tireSeasonTitle(locale, summer: false);
  }
  return tireSeasonGroupTitle(locale);
}

String _copy(
  String locale, {
  required String de,
  required String it,
  required String en,
  required String fr,
}) {
  switch (tireLocaleFromString(locale)) {
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
