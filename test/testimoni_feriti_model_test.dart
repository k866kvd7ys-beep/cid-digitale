import 'package:cid_digitale/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy witness data keeps working with empty additive fields', () {
    final witness = Testimone.fromJson({
      'nome': 'Mario Rossi',
      'telefono': '000000',
    });

    expect(witness.nome, 'Mario Rossi');
    expect(witness.telefono, '000000');
    expect(witness.cognome, isEmpty);
    expect(witness.indirizzo, isEmpty);
    expect(witness.email, isEmpty);
    expect(witness.nota, isEmpty);
  });

  test('witness round-trip preserves every new field and legacy key', () {
    final witness = Testimone(
      nome: 'Nome',
      cognome: 'Cognome',
      indirizzo: 'Indirizzo',
      zip: '00000',
      city: 'Città',
      country: 'Paese',
      telefono: '000000',
      email: 'persona@example.test',
      nota: 'Nota',
    );

    final json = witness.toJson();
    final restored = Testimone.fromJson(json);

    expect(json['nome'], 'Nome');
    expect(json['telefono'], '000000');
    expect(restored.cognome, 'Cognome');
    expect(restored.indirizzo, 'Indirizzo');
    expect(restored.zip, '00000');
    expect(restored.city, 'Città');
    expect(restored.country, 'Paese');
    expect(restored.email, 'persona@example.test');
    expect(restored.nota, 'Nota');
  });

  test('legacy injured data keeps working with empty additive fields', () {
    final injured = Ferito.fromJson({
      'nome': 'Mario Rossi',
      'indirizzo': 'Indirizzo precedente',
      'telefono': '000000',
    });

    expect(injured.nome, 'Mario Rossi');
    expect(injured.indirizzo, 'Indirizzo precedente');
    expect(injured.telefono, '000000');
    expect(injured.cognome, isEmpty);
    expect(injured.ruolo, isEmpty);
    expect(injured.gravita, isEmpty);
    expect(injured.nota, isEmpty);
  });

  test('injured round-trip preserves every new field and legacy key', () {
    final injured = Ferito(
      nome: 'Nome',
      cognome: 'Cognome',
      indirizzo: 'Indirizzo',
      zip: '00000',
      city: 'Città',
      country: 'Paese',
      telefono: '000000',
      email: 'persona@example.test',
      ruolo: 'passenger',
      veicoloCollegato: 'B',
      gravita: 'moderate',
      trasportatoOspedale: 'yes',
      nomeOspedale: 'Ospedale',
      nota: 'Nota',
    );

    final json = injured.toJson();
    final restored = Ferito.fromJson(json);

    expect(json['nome'], 'Nome');
    expect(json['indirizzo'], 'Indirizzo');
    expect(json['telefono'], '000000');
    expect(restored.cognome, 'Cognome');
    expect(restored.zip, '00000');
    expect(restored.city, 'Città');
    expect(restored.country, 'Paese');
    expect(restored.email, 'persona@example.test');
    expect(restored.ruolo, 'passenger');
    expect(restored.veicoloCollegato, 'B');
    expect(restored.gravita, 'moderate');
    expect(restored.trasportatoOspedale, 'yes');
    expect(restored.nomeOspedale, 'Ospedale');
    expect(restored.nota, 'Nota');
  });
}
