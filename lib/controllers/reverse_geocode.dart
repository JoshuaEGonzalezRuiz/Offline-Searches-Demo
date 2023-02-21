import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';
import 'package:offline_navigation_routes/values/colors.dart';

class ReverseGeocode {
  MapMarker? reverseMarker;

  Future<void> setMarker(Point2D touchPoint, HereMapController hereMapController,
      OfflineSearchEngine searchEngine, BuildContext context) async {

    if (reverseMarker == null) {
      MapImage? geocodeMarker;
      GeoCoordinates? tapCoordinates =
      hereMapController.viewToGeoCoordinates(touchPoint);

      if (geocodeMarker == null) {
        Uint8List imagePixelData =
        await _loadFileAsUint8List('assets/location_marker_64px.png');
        geocodeMarker = MapImage.withPixelDataAndImageFormat(
            imagePixelData, ImageFormat.png);
      }

      reverseMarker = MapMarker(tapCoordinates!, geocodeMarker);

      hereMapController.mapScene.addMapMarker(reverseMarker!);
      _getAddressForCoordinates(tapCoordinates,hereMapController, searchEngine, context);
    }
  }

  Future<Uint8List> _loadFileAsUint8List(String assetPathToFile) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load(assetPathToFile);
    return Uint8List.view(fileData.buffer);
  }

  Future<void> _getAddressForCoordinates(GeoCoordinates geoCoordinates,
      HereMapController hereMapController, OfflineSearchEngine searchEngine,
      BuildContext context) async {
    String addressText = '';
    int maxItems = 1;
    SearchOptions reverseGeocodingOptions =
    SearchOptions();
    reverseGeocodingOptions.languageCode = LanguageCode.enUs;
    reverseGeocodingOptions.maxItems = maxItems;

    searchEngine.searchByCoordinates(geoCoordinates, reverseGeocodingOptions,
            (SearchError? searchError, List<Place>? list) {
          if (searchError != null) {
            //print("Reverse geocoding Error: " + searchError.toString());
            addressText = 'Error: ' + searchError.toString();
            return;
          }

          // If error is null, list is guaranteed to be not empty.
          //print("Reverse geocoded address:" + list!.first.address.addressText);

          addressText = list!.first.address.addressText;
          _showResultRevGeocodeDialog('Reverse geocode result', addressText,
              hereMapController, context);
          return;
        });
  }

  Future<void> _showResultRevGeocodeDialog(String title, String message,
     HereMapController hereMapController, BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(
                color: description_color,
                fontSize: 24,
                fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: const TextStyle(
                color: general_color,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          backgroundColor: general_background_color.withOpacity(0.52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(35)),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'OK',
                style: TextStyle(
                    color: description_color, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                hereMapController.mapScene.removeMapMarker(reverseMarker!);
                  reverseMarker = null;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}