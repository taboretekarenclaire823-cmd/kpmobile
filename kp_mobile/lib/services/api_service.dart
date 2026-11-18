import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ApiService {
  // Live server (HTTPS). This is the only line to change if the domain changes.
  static const String baseUrl = 'https://brgyparaisokp.site/api';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ---------- helpers ----------

  static Future<http.Response> _send(
    Future<http.Response> Function() call,
  ) async {
    try {
      return await call().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('The server took too long to respond.');
    } catch (e) {
      // ignore: avoid_print
      print('API error: $e');
      throw Exception(
        'Cannot reach the server. Please check your internet connection and try again.',
      );
    }
  }

  static dynamic _decode(http.Response r) {
    try {
      return jsonDecode(r.body);
    } catch (_) {
      return null;
    }
  }

  /// Picks the first validation error, or the message, or a fallback.
  static String _message(http.Response r, String fallback) {
    final data = _decode(r);
    if (data is Map) {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    return fallback;
  }

  /// Sends a request that needs the login token. If the token is no longer
  /// valid (401), it is removed and the user is asked to log in again.
  static Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> headers) call, {
    bool json = false,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found.');
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };

    final response = await _send(() => call(headers));
    if (response.statusCode == 401) {
      await clearToken();
      throw Exception('Your session has expired. Please log in again.');
    }
    return response;
  }

  // ---------- auth ----------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      () => http.post(
        Uri.parse('$baseUrl/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'email': email, 'password': password}),
      ),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map<String, dynamic>;
      await saveToken(data['token']);
      return data;
    }
    throw Exception(_message(response, 'Login failed.'));
  }

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> body, {
    String? verificationDocumentPath,
  }) async {
    final response = await _send(() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/register'),
      )..headers['Accept'] = 'application/json';

      for (final entry in body.entries) {
        final value = entry.value;
        if (value == null) continue;
        request.fields[entry.key] = value is bool
            ? (value ? '1' : '0')
            : value.toString();
      }

      if (verificationDocumentPath != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'verification_document',
            verificationDocumentPath,
          ),
        );
      }

      return http.Response.fromStream(await request.send());
    });

    if (response.statusCode == 201) {
      final data = _decode(response) as Map<String, dynamic>;
      await saveToken(data['token']);
      return data;
    }
    throw Exception(_message(response, 'Registration failed.'));
  }

  static Future<Map<String, dynamic>> getMe() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/me'), headers: h),
    );

    if (response.statusCode == 200) {
      return _decode(response) as Map<String, dynamic>;
    }
    throw Exception(_message(response, 'Unable to load your profile.'));
  }

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } catch (_) {
        // Log out on the phone even if the server can't be reached.
      }
    }
    await clearToken();
  }

  // ---------- blotter reports ----------

  static Future<List<Map<String, dynamic>>> getBlotters() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/blotters'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not load your reports.'));
  }

  static Future<Map<String, dynamic>> getBlotter(int id) async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/blotters/$id'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not load this report.'));
  }

  /// Starts a GCash checkout for the blotter's unpaid shared fee.
  static Future<String> startBlotterPayment(int id) async {
    final response = await _authed(
      (h) => http.post(Uri.parse('$baseUrl/blotters/$id/pay'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as Map)['checkout_url'].toString();
    }
    throw Exception(_message(response, 'Could not start the payment.'));
  }

  /// Returns the created blotter, including its server-assigned id.
  static Future<Map<String, dynamic>> createBlotter(
    Map<String, dynamic> body,
  ) async {
    final response = await _authed(
      (h) => http.post(
        Uri.parse('$baseUrl/blotters'),
        headers: h,
        body: jsonEncode(body),
      ),
      json: true,
    );

    if (response.statusCode == 201) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not send your report.'));
  }

  /// Searches registered residents by name for the person picker.
  /// Each item is {'id': int, 'name': String}.
  static Future<List<Map<String, dynamic>>> searchResidents(String q) async {
    final response = await _authed(
      (h) => http.get(
        Uri.parse('$baseUrl/residents/search?q=${Uri.encodeQueryComponent(q)}'),
        headers: h,
      ),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not search residents.'));
  }

  // ---------- complaints ----------

  static Future<List<Map<String, dynamic>>> getComplaints() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/complaints'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not load your complaints.'));
  }

  static Future<Map<String, dynamic>> getComplaint(int id) async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/complaints/$id'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not load this complaint.'));
  }

  /// Returns the created complaint, including its server-assigned id.
  static Future<Map<String, dynamic>> createComplaint(
    Map<String, dynamic> body,
  ) async {
    final response = await _authed(
      (h) => http.post(
        Uri.parse('$baseUrl/complaints'),
        headers: h,
        body: jsonEncode(body),
      ),
      json: true,
    );

    if (response.statusCode == 201) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not submit your complaint.'));
  }

  /// Starts a GCash checkout for the complaint's unpaid balance.
  /// Returns the PayMongo page address to open in the browser.
  /// The amount is decided by the server, never by the app.
  static Future<String> startComplaintPayment(int id) async {
    final response = await _authed(
      (h) => http.post(Uri.parse('$baseUrl/complaints/$id/pay'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as Map)['checkout_url'].toString();
    }
    throw Exception(_message(response, 'Could not start the payment.'));
  }

  // ---------- hearings ----------

  /// Upcoming hearings first, then past ones. Each has 'is_upcoming'.
  static Future<List<Map<String, dynamic>>> getHearings() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/hearings'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not load your hearings.'));
  }

  // ---------- summons and subpoenas ----------

  /// Summons where the resident is the respondent. Upcoming first.
  /// Each item has 'number', 'status', 'appearance_at', 'is_upcoming', etc.
  static Future<List<Map<String, dynamic>>> getSummons() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/summons'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not load your summons.'));
  }

  /// Subpoenas where the resident is a witness. Same shape as summons.
  static Future<List<Map<String, dynamic>>> getSubpoenas() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/subpoenas'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not load your subpoenas.'));
  }

  // ---------- certificates ----------

  /// Certificates (Forms 20, 20-A, 20-B, 21, 22) of the resident's complaints.
  /// Each item has 'id', 'form_number', 'title', 'complaint_number',
  /// 'date_issued', 'my_role' and 'has_file'.
  static Future<List<Map<String, dynamic>>> getCertificates() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/certificates'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    throw Exception(_message(response, 'Could not load your certificates.'));
  }

  /// Downloads the certificate PDF (with the login token) into the phone's
  /// temporary folder and returns the file path.
  static Future<String> downloadCertificate(int id, String fileName) async {
    final response = await _authed(
      (h) =>
          http.get(Uri.parse('$baseUrl/certificates/$id/download'), headers: h),
    );

    if (response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    }
    throw Exception(_message(response, 'Could not download the certificate.'));
  }

  // ---------- notice letters (PDF) ----------

  static Future<String> _downloadPdf(
    String path,
    String fileName,
    String failMessage,
  ) async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/$path'), headers: h),
    );

    if (response.statusCode == 200) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    }
    throw Exception(_message(response, failMessage));
  }

  /// Downloads the summons letter (KP Form 9) and returns the file path.
  static Future<String> downloadSummons(int id, String fileName) =>
      _downloadPdf(
        'summons/$id/download',
        fileName,
        'Could not download the summons.',
      );

  /// Downloads the subpoena letter (KP Form 13) and returns the file path.
  static Future<String> downloadSubpoena(int id, String fileName) =>
      _downloadPdf(
        'subpoenas/$id/download',
        fileName,
        'Could not download the subpoena.',
      );

  // ---------- profile ----------

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await _authed(
      (h) => http.get(Uri.parse('$baseUrl/profile'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not load your profile.'));
  }

  /// Returns the confirmation and the updated profile from the server.
  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> body,
  ) async {
    final response = await _authed(
      (h) => http.put(
        Uri.parse('$baseUrl/profile'),
        headers: h,
        body: jsonEncode(body),
      ),
      json: true,
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data);
    }
    throw Exception(_message(response, 'Could not save your profile.'));
  }

  /// Uploads a new profile photo (JPG or PNG).
  /// Returns the updated profile, including the new 'photo_url'.
  static Future<Map<String, dynamic>> uploadProfilePhoto(
    String filePath,
  ) async {
    final response = await _authed((h) async {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/profile/photo'))
            ..headers.addAll(h)
            ..files.add(await http.MultipartFile.fromPath('photo', filePath));

      return http.Response.fromStream(await request.send());
    });

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not upload your photo.'));
  }

  /// Removes the profile photo. Returns the updated profile.
  static Future<Map<String, dynamic>> deleteProfilePhoto() async {
    final response = await _authed(
      (h) => http.delete(Uri.parse('$baseUrl/profile/photo'), headers: h),
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(_message(response, 'Could not remove your photo.'));
  }

  /// Returns the server's confirmation message.
  static Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _authed(
      (h) => http.post(
        Uri.parse('$baseUrl/profile/password'),
        headers: h,
        body: jsonEncode({
          'current_password': currentPassword,
          'password': newPassword,
          'password_confirmation': newPassword,
        }),
      ),
      json: true,
    );

    if (response.statusCode == 200) {
      final data = _decode(response) as Map;
      return (data['message'] ?? 'Your password was changed.').toString();
    }
    throw Exception(_message(response, 'Could not change your password.'));
  }

  // ---------- address lists (public) ----------
  // Each item is {'code': ..., 'name': ...}.

  static Future<List<Map<String, String>>> _geo(
    String path,
    String codeKey,
  ) async {
    final response = await _send(
      () => http.get(
        Uri.parse('$baseUrl/geo/$path'),
        headers: {'Accept': 'application/json'},
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Could not load the address list.');
    }
    final list = _decode(response) as List;
    return list
        .map<Map<String, String>>(
          (e) => {'code': e[codeKey].toString(), 'name': e['name'].toString()},
        )
        .toList();
  }

  static Future<List<Map<String, String>>> getRegions() =>
      _geo('regions', 'region_id');

  static Future<List<Map<String, String>>> getProvinces(String regionCode) =>
      _geo('provinces/$regionCode', 'province_id');

  static Future<List<Map<String, String>>> getCities(String provinceCode) =>
      _geo('cities/$provinceCode', 'city_id');

  // The barangay endpoint returns 'code', not 'barangay_id'.
  static Future<List<Map<String, String>>> getBarangays(String cityCode) =>
      _geo('barangays/$cityCode', 'code');

  // ---------- token (encrypted storage) ----------

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
