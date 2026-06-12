import '../models/workshop_model.dart';

class WorkshopCatalogService {
  Future<List<WorkshopModel>> fetchWorkshops() async {
    // TODO: replace the mock list with a Supabase-backed workshops table.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return List<WorkshopModel>.unmodifiable(_mockWorkshops);
  }
}

const List<WorkshopModel> _mockWorkshops = [
  WorkshopModel(
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
  ),
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
