import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Toast
void toastMsg(String msg) {
  if (!kIsWeb) {
    if (!Platform.isMacOS) {
      if (!Platform.isWindows) {
        Fluttertoast.showToast(
          msg: msg,
          toastLength: Toast.LENGTH_LONG,
          timeInSecForIosWeb: 1,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    }
  }
}
