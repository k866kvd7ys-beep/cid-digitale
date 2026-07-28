import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/services/preferred_workshop_repository.dart';

class FakePreferredWorkshopRepository implements PreferredWorkshopRepository {
  FakePreferredWorkshopRepository({this.stored});

  WorkshopModel? stored;
  Object? loadError;
  Object? saveError;
  Object? removeError;
  int loadCalls = 0;
  int saveCalls = 0;
  int removeCalls = 0;

  @override
  Future<WorkshopModel?> load() async {
    loadCalls++;
    if (loadError case final error?) throw error;
    return stored;
  }

  @override
  Future<void> save(WorkshopModel workshop) async {
    saveCalls++;
    if (saveError case final error?) throw error;
    stored = workshop;
  }

  @override
  Future<void> remove() async {
    removeCalls++;
    if (removeError case final error?) throw error;
    stored = null;
  }
}
