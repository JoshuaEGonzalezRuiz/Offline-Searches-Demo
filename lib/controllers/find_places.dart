import 'package:flutter/cupertino.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';
import 'package:offline_navigation_routes/controllers/add_poi_markers.dart';
import 'package:offline_navigation_routes/controllers/search_result_metadata.dart';
import 'package:offline_navigation_routes/models/add_suggestions.dart';

import 'messages.dart';

class FindPlaces {
  AddMarkers addMarkers = AddMarkers();

  Future<void> searchPlaces(
      TextEditingController toSearch,
      HereMapController hereMapController,
      GeoCoordinates? defaultCoordinates,
      double? distanceToEarthInMeters,
      bool needSearch,
      OfflineSearchEngine searchEngine,
      int selectedIndex,
      List<MapMarker?> mapMarkerList,
      List<AddSuggestion> suggestions) async {
    if (toSearch.text.isEmpty) {
      hereMapController.camera.lookAtPointWithDistance(
        defaultCoordinates!,
        distanceToEarthInMeters!,
      );
    } else {
      if (needSearch) {
        int maxItems = 30;
        SearchOptions searchOptions =
            SearchOptions();
        searchOptions.languageCode = LanguageCode.enUs;
        searchOptions.maxItems = maxItems;

        GeoBox viewportGeoBox = getMapViewGeoBox(hereMapController);
        TextQuery query = TextQuery.withBoxArea(toSearch.text, viewportGeoBox);
        searchEngine.searchByText(query, searchOptions,
            (SearchError? searchError, List<Place>? list) async {
          if (searchError != null) {
            print("Search Error: " + searchError.toString());
            return;
          }

          // Add new marker for each search result on map.
          for (Place? searchResult in list!) {
            print(
                "${searchResult!.title}, ${searchResult.address.addressText}");

            var contains = suggestions
                .where((element) => element.title == searchResult.title);

            if (contains.isEmpty) {
              suggestions.add((AddSuggestion(
                  title: searchResult.title,
                  address: searchResult.address.addressText,
                  coordinates: searchResult.geoCoordinates!)));

              Metadata metadata = Metadata();
              metadata.setCustomValue(
                  "key_search_result", SearchResultMetadata(searchResult));
              // Note: getGeoCoordinates() may return null only for Suggestions.
              await AddMarkers().addPoiMapMarker(
                  hereMapController,
                  searchResult.geoCoordinates!,
                  metadata,
                  selectedIndex,
                  mapMarkerList);
              //print(SearchResultMetadata(searchResult).searchResult.address.addressText);
            }
          }

          Messages().toastMessage(
              "Results obtained: ${list.length}. See console for details");
        });
      }
    }
  }

  GeoBox getMapViewGeoBox(HereMapController hereMapController) {
    GeoBox? geoBox = hereMapController.camera.boundingBox;
    if (geoBox == null) {
      print(
          "GeoBox creation failed, corners are null. This can happen when the map is tilted. Falling back to a fixed box.");
      GeoCoordinates southWestCorner = GeoCoordinates(
          hereMapController.camera.state.targetCoordinates.latitude - 0.05,
          hereMapController.camera.state.targetCoordinates.longitude - 0.05);
      GeoCoordinates northEastCorner = GeoCoordinates(
          hereMapController.camera.state.targetCoordinates.latitude + 0.05,
          hereMapController.camera.state.targetCoordinates.longitude + 0.05);
      geoBox = GeoBox(southWestCorner, northEastCorner);
    }
    return geoBox;
  }
}
