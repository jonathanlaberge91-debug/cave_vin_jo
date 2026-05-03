import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'photo_crop_dialog_web.dart' if (dart.library.io) 'photo_crop_dialog_mobile.dart'
    as platform;

Future<Uint8List?> showPhotoCropDialog(
  BuildContext context,
  Uint8List imageBytes,
) {
  return platform.showPhotoCropDialogImpl(context, imageBytes);
}
