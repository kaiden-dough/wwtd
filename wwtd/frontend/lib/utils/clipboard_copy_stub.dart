import 'package:flutter/services.dart';

Future<bool> copyTextToClipboardImpl(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  final ClipboardData? copied = await Clipboard.getData('text/plain');
  return copied?.text == text;
}
