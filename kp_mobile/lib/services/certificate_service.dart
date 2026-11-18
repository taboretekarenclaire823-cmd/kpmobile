import 'package:dio/dio.dart';

class LuponMember {
  final int id;
  final String name;
  LuponMember(this.id, this.name);
  factory LuponMember.fromJson(Map<String, dynamic> j) =>
      LuponMember(j['id'] as int, j['name'] as String);
}

class IssuedCertificate {
  final String message;
  final String? pdfUrl;
  IssuedCertificate(this.message, this.pdfUrl);
}

class CertificateService {
  final Dio dio; // baseUrl + bearer token already configured
  CertificateService(this.dio);

  Future<Map<String, bool>> available(int hearingId) async {
    final res = await dio.get('/hearings/$hearingId/certificates');
    return (res.data as Map).map((k, v) => MapEntry(k.toString(), v == true));
  }

  Future<List<LuponMember>> luponMembers() async {
    final res = await dio.get('/lupon-members');
    return (res.data as List)
        .map((e) => LuponMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<IssuedCertificate> issue({
    required int hearingId,
    required String form, // '20', '20-A', '20-B'
    required int issuedBy,
    String? repudiatingParty,
    String? repudiationReason,
  }) async {
    final res = await dio.post(
      '/hearings/$hearingId/certificates/$form',
      data: {
        'issued_by': issuedBy,
        if (form == '20') 'repudiating_party': repudiatingParty,
        if (form == '20') 'repudiation_reason': repudiationReason,
      },
    );
    return IssuedCertificate(
      res.data['message'] as String,
      res.data['pdf_url'] as String?,
    );
  }

  /// Turns a Dio error into a readable message (422 validation, 403, etc.).
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          return first is List ? first.first.toString() : first.toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
      if (e.response?.statusCode == 403) {
        return 'You are not allowed to issue this certificate.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}