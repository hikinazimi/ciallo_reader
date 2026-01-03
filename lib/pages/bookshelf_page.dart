import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 必須引入這個
import '../models/bookshelf_novel.dart';
import '../utils/bookshelf_manager.dart';
import 'book_detail_page.dart';

class BookshelfPage extends StatelessWidget { // 🔥 改成 StatelessWidget 也可以了，因為狀態由 Hive 管理
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("我的書架")),
      // 🔥 核心：ValueListenableBuilder
      // 只要 BookshelfManager.box 發生變化，builder 就會重新執行
      body: ValueListenableBuilder<Box<BookshelfNovel>>(
        valueListenable: BookshelfManager.box.listenable(),
        builder: (context, box, _) {
          // 實時獲取最新的書單，並反轉（讓最新加入的在上面）
          final books = box.values.toList().reversed.toList();

          if (books.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("書架是空的，去首頁加兩本吧~", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: books.length,
            separatorBuilder: (c, i) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final book = books[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BookDetailPage(
                        bookId: book.id,
                        title: book.title,
                        coverUrl: book.coverUrl,
                      ),
                    ),
                  );
                },
                onLongPress: () {
                  _showDeleteDialog(context, book);
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: book.coverUrl,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        httpHeaders: const {
                          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                        },
                        placeholder: (_,__) => Container(color: Colors.grey[200]),
                        errorWidget: (_,__,___) => Container(color: Colors.grey[300], child: const Icon(Icons.book)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text("作者: ${book.author}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.history, size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "讀至: ${book.lastReadChapter}",
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, BookshelfNovel book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("移出書架"),
        content: Text("確定要移除《${book.title}》嗎？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // 直接調用 Manager 刪除，UI 會自動刷新，不需要 setState
              BookshelfManager.removeBook(book.id);
            },
            child: const Text("移除", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}