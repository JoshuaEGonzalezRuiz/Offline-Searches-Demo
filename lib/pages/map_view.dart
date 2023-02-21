import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:here_sdk/core.dart';
import 'package:here_sdk/core.engine.dart';
import 'package:here_sdk/core.errors.dart';
import 'package:here_sdk/gestures.dart';
import 'package:here_sdk/maploader.dart';
import 'package:here_sdk/mapview.dart';
import 'package:here_sdk/search.dart';
import 'package:offline_navigation_routes/controllers/find_places.dart';
import 'package:offline_navigation_routes/controllers/geocode_address.dart';
import 'package:offline_navigation_routes/controllers/get_auto_suggestions.dart';
import 'package:offline_navigation_routes/controllers/messages.dart';
import 'package:offline_navigation_routes/controllers/reverse_geocode.dart';
import 'package:offline_navigation_routes/models/add_location.dart';
import 'package:offline_navigation_routes/models/add_suggestions.dart';
import 'package:offline_navigation_routes/values/colors.dart';
import 'package:offline_navigation_routes/values/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MyMapViewPage extends StatefulWidget {
  const MyMapViewPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyMapViewPage> createState() => _MyMapViewPageState();
}

class _MyMapViewPageState extends State<MyMapViewPage> {
  HereMapController? _hereMapController;
  SDKNativeEngine? sdkNativeEngine = SDKNativeEngine.sharedInstance;
  late MapDownloader _mapDownloader;
  late MapUpdater _mapUpdater;
  OfflineSearchEngine? _offlineSearchEngine;
  List<Region> _downloadableRegions = [];
  final List<MapDownloaderTask> _mapDownloaderTasks = [];
  final List<CatalogUpdateTask> _mapUpdateTasks = [];
  final double _distanceToEarthInMeters = 150000;
  GeoCoordinates? _defaultCoordinates;

  late SharedPreferences devicePrefs;
  bool hasOfflineData = false;
  bool hasRegions = false;
  bool isDownloading = false;
  bool expanded = false;
  late List<Region> childRegions;
  String downloadText = "";
  String countryName = "";
  String placeName = "";

  final _searchPlacesController = TextEditingController();
  final List<MapMarker> _mapMarkerList = [];
  int _selectedIndex = 0;

  final List<AddSuggestion> _suggestions = [];
  final List<AddLocation> _locations = [];
  final List<MapPolyline> _mapPolylines = [];

  GeoCoordinates? _valueSuggestion;

  bool _needSearch = false;

  String titlePage = '';

  final FindPlaces _findPlaces = FindPlaces();
  final GetAutosuggestions _getAutosuggestions = GetAutosuggestions();
  final GeocodeAddress _geocodeAddress = GeocodeAddress();
  final ReverseGeocode _reverseGeocode = ReverseGeocode();

  @override
  void initState() {
    if (sdkNativeEngine == null) {
      throw ("SDKNativeEngine not initialized.");
    }

    MapDownloader.fromSdkEngineAsync(sdkNativeEngine!, (mapDownloader) {
      _mapDownloader = mapDownloader;

      MapUpdater.fromSdkEngineAsync(sdkNativeEngine!, (mapUpdater) {
        _mapUpdater = mapUpdater;

        checkKeys();
      });
    });


    setState(() => titlePage = '${widget.title} - Places');
    super.initState();
  }

  void _onItemTapped(int index) {
    _clearAll(index);
    switch (index) {
      case 0:
        setState(() => titlePage = '${widget.title} - $places');
        Messages().toastMessage(placesDescription);
        break;
      case 1:
        setState(() => titlePage = '${widget.title} - $autoSuggestions');
        Messages().toastMessage(autoSuggestDescription);
        break;
      case 2:
        setState(() => titlePage = '${widget.title} - $revGeocode');
        Messages().toastMessage(revGeoDescription);
        break;
      case 3:
        setState(() => titlePage = '${widget.title} - $geocode');
        Messages().toastMessage(geoDescription);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: background_color,
        appBar: AppBar(
          title: Text(
            hasOfflineData
                ? widget.title
                : hasRegions
                    ? title_download
                    : "",
            style: const TextStyle(color: general_color),
          ),
          backgroundColor: general_background_color,
          actions: [
            hasOfflineData
                ? IconButton(
                    onPressed: () {
                      _showDialogs("Info", info_erase_message, "b");
                    },
                    icon: const Icon(
                      Icons.find_replace,
                      color: general_color,
                    ))
                : IconButton(
                    onPressed: () {
                      _showDialogs("Info", info_connection_message, "i");
                    },
                    icon: const Icon(
                      Icons.info,
                      color: general_color,
                    ))
          ],
        ),
        body: Center(
          child: isDownloading
              ? Container(
              padding: EdgeInsets.all(16),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                        child: SizedBox(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              backgroundColor: Colors.transparent,
                              color: general_color,
                            ),
                            width: 32,
                            height: 32),
                        padding: EdgeInsets.only(bottom: 16)),
                    const Padding(
                        child: Text(
                          'Please wait …',
                          style: TextStyle(
                              color: Colors.white, fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        padding: EdgeInsets.only(top: 10, bottom: 10)),
                    Text(
                      downloadText,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    )
                  ]))
              : hasOfflineData
                  ? Stack(
                      children: [
                        HereMap(onMapCreated: _onMapCreated),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _selectedIndex == 2 || _selectedIndex == 4
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: general_background_color,
                                      border: Border.all(
                                          color:
                                              subgeneral_color, // set border color
                                          width: 2.0), // set border width
                                      borderRadius: BorderRadius.circular(
                                          15.0), // set rounded corner radius
                                    ),
                                    margin: const EdgeInsets.all(10),
                                    width: MediaQuery.of(context).size.width *
                                        0.80,
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.info,
                                        color: description_color,
                                      ),
                                      contentPadding: const EdgeInsets.fromLTRB(
                                          10.0, 5.0, 0.0, 10.0),
                                      title: Transform(
                                        transform: Matrix4.translationValues(
                                            -16, 0.0, 0.0),
                                        child: const Text(
                                          tapMessage,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: general_color,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color:
                                              Colors.black, // set border color
                                          width: 2.0), // set border width
                                      borderRadius: BorderRadius.circular(
                                          15.0), // set rounded corner radius
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        15.0, 0.0, 15.0, 0.0),
                                    margin: const EdgeInsets.all(20),
                                    width: MediaQuery.of(context).size.width *
                                        0.90,
                                    child: TextField(
                                      controller: _searchPlacesController,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.all(12.0),
                                        suffixIcon: const Icon(Icons.search),
                                        //label: Text('Search box'),
                                        hintText: _selectedIndex == 0
                                            ? placeHint
                                            : _selectedIndex == 1
                                                ? autoSuggestHint
                                                : _selectedIndex == 3
                                                    ? geocodeHint
                                                    : '',
                                        border: InputBorder.none,
                                      ),
                                      onSubmitted: (enter) {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      onChanged: (value) async {
                                        if (_needSearch == false) {
                                          setState(
                                              () => _needSearch = !_needSearch);
                                        }

                                        if (_selectedIndex == 0) {
                                          await _clearMap().whenComplete(() {
                                            _findPlaces
                                                .searchPlaces(
                                                    _searchPlacesController,
                                                    _hereMapController!,
                                                    _defaultCoordinates!,
                                                    _distanceToEarthInMeters,
                                                    _needSearch,
                                                    _offlineSearchEngine!,
                                                    _selectedIndex,
                                                    _mapMarkerList,
                                                    _suggestions)
                                                .whenComplete(() {
                                              setState(
                                                  () => _needSearch = false);
                                            });
                                          });
                                        }

                                        if (_selectedIndex == 1) {
                                          await _clearMap().whenComplete(() {
                                            _getAutosuggestions
                                                .searchAutoSuggestion(
                                                    _hereMapController!,
                                                    _needSearch,
                                                    _offlineSearchEngine!,
                                                    _searchPlacesController,
                                                    _suggestions,
                                                    _selectedIndex,
                                                    _mapMarkerList);
                                          });
                                        }

                                        if (_selectedIndex == 3) {
                                          await _clearMap().whenComplete(() {
                                            _geocodeAddress.searchLocations(
                                                _hereMapController!,
                                                _searchPlacesController,
                                                _defaultCoordinates!,
                                                _offlineSearchEngine!,
                                                _locations,
                                                _selectedIndex,
                                                _mapMarkerList);
                                          });
                                        }
                                      },
                                      onEditingComplete: () {},
                                      onTap: () {
                                        _searchPlacesController.text = '';
                                        _clearMap();
                                      },
                                    ),
                                  ),
                            _suggestions.isNotEmpty || _locations.isNotEmpty
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color:
                                              Colors.black, // set border color
                                          width: 2.0), // set border width
                                      borderRadius: BorderRadius.circular(
                                          15.0), // set rounded corner radius
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        15.0, 0.0, 15.0, 0.0),
                                    width: MediaQuery.of(context).size.width *
                                        0.90,
                                    child: _suggestions.isNotEmpty &&
                                            _searchPlacesController
                                                .text.isNotEmpty
                                        ? Container(
                                            height: 220.00,
                                            padding: const EdgeInsets.all(10.0),
                                            child: ListView.builder(
                                                itemCount: _suggestions.length,
                                                itemBuilder:
                                                    (BuildContext context,
                                                        int index) {
                                                  return ListTile(
                                                    title: Text(
                                                        _suggestions[index]
                                                            .title),
                                                    onTap: () {
                                                      setState(() {
                                                        _valueSuggestion =
                                                            _suggestions[index]
                                                                .coordinates;
                                                        _suggestions.clear();
                                                      });

                                                      _hereMapController!.camera
                                                          .lookAtPointWithDistance(
                                                              _valueSuggestion!,
                                                              _distanceToEarthInMeters);
                                                    },
                                                  );
                                                }))
                                        : _locations.isNotEmpty &&
                                                _searchPlacesController
                                                    .text.isNotEmpty
                                            ? Container(
                                                height: 220.00,
                                                padding:
                                                    const EdgeInsets.all(10.0),
                                                child: ListView.builder(
                                                    itemCount:
                                                        _locations.length,
                                                    itemBuilder:
                                                        (BuildContext context,
                                                            int index) {
                                                      return ListTile(
                                                        title: Text(
                                                            _locations[index]
                                                                .title),
                                                        onTap: () {
                                                          setState(() {
                                                            _valueSuggestion =
                                                                _locations[
                                                                        index]
                                                                    .coordinates;
                                                            _locations.clear();
                                                          });

                                                          _hereMapController!
                                                              .camera
                                                              .lookAtPointWithDistance(
                                                                  _valueSuggestion!,
                                                                  _distanceToEarthInMeters);
                                                        },
                                                      );
                                                    }))
                                            : null)
                                : Container(),
                          ],
                        )
                      ],
                    )
                  : hasRegions
                      ? Padding(
                          padding: const EdgeInsets.all(10.00),
                          child: ListView.builder(
                              itemCount: childRegions.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  color: general_background_color,
                                  shape: RoundedRectangleBorder(
                                    side: const BorderSide(
                                        color: regionsTextTileColor, width: 1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ExpansionTile(
                                    textColor: regionsTileColor,
                                    iconColor: regionsTileColor,
                                    collapsedTextColor: regionsTextTileColor,
                                    collapsedIconColor: regionsTextTileColor,
                                    leading: const Icon(Icons.travel_explore),
                                    title: Text(childRegions[index].name),
                                    subtitle: Text(
                                        'Regions: ${childRegions[index].childRegions!.length}'),
                                    children: <Widget>[
                                      Column(
                                          children: buildChildRegion(
                                              childRegions[index].childRegions))
                                    ],
                                  ),
                                );
                              }),
                        )
                      : const CircularProgressIndicator(
                          color: general_color,
                        ),
        ),
        extendBody: true,
        bottomNavigationBar: hasOfflineData
            ? Container(
                margin: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 15.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38, spreadRadius: 0, blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: BottomNavigationBar(
                    iconSize: 26,
                    showSelectedLabels: false,
                    showUnselectedLabels: false,
                    type: BottomNavigationBarType.fixed,
                    selectedFontSize: 0,
                    items: const <BottomNavigationBarItem>[
                      BottomNavigationBarItem(
                        icon: Icon(Icons.place),
                        label: places,
                        backgroundColor: general_background_color,
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.not_listed_location),
                        label: autoSuggestions,
                        backgroundColor: general_background_color,
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.youtube_searched_for),
                        label: revGeocode,
                        backgroundColor: general_background_color,
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.terrain),
                        label: geocode,
                        backgroundColor: general_background_color,
                      ),
                    ],
                    currentIndex: _selectedIndex,
                    selectedItemColor: general_color,
                    unselectedItemColor: description_color,
                    backgroundColor: general_background_color,
                    onTap: _onItemTapped,
                  ),
                ),
              )
            : null);
  }

  buildChildRegion(List<Region>? regions) {
    List<Widget> columnContent = [];

    for (Region content in regions!) {
      columnContent.add(content.childRegions != null
          ? Card(
              margin: const EdgeInsets.all(10.0),
              color: general_background_color,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: subRegionsColor, width: 1),
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              child: ExpansionTile(
                textColor: subTextRegionsColor,
                iconColor: subTextRegionsColor,
                collapsedTextColor: subRegionsColor,
                collapsedIconColor: subRegionsColor,
                leading: const Icon(Icons.flag),
                title: Text(content.name),
                onExpansionChanged: (ev) {
                  setState(() {
                    countryName = content.name;
                  });
                },
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Sub regions: ${content.childRegions!.length}'),
                    IconButton(
                        onPressed: () {
                          print('Name: ' +
                              content.name +
                              ' Region id: ' +
                              content.regionId.id.toString());
                          onDownloadMapClicked(content.name, content.regionId);
                        },
                        color: buttonDownloadColor,
                        icon: const Icon(Icons.cloud_download))
                  ],
                ),
                children: <Widget>[
                  Column(children: buildSubChildRegion(content.childRegions))
                ],
              ),
            )
          : Card(
              margin: const EdgeInsets.all(10.0),
              color: general_background_color,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: subRegionsColor, width: 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.flag,
                  color: subRegionsColor,
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        content.name,
                        style: const TextStyle(color: subRegionsColor),
                      ),
                    ),
                    IconButton(
                        onPressed: () {
                          if (countryName.isNotEmpty) {
                            setState(() => countryName = "");
                          }
                          onDownloadMapClicked(content.name, content.regionId);
                        },
                        color: buttonDownloadColor,
                        icon: const Icon(Icons.cloud_download))
                  ],
                ),
              ),
            ));
    }
    return columnContent;
  }

  buildSubChildRegion(List<Region>? subRegions) {
    List<Widget> columnContent = [];
    for (Region content in subRegions!) {
      columnContent.add(Card(
        margin: const EdgeInsets.all(10.0),
        color: general_background_color,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: subSubRegionColor.withOpacity(0.6), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: const Icon(
            Icons.location_city,
            color: subSubRegionColor,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                content.name,
                style: const TextStyle(color: subSubRegionColor),
              ),
              IconButton(
                  onPressed: () {
                    onDownloadMapClicked(content.name, content.regionId);
                    //print(content.regionId.id);
                  },
                  color: buttonDownloadColor,
                  icon: const Icon(Icons.cloud_download))
            ],
          ),
        ),
      ));
    }
    return columnContent;
  }

  void _onMapCreated(HereMapController hereMapController) {
    _hereMapController = hereMapController;
    hereMapController.mapScene.loadSceneForMapScheme(MapScheme.normalDay,
        (MapError? error) {
      if (error != null) {
        print('Map scene not loaded. MapError: ${error.toString()}');
        return;
      }

      _checkInstallationStatus();
    });
  }

  setMapFlagDataValue(String key, bool value) async {
    devicePrefs = await SharedPreferences.getInstance();
    devicePrefs.setBool(key, value);
  }

  setPlaceNameValue(String key, String value) async {
    devicePrefs = await SharedPreferences.getInstance();
    devicePrefs.setString(key, value);
  }

  Future<bool> getMapFlagDataValue(String key) async {
    devicePrefs = await SharedPreferences.getInstance();
    return devicePrefs.getBool(key) ?? false;
  }

  Future<String> getPlaceNameValue(String key) async {
    devicePrefs = await SharedPreferences.getInstance();
    return devicePrefs.getString(key) ?? "";
  }

  Future<bool> containsKey(String key) async {
    devicePrefs = await SharedPreferences.getInstance();
    return devicePrefs.containsKey(key);
  }

  Future<void> checkKeys() async {
    bool hasKey = await containsKey('hasOfflineMapData');
    bool hasPlaceName = await containsKey('placeName');
    bool hasRegionCoords = await containsKey('hasRegionCoords');

    if (hasKey && hasPlaceName && hasRegionCoords) {
      bool checkOfflineData = await getMapFlagDataValue('hasOfflineMapData');
      String checkPlaceName = await getPlaceNameValue('placeName');
      String checkRegionCoords = await getPlaceNameValue('hasRegionCoords');

      if (checkOfflineData &&
          checkPlaceName.isNotEmpty &&
          checkRegionCoords.isNotEmpty) {
        setState(() {
          hasOfflineData = checkOfflineData;
          placeName = checkPlaceName;
          var coords = checkRegionCoords.split(",");
          double? lat = double.tryParse(coords[0]);
          double? lng = double.tryParse(coords[1]);
          _defaultCoordinates = GeoCoordinates(lat!, lng!);
        });
      } else {
        getRegionsList();
      }
    } else {
      await setMapFlagDataValue('hasOfflineMapData', hasOfflineData);
      await setPlaceNameValue('placeName', placeName);
      getRegionsList();
    }
  }

  void _showDialogs(String title, String message, String option) {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: general_background_color,
            title: Text(
              title,
              style: const TextStyle(color: general_color),
            ),
            content: Text(
              option == 'e' ? "$error_connection_message\n$message" : message,
              style: const TextStyle(color: description_color),
            ),
            actions: [
              option == 'e'
                  ? const Text("")
                  : TextButton(
                      onPressed: () {
                        if (option == 'b') {
                          deleteMapData();
                        }

                        _dismissDialog();
                      },
                      child: Text(
                        option == 'i' ? 'Close' : 'Ok',
                        style: const TextStyle(color: general_color),
                      )),
              option == 'b'
                  ? TextButton(
                      onPressed: () {
                        _dismissDialog();
                      },
                      child: const Text(
                        'Close',
                        style: TextStyle(color: general_color),
                      ))
                  : const Text("")
            ],
          );
        });
  }

  _dismissDialog() {
    Navigator.pop(context);
  }

  deleteMapData() {
    _clearMap();

    _mapDownloader.clearPersistentMapStorage((p0) {
      setState(() {
        hasOfflineData = false;
        placeName = "";
        hasRegions = false;
        _defaultCoordinates = null;
      });

      setMapFlagDataValue('hasOfflineMapData', hasOfflineData);
      setPlaceNameValue('placeName', placeName);
      setPlaceNameValue('hasRegionCoords', "");

      checkKeys();
    });
  }

  Future<void> getRegionsList() async {
    print("Downloading the list of available regions.");

    _mapDownloader.getDownloadableRegionsWithLanguageCode(LanguageCode.enUs,
        (MapLoaderError? mapLoaderError, List<Region>? list) {
      if (mapLoaderError != null) {
        _showDialogs("Error", mapLoaderError.toString(), "e");
        return;
      }

      // If error is null, it is guaranteed that the list will not be null.
      _downloadableRegions = list!;

      setState(() {
        childRegions = _downloadableRegions;
        hasRegions = true;
      });
    });
  }

  Future<void> onDownloadMapClicked(String name, RegionId selection) async {
    // For this example we download only one country.
    List<RegionId> regionIDs = [selection];

    setState(() {
      isDownloading = !isDownloading;
    });

    MapDownloaderTask mapDownloaderTask = _mapDownloader.downloadRegions(
        regionIDs,
        DownloadRegionsStatusListener(
            (MapLoaderError? mapLoaderError, List<RegionId>? list) {
          // Handle events from onDownloadRegionsComplete().
          if (mapLoaderError != null) {
            _showDialogs("Error", mapLoaderError.toString(), "e");
            return;
          }

          // If error is null, it is guaranteed that the list will not be null.
          // For this example we downloaded only one hardcoded region.
          String message =
              "Download Regions Status: Completed $name 100% for ID: " +
                  list!.first.id.toString();
          print(message);
        }, (RegionId regionId, int percentage) {
          // Handle events from onProgress().
          String message =
              "Downloading ${countryName.isNotEmpty ? name + ', ' + countryName : name}." +
                  "\n Progress: " +
                  percentage.toString() +
                  "%.";

          if (percentage == 100) {
            setState(() {
              downloadText = "";
              isDownloading = !isDownloading;
              hasOfflineData = true;
              setMapFlagDataValue('hasOfflineMapData', hasOfflineData);
              placeName = countryName != "" ? name + ', ' + countryName : name;
              setPlaceNameValue('placeName', placeName);

              if (_defaultCoordinates != null) {
                _hereMapController!.camera.lookAtPointWithDistance(
                    _defaultCoordinates!, _distanceToEarthInMeters);
                Future.delayed(const Duration(seconds: 5),
                        () => _initializeOfflineSearchingEngine());
              } else {
                searchPlaceId(placeName);
              }
            });
          } else {
            setState(() {
              downloadText = message;
            });
          }
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onPause().
          if (mapLoaderError == null) {
            //_showDialog("Info", "The download was paused by the user calling mapDownloaderTask.pause().");
            print(
                "The download was paused by the user calling mapDownloaderTask.pause().");
          } else {
            //_showDialog("Error",
            //"Download regions onPause error. The task tried to often to retry the download: $mapLoaderError");
            print(
                "Download regions onPause error. The task tried to often to retry the download: $mapLoaderError");
          }
        }, () {
          // Hnadle events from onResume().
          //_showDialog("Info", "A previously paused download has been resumed.");
          print("A previously paused download has been resumed.");
        }));

    _mapDownloaderTasks.add(mapDownloaderTask);
  }

  _checkInstallationStatus() {

    // Note that this value will not change during the lifetime of an app.
    PersistentMapStatus persistentMapStatus =
    _mapDownloader.getInitialPersistentMapStatus();
    if (persistentMapStatus == PersistentMapStatus.corrupted ||
        persistentMapStatus == PersistentMapStatus.migrationNeeded) {
      // Something went wrong after the app was closed the last time. It seems the offline map data is
      // corrupted. This can eventually happen, when an ongoing map download was interrupted due to a crash.
      print(
          "PersistentMapStatus: The persistent map data seems to be corrupted. Trying to repair.");

      // Let's try to repair.
      _mapDownloader.repairPersistentMap(
              (PersistentMapRepairError? persistentMapRepairError) {
            if (persistentMapRepairError == null) {
              print(
                  "RepairPersistentMap: Repair operation completed successfully!");

              _checkInstallationStatus();
              return;
            }

            print(
                "RepairPersistentMap: Repair operation failed: $persistentMapRepairError");
          });
    } else if (persistentMapStatus == PersistentMapStatus.invalidPath) {
      //Pending
    } else if (persistentMapStatus == PersistentMapStatus.invalidState) {
      _mapDownloader
          .clearPersistentMapStorage((MapLoaderError? mapLoaderError) {
        if (mapLoaderError == null) {
          print(
              "ClearPersistentMapStorage: Cleaning operation completed successfully!");

          _checkInstallationStatus();
          return;
        }

        print(
            "ClearPersistentMapStorage: Cleaning operation failed: $mapLoaderError");
      });
    } else if (persistentMapStatus == PersistentMapStatus.pendingUpdate) {
      _checkForMapUpdates();
    } else if (persistentMapStatus == PersistentMapStatus.ok) {
      //_getDownloadableRegions();
    }
  }

  void _checkForMapUpdates() {
    _mapUpdater
        .retrieveCatalogsUpdateInfo((mapLoaderError, catalogUpdateInfoList) {
      if (mapLoaderError != null) {
        _showDialogs("Error", mapLoaderError.toString(), "e");
        return;
      }

      if (catalogUpdateInfoList!.isEmpty) {
        print(
            "MapUpdateCheck: No map update available. Latest versions are already installed.");

        _checkInstallationStatus();
      }

      // Usually, only one global catalog is available that contains regions for the whole world.
      // For some regions like Japan only a base map is available, by default.
      // If your company has an agreement with HERE to use a detailed Japan map, then in this case you
      // can install and use a second catalog that references the detailed Japan map data.
      // All map data is part of downloadable regions. A catalog contains references to the
      // available regions. The map data for a region may differ based on the catalog that is used
      // or on the version that is downloaded and installed.
      for (CatalogUpdateInfo catalogUpdateInfo in catalogUpdateInfoList) {
        print(
            "CatalogUpdateCheck - Catalog name:${catalogUpdateInfo.installedCatalog.catalogIdentifier.hrn}");
        print(
            "CatalogUpdateCheck - Installed map version:${catalogUpdateInfo.installedCatalog.catalogIdentifier.version}");
        print(
            "CatalogUpdateCheck - Latest available map version:${catalogUpdateInfo.latestVersion}");

        if (_mapUpdateTasks.isEmpty) {
          setState(() {
            isDownloading = true;
          });

          _performMapUpdate(catalogUpdateInfo);
        }
      }
    });
  }

  // Downloads and installs map updates for any of the already downloaded regions.
  // Note that this example only shows how to download one region.
  void _performMapUpdate(CatalogUpdateInfo catalogUpdateInfo) {
    // This method conveniently updates all installed regions if an update is available.
    // Optionally, you can use the MapUpdateTask to pause / resume or cancel the update.
    setState(() {
      isDownloading = !isDownloading;
    });

    CatalogUpdateTask mapUpdateTask = _mapUpdater.updateCatalog(
        catalogUpdateInfo,
        CatalogUpdateProgressListener((RegionId regionId, int percentage) {
          // Handle events from onProgress().
          print(
              "MapUpdate: Downloading and installing a map update. Progress for ${regionId.id}: $percentage%.");

          if (percentage == 100) {
            setState(() {
              downloadText = "";
              isDownloading = !isDownloading;
            });
            if (_defaultCoordinates != null) {
              _hereMapController!.camera.lookAtPointWithDistance(
                  _defaultCoordinates!, _distanceToEarthInMeters);
              Future.delayed(const Duration(seconds: 5),
                      () => _initializeOfflineSearchingEngine());
            } else {
              searchPlaceId(placeName);
            }
          } else {
            setState(() {
              downloadText =
              "Downloading and installing a map update for $placeName: $percentage%.";
            });
          }
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onPause().
          if (mapLoaderError == null) {
            print(
                "MapUpdate:  The map update was paused by the user calling mapUpdateTask.pause().");
            setState(() {
              isDownloading = !isDownloading;
            });
          } else {
            setState(() {
              isDownloading = !isDownloading;
              _mapUpdateTasks.clear();
            });

            return;
          }
        }, (MapLoaderError? mapLoaderError) {
          // Handle events from onComplete().
          if (mapLoaderError != null) {
            _showDialogs("Error", mapLoaderError.toString(), "e");
            setState(() {
              isDownloading = !isDownloading;
              _mapUpdateTasks.clear();
            });
            return;
          }
          print(
              "MapUpdate: One or more map update has been successfully installed.");

          _checkInstallationStatus();

          // It is recommend to call now also `getDownloadableRegions()` to update
          // the internal catalog data that is needed to download, update or delete
          // existing `Region` data. It is required to do this at least once
          // before doing a new download, update or delete operation.
        }, () {
          // Handle events from onResume():
          print("MapUpdate: A previously paused map update has been resumed.");
        }));

    _mapUpdateTasks.add(mapUpdateTask);
  }

  Future<void> searchPlaceId(String place) async {
    print(place);

    var url = Uri.parse(
        "https://autocomplete.search.hereapi.com/v1/autocomplete?apiKey=$YOUR_API_KEY&q=$place");

    var result = await http.get(url).then((http.Response response) {
      final String res = response.body;
      final int statusCode = response.statusCode;

      if (statusCode < 200 || statusCode > 400) {
        throw Exception("Error while fetching data");
      }
      return jsonDecode(res);
    });

    print(result);

    print("${result["items"][0]["id"]}");

    String? placeId = "${result["items"][0]["id"]}";

    await searchPlaceCoords(placeId);

    //_hereMapController!.camera.lookAtPointWithDistance(GeoCoordinates(lat!, lng!), 250000);
  }

  Future<void> searchPlaceCoords(String placeId) async {
    print(placeId);

    var url = Uri.parse(
        "https://lookup.search.hereapi.com/v1/lookup?apiKey=$YOUR_API_KEY&id=$placeId");

    var result = await http.get(url).then((http.Response response) {
      final String res = response.body;
      final int statusCode = response.statusCode;

      if (statusCode < 200 || statusCode > 400) {
        throw Exception("Error while fetching data");
      }
      return jsonDecode(res);
    });

    print(result);

    print("${result["position"]["lat"]}, ${result["position"]["lng"]}");

    double? lat = result["position"]["lat"];
    double? lng = result["position"]["lng"];

    setState(() {
      _defaultCoordinates = GeoCoordinates(lat!, lng!);
      setPlaceNameValue('hasRegionCoords',
          "${_defaultCoordinates!.latitude},${_defaultCoordinates!.longitude}");
    });

    _hereMapController!.camera.lookAtPointWithDistance(
        _defaultCoordinates!, _distanceToEarthInMeters);

    Future.delayed(
        const Duration(seconds: 5), () => _initializeOfflineSearchingEngine());
  }

  void _setTapGestureHandler() async {
    _hereMapController!.gestures.tapListener =
        TapListener((Point2D touchPoint) async {
      //_selectedIndex <= 1 ? FocusManager.instance.primaryFocus?.unfocus() : setMarker(touchPoint);
      if (_selectedIndex <= 1 || _selectedIndex == 3) {
        FocusManager.instance.primaryFocus?.unfocus();
      } else {
        if (_selectedIndex == 2) {
          Messages().toastMessage("Getting information");
          await _reverseGeocode.setMarker(
              touchPoint, _hereMapController!, _offlineSearchEngine!, context);
        }
      }
    });
  }

  void _initializeOfflineSearchingEngine() {
    try {
      _offlineSearchEngine = OfflineSearchEngine();

      Future.delayed(const Duration(seconds: 5), () {
        _setTapGestureHandler();
      });
    } on InstantiationException {
      throw ("Initialization of OfflineSearchEngine failed.");
    }
  }

  Future<void> _clearMap() async {
    /*for (var mapMarker in _mapMarkerList) {
      _hereMapController!.mapScene.removeMapMarker(mapMarker);
    }*/
    _hereMapController!.mapScene.removeMapMarkers(_mapMarkerList);
    setState(() {
      _mapMarkerList.clear();
      _valueSuggestion = null;
      _suggestions.clear();
      _locations.clear();
      _mapPolylines.isNotEmpty
          ? _hereMapController!.mapScene.removeMapPolyline(_mapPolylines[0])
          : null;
      _mapPolylines.clear();
    });
    _hereMapController!.camera.lookAtPointWithDistance(
        _defaultCoordinates!, _distanceToEarthInMeters);
  }

  void _clearAll(index) {
    setState(() {
      _selectedIndex = index;
      _searchPlacesController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      _clearMap();
    });
  }
}
