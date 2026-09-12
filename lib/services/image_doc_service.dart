import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// يخزّن صور المستندات كنص Base64 داخل مستندات Firestore عادية، بدل
/// Firebase Storage — لأن Storage بقى يتطلب خطة دفع (Blaze) حتى للاستخدام
/// البسيط. Firestore نفسه يبقى ضمن الخطة المجانية (Spark) بدون أي بطاقة بنكية.
///
/// كل صورة تُحفظ في مستند مستقل داخل collection باسم "images" (حتى لا تكبر
/// مستندات الفاتورة/الطلب نفسها وتتجاوز حد الـ 1 ميجابايت لكل مستند في
/// Firestore)، ونحتفظ فقط بمعرّف الصورة (imageId) داخل الفاتورة/الطلب.
class ImageDocService {
  ImageDocService._();
  static final ImageDocService instance = ImageDocService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _images => _db.collection('images');

  /// حد أمان أقل من حد Firestore الفعلي (1 ميجابايت) لترك هامش لبقية حقول
  /// المستند ولزيادة حجم البيانات عند التحويل إلى Base64 (٪33 تقريباً).
  static const int maxOriginalBytes = 650 * 1024;

  final Map<String, Uint8List> _cache = {};

  Future<String> uploadDocumentImage(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > maxOriginalBytes) {
      throw Exception(
        'حجم الصورة كبير جداً (${(bytes.length / 1024).toStringAsFixed(0)} كيلوبايت). '
        'حاول تصويرها بإضاءة أفضل أو بدون تكبير الكاميرا، أو اقتصّ على المستند نفسه فقط.',
      );
    }
    final b64 = base64Encode(bytes);
    final id = const Uuid().v4();
    await _images.doc(id).set({
      'data': b64,
      'createdAt': DateTime.now().toIso8601String(),
    });
    _cache[id] = bytes;
    return id;
  }

  Future<List<String>> uploadDocumentImages(List<File> files) async {
    final ids = <String>[];
    for (final file in files) {
      ids.add(await uploadDocumentImage(file));
    }
    return ids;
  }

  Future<Uint8List?> getImageBytes(String imageId) async {
    if (_cache.containsKey(imageId)) return _cache[imageId];
    final doc = await _images.doc(imageId).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>;
    final b64 = data['data'] as String?;
    if (b64 == null) return null;
    final bytes = base64Decode(b64);
    _cache[imageId] = bytes;
    return bytes;
  }
}
