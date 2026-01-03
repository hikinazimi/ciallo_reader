import 'package:hive/hive.dart';

// 1. 必须添加这行 part，文件名要和当前文件名一致
part 'bookshelf_novel.g.dart';

// 2. 添加 @HiveType(typeId: 0) -> 这里的 0 是唯一的 ID，不同类不能重复
@HiveType(typeId: 0)
class BookshelfNovel {

  @HiveField(0) // 字段索引，不要重复，不要轻易修改
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String coverUrl;

  @HiveField(3)
  final String author;

  @HiveField(4)
  String lastReadChapter; // 去掉 final，方便修改

  @HiveField(5)
  String lastReadChapterId;

  @HiveField(6)
  String lastUpdate;

  BookshelfNovel({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.author,
    this.lastReadChapter = "尚未阅读",
    this.lastReadChapterId = "",
    this.lastUpdate = "",
  });

// 不再需要 toJson 和 fromJson 了！Hive 会自动处理。
}