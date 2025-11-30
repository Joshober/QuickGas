import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/image_service.dart';

class Base64ImageWidget extends StatelessWidget {
  final String? imageString; // Can be base64 or URL
  final double? width;
  final double? height;
  final BoxFit fit;

  const Base64ImageWidget({
    super.key,
    required this.imageString,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imageString == null || imageString!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Check if it's a base64 image or URL
    if (ImageService.isBase64Image(imageString)) {
      // Decode base64
      final imageBytes = ImageService.decodeBase64Image(imageString!);

      if (imageBytes != null) {
        return Image.memory(
          imageBytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image),
            );
          },
        );
      }
    } else if (imageString!.startsWith('http')) {
      // It's a URL - use cached network image for better performance
      return CachedNetworkImage(
        imageUrl: imageString,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image),
        ),
      );
    }

    // Fallback
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image),
    );
  }
}
