import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageService {
  // Compress and encode image to base64 string
  // Target size: ~500KB to stay under Firestore's 1MB limit
  static Future<String> compressAndEncodeImage(File imageFile) async {
    try {
      // Read original image
      final originalBytes = await imageFile.readAsBytes();
      
      // Compress image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 1920,
        minHeight: 1080,
        quality: 70, // Quality 70% for good balance
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) {
        throw Exception('Failed to compress image');
      }

      // Check size - Firestore limit is 1MB, base64 adds ~33%, so max ~750KB raw
      // We'll target ~500KB to be safe
      const maxSize = 500 * 1024; // 500KB
      Uint8List finalBytes = compressedBytes;

      // If still too large, compress more aggressively
      if (compressedBytes.length > maxSize) {
        finalBytes = await FlutterImageCompress.compressWithList(
          compressedBytes,
          minWidth: 1280,
          minHeight: 720,
          quality: 50, // Lower quality for smaller size
          format: CompressFormat.jpeg,
        ) ?? compressedBytes;
      }

      // Encode to base64
      final base64String = base64Encode(finalBytes);
      
      // Return with data URI prefix for easy display
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      throw Exception('Failed to compress and encode image: $e');
    }
  }

  // Decode base64 string to Uint8List for display
  static Uint8List? decodeBase64Image(String base64String) {
    try {
      // Remove data URI prefix if present
      String base64Data = base64String;
      if (base64String.contains(',')) {
        base64Data = base64String.split(',').last;
      }
      
      return base64Decode(base64Data);
    } catch (e) {
      return null;
    }
  }

  // Check if string is base64 image
  static bool isBase64Image(String? imageString) {
    if (imageString == null || imageString.isEmpty) return false;
    return imageString.startsWith('data:image/') || 
           (imageString.length > 100 && !imageString.startsWith('http'));
  }
}

