import 'dart:convert';
import 'dart:typed_data';

class ImageHelper {
  // ✅ Get all images — handles single base64 string OR JSON array string
  static List<Uint8List> getImages(dynamic imageData) {
    if (imageData == null || imageData.toString().isEmpty) return [];
    final str = imageData.toString().trim();

    // ✅ Try JSON array first ["base64...","base64..."]
    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded
              .map((e) => _decodeBase64(e.toString()))
              .whereType<Uint8List>()
              .toList();
        }
      } catch (_) {}
    }

    // ✅ Single base64 string
    final bytes = _decodeBase64(str);
    if (bytes != null) return [bytes];
    return [];
  }

  // ✅ Get only the first image for thumbnails
  static Uint8List? getFirstImage(dynamic imageData) {
    final images = getImages(imageData);
    return images.isNotEmpty ? images.first : null;
  }

  static Uint8List? _decodeBase64(String str) {
    try { return base64Decode(str); } catch (_) { return null; }
  }
}