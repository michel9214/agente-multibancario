import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/upload_service.dart';

/// Shows a bottom sheet to pick photo from camera or gallery,
/// compresses it for low-RAM devices, uploads it, and returns the URL.
Future<String?> pickAndUploadPhoto(BuildContext context) async {
  // 'camera' or 'gallery'
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Elegir de galeria'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    ),
  );

  if (choice == null) return null;

  // Show loading indicator
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Procesando foto...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );
  }

  try {
    String? imagePath;

    if (choice == 'camera') {
      // Request camera permission
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Se necesita permiso de cámara'),
              action: SnackBarAction(
                label: 'Config',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return null;
      }
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 50,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
      imagePath = image?.path;
    } else {
      // Use file_picker for gallery - opens system file explorer
      // which works on all Xiaomi/MIUI devices
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      imagePath = result?.files.single.path;
    }

    if (imagePath == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      return null;
    }

    // Compress for low-RAM devices
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imagePath,
      targetPath,
      quality: 40,
      minWidth: 720,
      minHeight: 720,
      format: CompressFormat.jpeg,
    );

    final fileToUpload = compressedFile != null ? File(compressedFile.path) : File(imagePath);

    final url = await UploadService().uploadReceipt(fileToUpload);

    // Clean up temp files
    try {
      if (compressedFile != null) File(compressedFile.path).deleteSync();
      File(imagePath).deleteSync();
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    return url;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e')),
      );
    }
    return null;
  }
}

/// Shows a full-screen preview of an uploaded photo (memory-efficient)
void showPhotoPreview(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                cacheWidth: 800,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stack) => const Center(
                  child:
                      Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    ),
  );
}
