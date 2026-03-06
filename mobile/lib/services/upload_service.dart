import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class UploadService {
  final _api = ApiClient().dio;

  Future<String> uploadReceipt(File file) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    final response = await _api.post(
      '/uploads/receipt',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response.data['url'];
  }
}
