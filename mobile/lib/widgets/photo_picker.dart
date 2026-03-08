import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/upload_service.dart';

/// Request storage/photo permissions based on Android version.
Future<bool> _requestPermissions(BuildContext context, ImageSource source) async {
  if (source == ImageSource.camera) {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Se necesita permiso de cámara'),
            action: SnackBarAction(
              label: 'Abrir config',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  // For gallery: try photos first (Android 13+), then storage (older)
  PermissionStatus status = await Permission.photos.request();
  if (status.isGranted || status.isLimited) return true;

  // Fallback for Android < 13
  status = await Permission.storage.request();
  if (status.isGranted || status.isLimited) return true;

  // If permanently denied, guide user to settings
  if (status.isPermanentlyDenied || status.isDenied) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Se necesita permiso para acceder a fotos'),
          action: SnackBarAction(
            label: 'Abrir config',
            onPressed: () => openAppSettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    return false;
  }

  return true;
}

/// Shows a bottom sheet to pick photo from camera or gallery,
/// compresses it for low-RAM devices, uploads it, and returns the URL.
Future<String?> pickAndUploadPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
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
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('Elegir de galeria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );

  if (source == null) return null;

  // Request permissions before proceeding
  if (context.mounted) {
    final granted = await _requestPermissions(context, source);
    if (!granted) return null;
  }

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
    // Disable Android Photo Picker (shows empty on MIUI/Xiaomi),
    // use legacy intent picker (ACTION_GET_CONTENT) which works correctly
    final ImagePickerPlatform pickerPlatform = ImagePickerPlatform.instance;
    if (pickerPlatform is ImagePickerAndroid) {
      pickerPlatform.useAndroidPhotoPicker = false;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 50,
      preferredCameraDevice: CameraDevice.rear,
      requestFullMetadata: false,
    );
    if (image == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      return null;
    }

    // Compress further for low-RAM devices
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      quality: 40,
      minWidth: 720,
      minHeight: 720,
      format: CompressFormat.jpeg,
    );

    final fileToUpload = compressedFile != null ? File(compressedFile.path) : File(image.path);

    final url = await UploadService().uploadReceipt(fileToUpload);

    // Clean up temp files
    try {
      if (compressedFile != null) File(compressedFile.path).deleteSync();
      File(image.path).deleteSync();
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
                // Limit decoded image size in memory
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
