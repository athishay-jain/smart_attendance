import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class ImageHelper {
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();

  final ImagePicker _picker = ImagePicker();

  // Pick and save image
  Future<File?> pickAndSaveImage() async {
    try {
      // Show options dialog - in a real app, you'd pass context
      // For now, we'll default to gallery
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Get app's private directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/student_images');

      // Create directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(pickedFile.path);
      final fileName = 'student_$timestamp$extension';
      final savedImagePath = path.join(imagesDir.path, fileName);

      // Read and compress image
      final imageBytes = await File(pickedFile.path).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        // If decoding fails, just copy the original
        await File(pickedFile.path).copy(savedImagePath);
      } else {
        // Resize if needed (max 800x800 while maintaining aspect ratio)
        final resized = img.copyResize(
          image,
          width: image.width > 800 ? 800 : image.width,
          height: image.height > 800 ? 800 : image.height,
        );

        // Save compressed image
        final compressedBytes = img.encodeJpg(resized, quality: 85);
        await File(savedImagePath).writeAsBytes(compressedBytes);
      }

      return File(savedImagePath);
    } catch (e) {
      print('Error picking/saving image: $e');
      return null;
    }
  }

  // Pick image from camera
  Future<File?> pickFromCamera() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return await _saveImage(pickedFile);
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  // Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      return await _saveImage(pickedFile);
    } catch (e) {
      print('Error picking from gallery: $e');
      return null;
    }
  }

  // Save image to app directory
  Future<File?> _saveImage(XFile pickedFile) async {
    try {
      // Get app's private directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/student_images');

      // Create directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(pickedFile.path);
      final fileName = 'student_$timestamp$extension';
      final savedImagePath = path.join(imagesDir.path, fileName);

      // Read and compress image
      final imageBytes = await File(pickedFile.path).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        // If decoding fails, just copy the original
        await File(pickedFile.path).copy(savedImagePath);
      } else {
        // Resize if needed
        final resized = img.copyResize(
          image,
          width: image.width > 800 ? 800 : image.width,
          height: image.height > 800 ? 800 : image.height,
        );

        // Save compressed image
        final compressedBytes = img.encodeJpg(resized, quality: 85);
        await File(savedImagePath).writeAsBytes(compressedBytes);
      }

      return File(savedImagePath);
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  // Delete image file
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  // Get image file size in KB
  Future<int> getImageSize(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return (bytes / 1024).round(); // Convert to KB
      }
      return 0;
    } catch (e) {
      print('Error getting image size: $e');
      return 0;
    }
  }

  // Check if image exists
  Future<bool> imageExists(String imagePath) async {
    try {
      return await File(imagePath).exists();
    } catch (e) {
      return false;
    }
  }

  // Clear all student images
  Future<void> clearAllImages() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/student_images');

      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing images: $e');
    }
  }

  // Get total storage used by images in MB
  Future<double> getTotalImageStorage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/student_images');

      if (!await imagesDir.exists()) return 0.0;

      int totalBytes = 0;
      await for (var entity in imagesDir.list()) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }

      return totalBytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      print('Error calculating storage: $e');
      return 0.0;
    }
  }

  // Copy image to app directory (useful for testing or importing)
  Future<File?> copyImageToAppDirectory(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/student_images');

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(sourcePath);
      final fileName = 'student_$timestamp$extension';
      final savedImagePath = path.join(imagesDir.path, fileName);

      await File(sourcePath).copy(savedImagePath);
      return File(savedImagePath);
    } catch (e) {
      print('Error copying image: $e');
      return null;
    }
  }
}