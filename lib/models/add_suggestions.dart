import 'package:here_sdk/core.dart';

class AddSuggestion {
  String title;
  String address;
  GeoCoordinates coordinates;

  AddSuggestion(
      {required this.title, required this.address, required this.coordinates});
}