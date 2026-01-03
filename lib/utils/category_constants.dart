class CategoryConstants {
  // 文库8的标准分类映射
  static const Map<String, String> categories = {
    "0": "全部",
    "1": "电击文库",
    "2": "富士见",
    "3": "角川文库",
    "4": "MF文库J",
    "5": "Fami通",
    "6": "GA文库",
    "7": "HJ文库",
    "8": "一迅社",
    "9": "集英社",
    "10": "小学馆",
    "11": "讲谈社",
    "12": "少女文库",
    "13": "其他文库",
    "14": "游戏剧本",
  };

  // 转换成列表方便 UI 生成 Tab
  static List<MapEntry<String, String>> get list => categories.entries.toList();
}