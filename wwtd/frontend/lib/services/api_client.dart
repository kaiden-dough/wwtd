import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wwtd/config/api_config.dart';
import 'package:wwtd/models/game_room.dart';
import 'package:wwtd/models/room_discover.dart';
import 'package:wwtd/models/room_leaderboard.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/models/user_bet.dart';
import 'package:wwtd/models/user_profile.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final Map<String, String> headers = <String, String>{};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<({bool available, String? message})> checkUsername(String username) async {
    final http.Response response = await _client.get(
      _uri('/api/auth/check-username?username=${Uri.encodeQueryComponent(username.trim())}'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
    return (
      available: body['available'] as bool? ?? false,
      message: body['message'] as String?,
    );
  }

  Future<UserProfile> register({
    required String username,
    required String password,
  }) async {
    final http.Response response = await _client.post(
      _uri('/api/auth/register'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{
        'username': username.trim(),
        'password': password,
      }),
    );
    if (response.statusCode != 201) {
      throw _errorFromResponse(response);
    }
    return _profileFromAuthResponse(response);
  }

  Future<UserProfile> login({
    required String username,
    required String password,
  }) async {
    final http.Response response = await _client.post(
      _uri('/api/auth/login'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{
        'username': username.trim(),
        'password': password,
      }),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return _profileFromAuthResponse(response);
  }

  UserProfile _profileFromAuthResponse(http.Response response) {
    final Map<String, dynamic> body = jsonDecode(response.body) as Map<String, dynamic>;
    _token = body['access_token'] as String;
    return UserProfile.fromJson(body['profile'] as Map<String, dynamic>);
  }

  Future<UserProfile> fetchMe() async {
    final http.Response response = await _client.get(
      _uri('/api/me'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> updateDisplayName(String displayName) async {
    final http.Response response = await _client.patch(
      _uri('/api/me'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{'display_name': displayName.trim()}),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return UserProfile.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PredictionMarket>> fetchMarkets() async {
    final http.Response response = await _client.get(
      _uri('/api/markets'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic e) => PredictionMarket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PredictionMarket> placeBet({
    required String marketId,
    required bool isYes,
    required double amount,
  }) async {
    final http.Response response = await _client.post(
      _uri('/api/markets/$marketId/bets'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, dynamic>{
        'side': isYes ? 'yes' : 'no',
        'amount': amount,
      }),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return PredictionMarket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<GameRoom>> fetchRooms() async {
    final http.Response response = await _client.get(
      _uri('/api/rooms'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((dynamic e) => GameRoom.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GameRoom> createRoom(String personName) async {
    final http.Response response = await _client.post(
      _uri('/api/rooms'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{'person_name': personName.trim()}),
    );
    if (response.statusCode != 201) {
      throw _errorFromResponse(response);
    }
    return GameRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RoomDiscover>> discoverRooms(String query) async {
    final String q = query.trim();
    if (q.isEmpty) {
      return <RoomDiscover>[];
    }
    final http.Response response = await _client.get(
      _uri('/api/rooms/discover?q=${Uri.encodeQueryComponent(q)}'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((dynamic e) => RoomDiscover.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GameRoom> joinRoom({
    required String joinCode,
    String? roomId,
  }) async {
    final Map<String, String> body = <String, String>{
      'join_code': joinCode.trim().toUpperCase(),
    };
    if (roomId != null && roomId.isNotEmpty) {
      body['room_id'] = roomId;
    }
    final http.Response response = await _client.post(
      _uri('/api/rooms/join'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return GameRoom.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<PredictionMarket>> fetchRoomQuestions(String roomId) async {
    final http.Response response = await _client.get(
      _uri('/api/rooms/$roomId/questions'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic e) => PredictionMarket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PredictionMarket> addQuestion({
    required String roomId,
    required String question,
  }) async {
    final http.Response response = await _client.post(
      _uri('/api/rooms/$roomId/questions'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{'question': question.trim()}),
    );
    if (response.statusCode != 201) {
      throw _errorFromResponse(response);
    }
    return PredictionMarket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteQuestion({
    required String roomId,
    required String questionId,
  }) async {
    final http.Response response = await _client.delete(
      _uri('/api/rooms/$roomId/questions/$questionId'),
      headers: _headers(),
    );
    if (response.statusCode != 204) {
      throw _errorFromResponse(response);
    }
  }

  Future<PredictionMarket> resolveMarket({
    required String marketId,
    required bool winningYes,
  }) async {
    final http.Response response = await _client.post(
      _uri('/api/markets/$marketId/resolve'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, dynamic>{
        'winning_side': winningYes ? 'yes' : 'no',
      }),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return PredictionMarket.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<RoomLeaderboard>> fetchLeaderboard({String? roomId}) async {
    final String query = roomId != null ? '?room_id=$roomId' : '';
    final http.Response response = await _client.get(
      _uri('/api/leaderboard$query'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((dynamic e) => RoomLeaderboard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserBet>> fetchMyBets({String? roomId}) async {
    final String query = roomId != null ? '?room_id=$roomId' : '';
    final http.Response response = await _client.get(
      _uri('/api/me/bets$query'),
      headers: _headers(),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
    return list.map((dynamic e) => UserBet.fromJson(e as Map<String, dynamic>)).toList();
  }

  ApiException _errorFromResponse(http.Response response) {
    String message = 'Request failed (${response.statusCode})';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic detail = decoded['detail'];
        if (detail is String) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final dynamic first = detail.first;
          if (first is Map && first['msg'] is String) {
            message = first['msg'] as String;
          }
        }
      }
    } catch (_) {}
    return ApiException(message, statusCode: response.statusCode);
  }
}
