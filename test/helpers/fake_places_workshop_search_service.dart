import 'package:cid_digitale/models/workshop_model.dart';
import 'package:cid_digitale/services/places_workshop_search_service.dart';

class FakePlacesWorkshopSearchService extends PlacesWorkshopSearchService {
  FakePlacesWorkshopSearchService({
    this.textResults = const [],
    this.nearbyResults = const [],
  }) : super(apiKey: 'test-google-places-key');

  final List<WorkshopModel> textResults;
  final List<WorkshopModel> nearbyResults;

  int textSearchCalls = 0;
  int nearbySearchCalls = 0;

  @override
  Future<List<WorkshopModel>> searchWorkshopsByText({
    required String query,
    required String locale,
    double? latitude,
    double? longitude,
  }) async {
    textSearchCalls += 1;
    return textResults;
  }

  @override
  Future<List<WorkshopModel>> searchNearbyWorkshops({
    required double latitude,
    required double longitude,
    required String locale,
    String? cityHint,
  }) async {
    nearbySearchCalls += 1;
    return nearbyResults;
  }
}
