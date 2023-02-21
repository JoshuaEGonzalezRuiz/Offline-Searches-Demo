import 'package:fluttertoast/fluttertoast.dart';
import 'package:offline_navigation_routes/values/colors.dart';

class Messages {
  void toastMessage(String message) async {
    await Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: general_background_color,
        textColor: description_color,
        fontSize: 16.0);
  }
}