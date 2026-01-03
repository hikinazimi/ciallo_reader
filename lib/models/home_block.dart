import 'novel.dart';

class HomeBlock {
  final String title;      // 板块标题，如 "强力推荐"
  final List<Novel> novels; // 该板块下的书籍列表

  HomeBlock({
    required this.title,
    required this.novels,
  });
}