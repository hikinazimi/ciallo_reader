import 'chapter.dart'; // 导入之前写的章节模型

class Book {
  final String title;
  final String author;
  final String summary;
  final List<Chapter> chapters; // 书里包含章节列表

  Book({
    required this.title,
    required this.author,
    required this.chapters,
    this.summary = '',
  });
}