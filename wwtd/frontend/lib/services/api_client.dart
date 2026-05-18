import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wwtd/config/api_config.dart';
import 'package:wwtd/models/send_code_result.dart';
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

  Future<SendCodeResult> sendLoginCode(String email) async {
    final http.Response response = await _client.post(
      _uri('/api/auth/send-code'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{'email': email.trim().toLowerCase()}),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
    return SendCodeResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserProfile> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    final http.Response response = await _client.post(
      _uri('/api/auth/verify-code'),
      headers: _headers(jsonBody: true),
      body: jsonEncode(<String, String>{
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      }),
    );
    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }
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
