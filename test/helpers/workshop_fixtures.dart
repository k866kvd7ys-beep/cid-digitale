import 'package:cid_digitale/models/workshop_model.dart';

const realPlacesWorkshopFixture = WorkshopModel(
  id: 'google-place-real-workshop',
  name: 'Garage Reale Lugano SA',
  email: '',
  phone: '+41 91 123 45 67',
  address: 'Via Industria 12',
  city: '6900 Lugano',
  rating: 4.6,
  isOpen: true,
  latitude: 46.0102,
  longitude: 8.9604,
  distanceKm: 2.1,
);

const realPreferredWorkshopFixture = WorkshopModel(
  id: 'google-place-preferred-workshop',
  name: 'Garage Preferito Reale SA',
  email: '',
  phone: '+41 91 765 43 21',
  address: 'Via Cantonale 42',
  city: '6900 Lugano',
  rating: 4.9,
  isOpen: true,
  latitude: 46.0037,
  longitude: 8.9511,
);

const legacyMockWorkshopFixture = WorkshopModel(
  id: 'garage-europa-ag',
  name: 'Garage Europa AG',
  email: 'garage.europa@email.ch',
  phone: '+41 91 555 10 10',
  address: 'Via Cantonale 10',
  city: '6900 Lugano',
  rating: 4.9,
  isOpen: true,
  latitude: 46.0050,
  longitude: 8.9516,
);

const legacyMockWorkshopFixtures = <WorkshopModel>[
  legacyMockWorkshopFixture,
  WorkshopModel(
    id: 'autocentro-ticino',
    name: 'AutoCentro Ticino',
    email: 'ticino.service@email.ch',
    phone: '+41 91 555 21 21',
    address: 'Viale Stazione 24',
    city: '6500 Bellinzona',
    rating: 4.8,
    isOpen: true,
    latitude: 46.1957,
    longitude: 9.0238,
  ),
  WorkshopModel(
    id: 'officine-mendrisio',
    name: 'Officine Mendrisio SA',
    email: 'mendrisio@email.ch',
    phone: '+41 91 555 30 30',
    address: 'Via Penate 7',
    city: '6850 Mendrisio',
    rating: 4.7,
    isOpen: false,
    latitude: 45.8721,
    longitude: 8.9851,
  ),
  WorkshopModel(
    id: 'carrosserie-lac',
    name: 'Carrosserie du Lac',
    email: 'atelier.lac@email.ch',
    phone: '+41 91 555 44 44',
    address: 'Rue du Port 6',
    city: '1820 Montreux',
    rating: 4.9,
    isOpen: true,
    latitude: 46.4329,
    longitude: 6.9103,
  ),
];

final legacyMockWorkshopNames =
    legacyMockWorkshopFixtures.map((workshop) => workshop.name).toSet();
