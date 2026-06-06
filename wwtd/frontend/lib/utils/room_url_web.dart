import 'package:web/web.dart' as web;

void replaceRoomInUrlImpl(String roomId, {bool retry = true}) {
  _replaceRoomInUrl(roomId);
  if (!retry) {
    return;
  }
  Future<void>.delayed(const Duration(milliseconds: 250), () {
    _replaceRoomInUrl(roomId);
  });
}

void _replaceRoomInUrl(String roomId) {
  final Uri current = Uri.base;
  if (current.queryParameters['room'] == roomId) {
    return;
  }
  final Uri next = current.replace(
    queryParameters: <String, String>{'room': roomId},
    fragment: '',
  );
  web.window.history.replaceState(null, web.document.title, next.toString());
}
