
import 'package:flutter/cupertino.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';
import 'package:offline_navigation_routes/controllers/add_poi_markers.dart';
import 'package:offline_navigation_routes/models/add_suggestions.dart';
import 'package:offline_navigation_routes/controllers/search_result_metadata.dart';

import 'messages.dart';

class GetAutosuggestions {
  AddMarkers addMarkers = AddMarkers();

  Future<void> searchAutoSuggestion(HereMapController hereMapController,
      bool needSearch, OfflineSearchEngine searchEngine,
      TextEditingController searchPlacesController, List<AddSuggestion> suggestions,
      int selectedIndex, List<MapMarker?> mapMarkerList) async {

    if (needSearch) {
      GeoCoordinates centerGeoCoordinates = getMapViewCenter(hereMapController);

      int maxItems = 30;
      SearchOptions searchOptions =
      SearchOptions();
      searchOptions.languageCode = LanguageCode.enUs;
      searchOptions.maxItems = maxItems;

      searchEngine.suggest(
          TextQuery.withAreaCenter(
              searchPlacesController.text,
              centerGeoCoordinates),
          searchOptions,
              (SearchError? searchError, List<Suggestion>? list) async {
            await handleSuggestionResults(hereMapController, searchError, list,
                needSearch, suggestions, selectedIndex, mapMarkerList);
          });
    }
  }

  GeoCoordinates getMapViewCenter(HereMapController hereMapController) {
    return hereMapController.camera.state.targetCoordinates;
  }

  Future<void> handleSuggestionResults(HereMapController hereMapController,
      SearchError? searchError, List<Suggestion>? list,
      bool needSearch, List<AddSuggestion> suggestions,
      int selectedIndex, List<MapMarker?> mapMarkerList) async {
    if (needSearch) {
      if (searchError != null) {
        print("Autosuggestion Error: " + searchError.toString());
        return;
      }

      // If error is null, list is guaranteed to be not empty.
      int listLength = list!.length;
      print("Autosuggestion results: $listLength.");
      Metadata metadata = Metadata();

      for (Suggestion autosuggestResult in list) {
        String addressText = "Not a place.";
        Place? place = autosuggestResult.place;
        if (place != null) {
          addressText = place.address.addressText;

          print("Autosuggestion result: " +
              autosuggestResult.title +
              " coordinates: " +
              '${autosuggestResult.place!.geoCoordinates!.latitude},${autosuggestResult.place!.geoCoordinates!.longitude}');

          var contains = suggestions
              .where((element) => element.title == autosuggestResult.title);

          if (contains.isEmpty) {
            suggestions.add((AddSuggestion(
                title: autosuggestResult.title,
                address: autosuggestResult.place!.address.addressText,
                coordinates: autosuggestResult.place!.geoCoordinates!)));
          }

          metadata.setCustomValue("key_search_result",
              SearchResultMetadata(autosuggestResult.place!));
          await AddMarkers().addPoiMapMarker(hereMapController, autosuggestResult.place!.geoCoordinates,
              metadata, selectedIndex, mapMarkerList);
        }
      }

      Messages().toastMessage("Results obtained");
    }
  }
}