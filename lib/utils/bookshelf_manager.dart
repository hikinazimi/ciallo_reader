import 'package:hive/hive.dart';
import '../models/bookshelf_novel.dart';
import '../models/novel_info.dart';

class BookshelfManager {
  // 获取之前在 main.dart 打开的盒子
  static Box<BookshelfNovel> get _box => Hive.box<BookshelfNovel>('bookshelfBox');

  static Box<BookshelfNovel> get box => _box;
  // 📖 获取所有书籍 (转为 List)
  static List<BookshelfNovel> getAllBooks() {
    // values 是所有的书，toList 转为列表
    // reversed 是为了让最新加入/阅读的书排在前面 (可选)
    return _box.values.toList().reversed.toList();
  }

  // ➕ 添加书籍
  static Future<void> addBook(NovelInfo info) async {
    // 如果已经有了，就不加
    if (_box.containsKey(info.id)) return;

    final newBook = BookshelfNovel(
      id: info.id,
      title: info.title,
      coverUrl: info.coverUrl,
      author: info.author,
      lastUpdate: info.lastUpdate,
      lastReadChapter: "尚未阅读",
    );

    // key 使用 id，value 是对象
    await _box.put(info.id, newBook);
  }

  // ➖ 移除书籍
  static Future<void> removeBook(String bookId) async {
    await _box.delete(bookId);
  }

  // 🔥获取单本书籍对象 (用于详情页判断进度)
  static BookshelfNovel? getBook(String bookId) {
    return box.get(bookId);
  }

  // 🔄 更新阅读进度
  static Future<void> updateProgress(String bookId, String chapterName, String chapterId) async {
    final book = _box.get(bookId);
    if (book != null) {
      // 创建新对象 (因为字段是 final 的推荐做法，虽然我上面去掉了 final，但这样更稳健)
      final updatedBook = BookshelfNovel(
        id: book.id,
        title: book.title,
        coverUrl: book.coverUrl,
        author: book.author,
        lastUpdate: book.lastUpdate,
        lastReadChapter: chapterName,     // 更新
        lastReadChapterId: chapterId,     // 更新
      );

      // 重新存入，覆盖旧的
      // 为了实现“最近阅读排在最前”，我们可以先删再加，或者只覆盖
      // Hive 默认是按添加顺序排序。如果想置顶，可以先 delete 再 put
      await _box.delete(bookId);
      await _box.put(bookId, updatedBook);
    }
  }

  // ❓ 检查是否在书架中
  static bool isInBookshelf(String bookId) {
    // 速度极快，O(1) 复杂度
    return _box.containsKey(bookId);
  }
}