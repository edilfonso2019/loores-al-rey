import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Lee assets directamente del disco (sin necesitar el bundle de Flutter).
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(await File(key).readAsBytes());

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).readAsString(encoding: utf8);
}
