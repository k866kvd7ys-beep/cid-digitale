import 'package:cid_digitale/models/personal_vehicle_data.dart';
import 'package:cid_digitale/services/personal_vehicle_repository.dart';

class FakePersonalVehicleRemoteDataSource
    implements PersonalVehicleRemoteDataSource {
  FakePersonalVehicleRemoteDataSource({required this.authenticatedUserId});

  String? authenticatedUserId;
  Object? loadError;
  Object? insertError;
  Object? updateError;
  Object? setPrimaryError;
  Object? deleteError;

  int loadCalls = 0;
  int insertVehiclesCalls = 0;
  int insertVehicleCalls = 0;
  int updateVehicleCalls = 0;
  int setPrimaryCalls = 0;
  int deleteCalls = 0;
  int _createdSequence = 0;

  final Map<String, List<Map<String, dynamic>>> _rowsByUser = {};

  void seed(
    String userId,
    PersonalVehicleCollection collection,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final vehicle in collection.vehicles) {
      rows.add(
        _rowFromVehicle(
          userId,
          vehicle,
          isPrimary: vehicle.id == collection.primaryVehicleId,
        ),
      );
    }
    _rowsByUser[userId] = rows;
  }

  List<Map<String, dynamic>> rowsFor(String userId) {
    return (_rowsByUser[userId] ?? const <Map<String, dynamic>>[])
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> loadVehicles(String userId) async {
    loadCalls++;
    _guardOwner(userId);
    if (loadError case final error?) throw error;
    return rowsFor(userId);
  }

  @override
  Future<void> insertVehicles(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    insertVehiclesCalls++;
    _guardOwner(userId);
    if (insertError case final error?) throw error;
    for (final row in rows) {
      _insertRow(userId, row);
    }
  }

  @override
  Future<void> insertVehicle(
    String userId,
    Map<String, dynamic> row,
  ) async {
    insertVehicleCalls++;
    _guardOwner(userId);
    if (insertError case final error?) throw error;
    _insertRow(userId, row);
  }

  @override
  Future<void> updateVehicle(
    String userId,
    String vehicleId,
    Map<String, dynamic> values,
  ) async {
    updateVehicleCalls++;
    _guardOwner(userId);
    if (updateError case final error?) throw error;

    final rows = _rowsByUser[userId] ?? <Map<String, dynamic>>[];
    final index = rows.indexWhere((row) => row['vehicle_id'] == vehicleId);
    if (index == -1) throw StateError('Customer vehicle was not found');
    rows[index] = {
      ...rows[index],
      ...values,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<void> setPrimaryVehicle(String userId, String vehicleId) async {
    setPrimaryCalls++;
    _guardOwner(userId);
    if (setPrimaryError case final error?) throw error;

    final rows = _rowsByUser[userId] ?? <Map<String, dynamic>>[];
    if (!rows.any((row) => row['vehicle_id'] == vehicleId)) {
      throw StateError('Customer vehicle was not found');
    }
    for (final row in rows) {
      row['is_primary'] = row['vehicle_id'] == vehicleId;
    }
  }

  @override
  Future<void> deleteVehicle(String userId, String vehicleId) async {
    deleteCalls++;
    _guardOwner(userId);
    if (deleteError case final error?) throw error;

    final rows = _rowsByUser[userId] ?? <Map<String, dynamic>>[];
    final index = rows.indexWhere((row) => row['vehicle_id'] == vehicleId);
    if (index == -1) throw StateError('Customer vehicle was not found');
    final deletedWasPrimary = rows[index]['is_primary'] == true;
    rows.removeAt(index);
    if (deletedWasPrimary && rows.isNotEmpty) {
      rows.sort(
        (left, right) => left['created_at']
            .toString()
            .compareTo(right['created_at'].toString()),
      );
      for (var index = 0; index < rows.length; index++) {
        rows[index]['is_primary'] = index == 0;
      }
    }
  }

  void _insertRow(String userId, Map<String, dynamic> source) {
    if (source['user_id'] != userId) {
      throw StateError('RLS rejected a different vehicle owner');
    }
    final rows = _rowsByUser.putIfAbsent(
      userId,
      () => <Map<String, dynamic>>[],
    );
    final vehicleId = source['vehicle_id']?.toString() ?? '';
    if (rows.any((row) => row['vehicle_id'] == vehicleId)) {
      throw StateError('Duplicate customer vehicle');
    }

    final row = Map<String, dynamic>.from(source);
    row['created_at'] = DateTime.utc(2026, 1, 1)
        .add(Duration(seconds: _createdSequence++))
        .toIso8601String();
    row['updated_at'] = row['created_at'];
    if (rows.isEmpty) row['is_primary'] = true;
    if (row['is_primary'] == true &&
        rows.any((existing) => existing['is_primary'] == true)) {
      throw StateError('Only one primary vehicle is allowed');
    }
    rows.add(row);
  }

  Map<String, dynamic> _rowFromVehicle(
    String userId,
    PersonalVehicleData vehicle, {
    required bool isPrimary,
  }) {
    return {
      'user_id': userId,
      'vehicle_id': vehicle.id,
      'plate': vehicle.targa,
      'brand': vehicle.marca,
      'model': vehicle.modello,
      'vin': vehicle.vin,
      'mileage': vehicle.kilometraggio,
      'first_registration': vehicle.primaImmatricolazione,
      'insurance_company': vehicle.assicurazione,
      'policy_number': vehicle.numeroPolizza,
      'claim_number': vehicle.numeroSinistro,
      'is_primary': isPrimary,
      'created_at': DateTime.utc(2026, 1, 1)
          .add(Duration(seconds: _createdSequence++))
          .toIso8601String(),
      'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    };
  }

  void _guardOwner(String userId) {
    if (authenticatedUserId == null || authenticatedUserId != userId) {
      throw StateError('RLS rejected access to another customer');
    }
  }
}
