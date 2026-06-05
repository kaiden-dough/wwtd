import 'package:flutter/material.dart';

void showAppSnackBar(BuildContext context, SnackBar snackBar) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger
    ..clearSnackBars()
    ..showSnackBar(snackBar);
}
