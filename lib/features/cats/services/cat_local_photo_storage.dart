import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local persistence for cat profile photos.
class CatLocalPhotoStorage {
  static const String _keyPrefix = 'cat.localPhotoPath.';

  Future<String> save({required String catId, required Uint8List bytes}) async {
    final Directory root = await getApplicationDocumentsDirectory();
    final Directory directory = Directory('${root.path}/cat_photos');
    await directory.create(recursive: true);
    final File file = File('${directory.path}/cat_$catId.jpg');
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix$catId', file.path);
    return file.path;
  }

  Future<String?> pathFor(String catId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString('$_keyPrefix$catId');
    if (path == null || path.isEmpty) return null;
    if (await File(path).exists()) return path;
    await prefs.remove('$_keyPrefix$catId');
    return null;
  }

  Future<void> delete(String catId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? path = prefs.getString('$_keyPrefix$catId');
    if (path != null && path.isNotEmpty) {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    }
    await prefs.remove('$_keyPrefix$catId');
  }
}
