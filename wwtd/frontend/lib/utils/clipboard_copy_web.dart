// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/services.dart';

Future<bool> copyTextToClipboardImpl(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  final ClipboardData? copied = await Clipboard.getData('text/plain');
  if (copied?.text == text) {
    return true;
  }

  try {
    await html.window.navigator.clipboard?.writeText(text);
    return true;
  } catch (_) {
    return _copyWithHiddenInput(text);
  }
}

bool _copyWithHiddenInput(String text) {
  final html.TextAreaElement textarea = html.TextAreaElement()
    ..value = text
    ..style.position = 'fixed'
    ..style.left = '-1000px'
    ..style.top = '-1000px';
  html.document.body?.append(textarea);
  textarea
    ..focus()
    ..select();
  final bool copied = html.document.execCommand('copy');
  textarea.remove();
  return copied;
}
