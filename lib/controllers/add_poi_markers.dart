import 'package:flutter/services.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/mapview.dart';

class AddMarkers {
  MapImage? poiMapImage;

  Future<void> addPoiMapMarker(
      HereMapController hereMapController,
      GeoCoordinates? geoCoordinates,
      Metadata metadata,
      int selectedIndex,
      List<MapMarker?> mapMarkerList) async {
    MapMarker mapMarker = await _addPoiMapMarker(
        hereMapController, geoCoordinates!, selectedIndex, mapMarkerList);
    mapMarker.metadata = metadata;

    //setState(() => _needSearch = false);
  }

  Future<MapMarker> _addPoiMapMarker(
      HereMapController hereMapController,
      GeoCoordinates geoCoordinates,
      int selectedIndex,
      List<MapMarker?> mapMarkerList) async {
    String poiImage = selectedIndex == 0
        ? 'place_marker_64px.png'
        : selectedIndex == 1
            ? 'suggestion_64px.png'
            : selectedIndex == 3
                ? 'address_location_marker_64px.png'
                : 'location_marker_64px.png';

    Uint8List imagePixelData = await loadFileAsUint8List(poiImage);
    poiMapImage =
        MapImage.withPixelDataAndImageFormat(imagePixelData, ImageFormat.png);

    MapMarker mapMarker = MapMarker(geoCoordinates, poiMapImage!);
    hereMapController.mapScene.addMapMarker(mapMarker);
    mapMarkerList.add(mapMarker);

    return mapMarker;
  }

  Future<Uint8List> loadFileAsUint8List(String fileName) async {
    // The path refers to the assets directory as specified in pubspec.yaml.
    ByteData fileData = await rootBundle.load('assets/' + fileName);
    return Uint8List.view(fileData.buffer);
  }
}
