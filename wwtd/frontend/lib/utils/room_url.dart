import 'room_url_stub.dart' if (dart.library.js_interop) 'room_url_web.dart';

void replaceRoomInUrl(String roomId, {bool retry = true}) =>
    replaceRoomInUrlImpl(roomId, retry: retry);
