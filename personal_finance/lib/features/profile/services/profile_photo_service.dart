import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ProfilePhotoService {
  final ImagePicker _picker;

  ProfilePhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  /// Picks an image from device gallery, saves a managed local copy, and returns the persistent path.
  Future<String?> pickAndSaveProfilePhoto() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return await saveManagedCopy(File(pickedFile.path));
    } catch (e) {
      debugPrint('Error picking profile photo: $e');
      return null;
    }
  }

  /// Saves a persistent copy in the application documents directory
  Future<String> saveManagedCopy(File sourceFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final profileDir = Directory(p.join(docsDir.path, 'profile'));
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }

    final ext = p.extension(sourceFile.path).isNotEmpty
        ? p.extension(sourceFile.path)
        : '.jpg';
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(profileDir.path, fileName);

    final savedFile = await sourceFile.copy(targetPath);
    return savedFile.path;
  }

  /// Deletes a previously stored avatar file safely if it exists
  Future<void> deleteManagedPhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting old avatar photo: $e');
    }
  }
}
