import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';
import 'package:offline_navigation_routes/controllers/search_result_metadata.dart';
import 'package:offline_navigation_routes/models/add_location.dart';

import 'add_poi_markers.dart';
import 'messages.dart';

class GeocodeAddress {
  AddMarkers addMarkers = AddMarkers();

  Future<void> searchLocations(HereMapController hereMapController,
      TextEditingController searchLocationsController, GeoCoordinates geoCoordinates,
      OfflineSearchEngine searchEngine, List<AddLocation> locations,
      int selectedIndex, List<MapMarker?> mapMarkerList) async {
    AddressQuery query = AddressQuery.withAreaCenter(searchLocationsController.text, geoCoordinates);
    int maxItems = 30;
    SearchOptions searchOptions =
    SearchOptions();
    searchOptions.languageCode = LanguageCode.enUs;
    searchOptions.maxItems = maxItems;

    searchEngine.searchByAddress(query, searchOptions, (SearchError? searchError, List<Place>? list) async {
      if (searchError != null) {
        print("Geocoding Error: " + searchError.toString());
        return;
      }
      Metadata metadata = Metadata();

      String locationDetails = "";

      // If error is null, list is guaranteed to be not empty.
      for (Place geocodingResult in list!) {
        // Note: getGeoCoordinates() may return null only for Suggestions.
        GeoCoordinates geoCoordinates = geocodingResult.geoCoordinates!;
        Address address = geocodingResult.address;
        locationDetails = address.addressText +
            ". GeoCoordinates: " +
            geoCoordinates.latitude.toString() +
            ", " +
            geoCoordinates.longitude.toString();

        print(locationDetails);

        var contains = locations
            .where((element) => element.title == address.addressText);

        if (contains.isEmpty) {
          locations.add((AddLocation(
              title: address.addressText,
              coordinates: geoCoordinates)));
        }

        metadata.setCustomValue("key_search_result",
            SearchResultMetadata(geocodingResult));
        await AddMarkers().addPoiMapMarker(hereMapController, geoCoordinates,
            metadata, selectedIndex, mapMarkerList);
      }

      Messages().toastMessage("Results obtained");
    });
  }
}