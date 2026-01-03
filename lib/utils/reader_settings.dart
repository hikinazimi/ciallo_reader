import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class ReaderSettings {
  static const String _boxName = "readerSettings";

  static Box get _box => Hive.box(_boxName);

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  // 1. 字号
  static double get fontSize => _box.get('fontSize', defaultValue: 18.0);
  static set fontSize(double value) => _box.put('fontSize', value);

  // 2. 是否开启双栏 (仅限大屏)
  static bool get useTwoColumns => _box.get('useTwoColumns', defaultValue: false);
  static set useTwoColumns(bool value) => _box.put('useTwoColumns', value);

  // 3. 监听设置变化 (用于 UI 实时刷新)
  static ValueListenable<Box> listenable() {
    return _box.listenable();
  }
}