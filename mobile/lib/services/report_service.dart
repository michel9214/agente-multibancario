import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_client.dart';

class ReportService {
  final _api = ApiClient().dio;

  Future<Map<String, dynamic>> getSummary({String? from, String? to}) async {
    final response = await _api.get('/reports/summary', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return response.data;
  }

  Future<Uint8List> exportShift(String shiftId, String format) async {
    final response = await _api.get(
      '/reports/shifts/$shiftId/export',
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
  }
}
