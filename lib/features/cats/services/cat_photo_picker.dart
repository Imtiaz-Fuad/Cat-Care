import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/services/app_logger.dart';

/// Outcome of a `CatPhotoPicker.pick*` call.
///
/// `path` is the on-device file path of the picked image, suitable
/// for `Image.file(File(path))` rendering. `bytes` is the in-memory
/// representation used by `CatRepository.uploadCatPhoto`. Both are
/// `null` when the user cancelled the picker.
class PickedCatPhoto {
  const PickedCatPhoto({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

/// Thin façade over `image_picker` so features never import the
/// plugin directly.
///
/// The picker is the single point that decides which platform
/// channels run (camera vs gallery, Android/iOS permission flow).
/// Repositories depend on this service to keep their tests pure.
class CatPhotoPicker {
  CatPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Show the system gallery picker. Returns `null` on user cancel.
  Future<PickedCatPhoto?> pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return null;
      final Uint8List bytes = await file.readAsBytes();
      return PickedCatPhoto(path: file.path, bytes: bytes);
    } catch (error, stack) {
      AppLogger.e('CatPhotoPicker.pickFromGallery failed', error, stack);
      throw const PermissionFailure(
        'Could not open the photo library.',
        code: 'gallery-unavailable',
      );
    }
  }

  /// Launch the system camera. Requires the platform permission to be
  /// granted (Android: `CAMERA` runtime permission; iOS:
  /// `NSCameraUsageDescription` in `Info.plist`).
  Future<PickedCatPhoto?> takePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file == null) return null;
      final Uint8List bytes = await file.readAsBytes();
      return PickedCatPhoto(path: file.path, bytes: bytes);
    } catch (error, stack) {
      AppLogger.e('CatPhotoPicker.takePhoto failed', error, stack);
      throw const PermissionFailure(
        'Could not open the camera.',
        code: 'camera-unavailable',
      );
    }
  }
}
