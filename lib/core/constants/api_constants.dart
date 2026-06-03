import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";
    }
    // Connect to the computer's current local Wi-Fi IP address
    return "http://192.168.2.62:5000";
  }

  static String get login => "$baseUrl/api/users/login";
  static String get register => "$baseUrl/api/users/register";
}
