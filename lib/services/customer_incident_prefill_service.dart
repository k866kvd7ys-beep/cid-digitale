import 'package:shared_preferences/shared_preferences.dart';

import '../models/customer_profile.dart';
import '../models/driver_personal_qr_data.dart';
import '../models/personal_vehicle_data.dart';
import 'customer_auth_service.dart';
import 'personal_vehicle_repository.dart';
import 'personal_vehicle_storage.dart';

abstract interface class CustomerIncidentPrefillLoader {
  Future<CustomerIncidentPrefillData> load();
}

class CustomerIncidentPrefillData {
  const CustomerIncidentPrefillData({
    required this.customerProfile,
    required this.cachedPersonalData,
    required this.vehicles,
    required this.accountEmail,
    this.profileLoadError,
    this.vehicleLoadError,
  });

  final CustomerProfile? customerProfile;
  final DriverPersonalQrData? cachedPersonalData;
  final PersonalVehicleCollection vehicles;
  final String accountEmail;
  final Object? profileLoadError;
  final Object? vehicleLoadError;

  bool get hasLoadError => profileLoadError != null || vehicleLoadError != null;

  DriverPersonalQrData? driverDataForVehicle(
    PersonalVehicleData? vehicle,
  ) {
    var data = cachedPersonalData ?? const DriverPersonalQrData.empty();
    final profile = customerProfile;
    if (profile != null) {
      data = data.copyWith(
        courtesy: driverPersonalQrCourtesyFromString(profile.title),
        nome: profile.firstName,
        cognome: profile.lastName,
        indirizzo: profile.street,
        zip: profile.postalCode,
        city: profile.city,
        country: profile.country,
        telefono: profile.phone,
        email: profile.email.trim().isNotEmpty ? profile.email : accountEmail,
      );
    }
    if (vehicle != null) {
      data = vehicle.applyToProfile(data);
    }
    return data.hasAnyValue ? data : null;
  }
}

class CustomerIncidentPrefillService implements CustomerIncidentPrefillLoader {
  CustomerIncidentPrefillService({
    required CustomerAuthService authService,
    CustomerProfile? fallbackProfile,
    PersonalVehicleRepository? vehicleRepository,
    PersonalVehicleStorage? localVehicleStorage,
    SharedPreferences? preferences,
  })  : _authService = authService,
        _fallbackProfile = fallbackProfile,
        _vehicleRepository = vehicleRepository ?? PersonalVehicleRepository(),
        _localVehicleStorage = localVehicleStorage ?? PersonalVehicleStorage(),
        _preferences = preferences;

  static const _personalQrProfileStorageKey = 'driver_personal_qr_data_v1';

  final CustomerAuthService _authService;
  final CustomerProfile? _fallbackProfile;
  final PersonalVehicleRepository _vehicleRepository;
  final PersonalVehicleStorage _localVehicleStorage;
  final SharedPreferences? _preferences;

  @override
  Future<CustomerIncidentPrefillData> load() async {
    final account = _authService.currentAccount;
    if (account == null) {
      throw const CustomerAuthException(
        CustomerAuthErrorCode.unauthenticated,
      );
    }

    CustomerProfile? profile = _fallbackProfile;
    var vehicles = const PersonalVehicleCollection.empty();
    Object? profileError;
    Object? vehicleError;

    // Avvia entrambe le letture subito: sono indipendenti e non richiedono
    // l'apertura preventiva della pagina QR personale.
    final profileFuture = _authService.loadProfile(account.id).catchError(
      (Object error) {
        profileError = error;
        return profile;
      },
    );
    final vehiclesFuture =
        _vehicleRepository.loadForUser(account.id).catchError(
      (Object error) async {
        vehicleError = error;
        return _loadScopedVehicleCache(account.id);
      },
    );

    profile = await profileFuture ?? profile;
    try {
      vehicles = await vehiclesFuture;
    } catch (_) {
      vehicles = await _loadScopedVehicleCache(account.id);
    }

    DriverPersonalQrData? cachedPersonalData;
    try {
      final preferences = _preferences ?? await SharedPreferences.getInstance();
      await preferences.reload();
      final decoded = driverPersonalQrDataFromJson(
        preferences.getString(_personalQrProfileStorageKey) ?? '',
      );
      if (profile != null && decoded.hasAnyValue) {
        // I veicoli arrivano dalla raccolta server scoped per utente. Dalla
        // cache QR riusiamo soltanto gli eventuali dati personali aggiuntivi,
        // evitando targhe/assicurazioni lasciate da un altro accesso.
        cachedPersonalData = decoded.copyWith(
          targa: '',
          marca: '',
          modello: '',
          vin: '',
          kilometraggio: '',
          primaImmatricolazione: '',
          assicurazione: '',
          numeroPolizza: '',
          numeroSinistro: '',
        );
      }
    } catch (_) {}

    return CustomerIncidentPrefillData(
      customerProfile: profile,
      cachedPersonalData: cachedPersonalData,
      vehicles: vehicles,
      accountEmail: account.email,
      profileLoadError: profileError,
      vehicleLoadError: vehicleError,
    );
  }

  Future<PersonalVehicleCollection> _loadScopedVehicleCache(
    String userId,
  ) async {
    try {
      final collection = await _localVehicleStorage.loadOrMigrate();
      final metadata = await _localVehicleStorage.loadCacheMetadata();
      if (metadata?.matches(userId, collection) != true) {
        return const PersonalVehicleCollection.empty();
      }
      return collection;
    } catch (_) {
      return const PersonalVehicleCollection.empty();
    }
  }
}
