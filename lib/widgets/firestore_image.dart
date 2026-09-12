import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_doc_service.dart';

/// يعرض صورة مستند محفوظة كـ Base64 داخل Firestore (بدل Image.network).
class FirestoreImage extends StatelessWidget {
  final String imageId;
  final BoxFit fit;
  final double? width;
  final double? height;

  const FirestoreImage({
    super.key,
    required this.imageId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (imageId.isEmpty) {
      return _placeholder();
    }
    return FutureBuilder<Uint8List?>(
      future: ImageDocService.instance.getImageBytes(imageId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (!snap.hasData || snap.data == null) {
          return _placeholder();
        }
        return Image.memory(snap.data!, width: width, height: height, fit: fit);
      },
    );
  }

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
        child: const Icon(Icons.broken_image),
      );
}
