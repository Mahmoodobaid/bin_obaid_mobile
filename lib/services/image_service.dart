import 'dart:convert'; // مهم لـ base64Encode
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:cached_network_image/cached_network_image.dart';

/// نتيجة معالجة الصورة
class ImageProcessResult {
  final File? file;
  final Uint8List? bytes;
  final String? error;

  ImageProcessResult({this.file, this.bytes, this.error});

  bool get success => error == null;
}

/// إعدادات الضغط
class ImageCompressSettings {
  final int quality;       // 0-100
  final int maxWidth;
  final int maxHeight;

  const ImageCompressSettings({
    this.quality = 85,
    this.maxWidth = 1024,
    this.maxHeight = 1024,
  });
}

/// إعدادات الكولاج
class CollageSettings {
  final int width;
  final int height;
  final int quality;
  final int maxImages;     // الحد الأقصى لعدد الصور (4)

  const CollageSettings({
    this.width = 800,
    this.height = 800,
    this.quality = 85,
    this.maxImages = 4,
  });
}

/// خدمة الصور المتكاملة
class ImageService {
  // ذاكرة مؤقتة بسيطة (LRU)
  static final Map<String, File> _cache = {};
  static const int _maxCacheSize = 50;

  // ============================================================
  // 1. تحميل صورة من URL وحفظها كملف مؤقت (مع cache)
  // ============================================================
  static Future<File?> downloadImageToFile(String url, {bool useCache = true}) async {
    if (url.isEmpty) return null;

    // التحقق من الكاش
    if (useCache && _cache.containsKey(url)) {
      final cachedFile = _cache[url];
      if (cachedFile != null && await cachedFile.exists()) {
        return cachedFile;
      } else {
        _cache.remove(url);
      }
    }

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final dir = await getTemporaryDirectory();
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}.jpg';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      // إضافة إلى الكاش مع إدارة الحجم
      _cache[url] = file;
      if (_cache.length > _maxCacheSize) {
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
      }
      return file;
    } catch (e) {
      debugPrint('Download error for $url: $e');
      return null;
    }
  }

  // ============================================================
  // 2. تحميل صورة كـ Uint8List (للاستخدام المباشر)
  // ============================================================
  static Future<Uint8List?> downloadImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (e) {
      debugPrint('Download bytes error: $e');
    }
    return null;
  }

  // ============================================================
  // 3. ضغط وتغيير حجم الصورة (في Isolate)
  // ============================================================
  static Future<ImageProcessResult> compressImage({
    required dynamic input, // يمكن أن يكون File أو Uint8List
    ImageCompressSettings settings = const ImageCompressSettings(),
  }) async {
    try {
      Uint8List originalBytes;
      if (input is File) {
        originalBytes = await input.readAsBytes();
      } else if (input is Uint8List) {
        originalBytes = input;
      } else {
        return ImageProcessResult(error: 'Invalid input type');
      }

      final result = await compute(_compressImageIsolate, _CompressParams(originalBytes, settings));
      return result;
    } catch (e) {
      return ImageProcessResult(error: e.toString());
    }
  }

  static Future<ImageProcessResult> _compressImageIsolate(_CompressParams params) async {
    try {
      img.Image? image = img.decodeImage(params.bytes);
      if (image == null) return ImageProcessResult(error: 'Failed to decode image');

      // تغيير الحجم مع الحفاظ على النسبة
      img.Image resized = img.copyResize(
        image,
        width: params.settings.maxWidth,
        height: params.settings.maxHeight,
        interpolation: img.Interpolation.average,
      );

      final compressedBytes = img.encodeJpg(resized, quality: params.settings.quality);
      return ImageProcessResult(bytes: compressedBytes);
    } catch (e) {
      return ImageProcessResult(error: e.toString());
    }
  }

  // ============================================================
  // 4. حفظ الصورة المضغوطة كملف
  // ============================================================
  static Future<File?> compressAndSave(File inputFile, {ImageCompressSettings settings = const ImageCompressSettings()}) async {
    final result = await compressImage(input: inputFile, settings: settings);
    if (result.bytes == null) return null;

    final dir = await getTemporaryDirectory();
    final outputFile = File('${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await outputFile.writeAsBytes(result.bytes!);
    return outputFile;
  }

  // ============================================================
  // 5. إنشاء كولاج من مجموعة صور (في Isolate)
  // ============================================================
  static Future<File?> createCollage(List<File> images, {CollageSettings settings = const CollageSettings()}) async {
    if (images.isEmpty) return null;

    // تقليل عدد الصور إلى الحد الأقصى
    final limited = images.take(settings.maxImages).toList();
    final collageFile = await compute(_createCollageIsolate, _CollageParams(limited, settings));
    return collageFile;
  }

  static Future<File?> _createCollageIsolate(_CollageParams params) async {
    try {
      final int count = params.images.length;
      if (count == 0) return null;

      // إنشاء لوحة فارغة
      img.Image collage = img.Image(width: params.settings.width, height: params.settings.height);
      int cellW = params.settings.width ~/ 2;
      int cellH = params.settings.height ~/ 2;

      for (int i = 0; i < count; i++) {
        final bytes = await params.images[i].readAsBytes();
        img.Image? original = img.decodeImage(bytes);
        if (original == null) continue;

        // تغيير حجم الصورة لتناسب الخلية
        img.Image resized = img.copyResize(original, width: cellW, height: cellH);
        int row = i ~/ 2;
        int col = i % 2;
        img.copyInto(collage, resized, dstX: col * cellW, dstY: row * cellH);
      }

      // حفظ الكولاج
      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/collage_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await outFile.writeAsBytes(img.encodeJpg(collage, quality: params.settings.quality));
      return outFile;
    } catch (e) {
      debugPrint('Collage creation error: $e');
      return null;
    }
  }

  // ============================================================
  // 6. إنشاء كولاج من URLs مباشرة (تحميل تلقائي)
  // ============================================================
  static Future<File?> createCollageFromUrls(List<String> urls, {CollageSettings settings = const CollageSettings()}) async {
    final files = <File>[];
    for (final url in urls.take(settings.maxImages)) {
      final file = await downloadImageToFile(url);
      if (file != null) files.add(file);
    }
    if (files.isEmpty) return null;
    return await createCollage(files, settings: settings);
  }

  // ============================================================
  // 7. تحويل الصورة إلى Base64 (للرفع)
  // ============================================================
  static Future<String?> imageToBase64(File imageFile, {int quality = 80}) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final compressed = await compressImage(input: bytes, settings: ImageCompressSettings(quality: quality));
      if (compressed.bytes != null) {
        return 'data:image/jpeg;base64,${base64Encode(compressed.bytes!)}';
      }
      return null;
    } catch (e) {
      debugPrint('Base64 conversion error: $e');
      return null;
    }
  }

  // ============================================================
  // 8. عرض صورة من ملف أو URL باستخدام CachedNetworkImage
  // ============================================================
  static Widget buildImageWidget({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _defaultImage(width, height);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _defaultImage(width, height),
    );
  }

  static Widget _defaultImage(double? w, double? h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }

  static Widget _defaultPlaceholder() {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }

  // ============================================================
  // 9. مسح الكاش
  // ============================================================
  static void clearCache() {
    _cache.clear();
    // مسح كاش CachedNetworkImage بشكل صحيح
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  // ============================================================
  // 10. الحصول على صورة مصغرة (thumbnail) من الصورة الأصلية
  // ============================================================
  static Future<File?> createThumbnail(File originalFile, {int size = 200}) async {
    return await compressAndSave(originalFile, settings: ImageCompressSettings(maxWidth: size, maxHeight: size, quality: 70));
  }
}

// ============================================================
// فئات مساعدة للـ Isolate
// ============================================================
class _CompressParams {
  final Uint8List bytes;
  final ImageCompressSettings settings;
  _CompressParams(this.bytes, this.settings);
}

class _CollageParams {
  final List<File> images;
  final CollageSettings settings;
  _CollageParams(this.images, this.settings);
}
