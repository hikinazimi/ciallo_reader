import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 必须引入，用于监听数据库变化

import '../models/novel_info.dart';
import '../models/chapter.dart';
import '../api/wenku_api.dart';
import '../utils/bookshelf_manager.dart'; // 引入管理器

import 'catalog_page.dart';
import 'reader_page.dart'; // 🔥 必须引入阅读页

class BookDetailPage extends StatefulWidget {
  final String bookId;
  final String? coverUrl;
  final String? title;

  const BookDetailPage({
    super.key,
    required this.bookId,
    this.coverUrl,
    this.title,
  });

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  NovelInfo? _info;
  bool _isLoading = true;
  String _errorMsg = "";

  @override
  void initState() {
    super.initState();
    _loadData();
    // 注意：不再需要手动 _checkFavoriteStatus，因为我们用 ValueListenableBuilder 全局监听
  }

  Future<void> _loadData() async {
    try {
      final info = await WenkuApi().fetchNovelInfo(widget.bookId);
      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = "加载失败: $e";
        });
      }
    }
  }

  // 🔥 点击收藏/取消收藏
  Future<void> _toggleFavorite(bool isFavorited) async {
    if (_info == null) return;

    if (isFavorited) {
      await BookshelfManager.removeBook(widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已移出书架")));
      }
    } else {
      await BookshelfManager.addBook(_info!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已加入书架")));
      }
    }
    // 不需要手动 setState，Hive 监听器会自动刷新 UI
  }

  // 🔥 直接跳转阅读页 (继续阅读)
  void _continueReading(String chapterId, String chapterTitle) {
    if (_info == null) return;

    // 1. 手动拼凑 baseUrl
    int id = int.tryParse(widget.bookId) ?? 0;
    int subDir = id ~/ 1000;
    String baseUrl = "https://www.wenku8.net/novel/$subDir/$id/";

    // 2. 构造 Chapter 对象
    final chapter = Chapter(
      cid: chapterId,
      title: chapterTitle,
      url: "$chapterId.htm",
    );

    // 3. 跳转
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderPage(
          chapter: chapter,
          baseUrl: baseUrl,
          bookId: widget.bookId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 使用 ValueListenableBuilder 监听 Hive 数据库
    // 只要书架数据发生变化（添加、删除、更新进度），这里都会自动重绘
    return ValueListenableBuilder(
      valueListenable: BookshelfManager.box.listenable(),
      builder: (context, box, child) {

        // 获取当前书籍在本地的状态
        final shelfBook = box.get(widget.bookId);
        final bool isFavorited = shelfBook != null;
        // 判断是否有阅读记录 (既要已收藏，又要有章节ID)
        final bool hasHistory = isFavorited && shelfBook.lastReadChapterId.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title ?? "小说详情"),
            actions: [
              // 收藏按钮
              if (!_isLoading && _info != null)
                IconButton(
                  icon: Icon(
                    isFavorited ? Icons.favorite : Icons.favorite_border,
                    color: isFavorited ? Colors.red : null,
                  ),
                  onPressed: () => _toggleFavorite(isFavorited),
                ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMsg.isNotEmpty
              ? Center(child: Text(_errorMsg))
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 顶部信息区
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 封面
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _info!.coverUrl.isNotEmpty
                              ? _info!.coverUrl
                              : (widget.coverUrl ?? ""),
                          width: 100,
                          height: 140,
                          fit: BoxFit.cover,
                          httpHeaders: const {
                            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                          },
                          errorWidget: (_, __, ___) => Container(color: Colors.grey, width: 100, height: 140),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 右侧文字
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _info!.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text("作者: ${_info!.author}"),
                            const SizedBox(height: 4),
                            Text("状态: ${_info!.status}"),
                            const SizedBox(height: 4),
                            Text("更新: ${_info!.lastUpdate}"),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              children: _info!.tags.map((tag) => Chip(
                                label: Text(tag, style: const TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              )).toList(),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                const Divider(),

                // 2. 操作按钮区
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CatalogPage(
                                      bookId: widget.bookId,
                                      title: _info!.title,
                                    )
                                )
                            );
                          },
                          icon: const Icon(Icons.list),
                          label: const Text("查看目录"),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          // 🔥 核心逻辑：有历史则继续阅读，无历史则进入目录
                          onPressed: hasHistory
                              ? () => _continueReading(shelfBook.lastReadChapterId, shelfBook.lastReadChapter)
                              : () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => CatalogPage(
                                      bookId: widget.bookId,
                                      title: _info!.title,
                                    )
                                )
                            );
                          },
                          icon: Icon(hasHistory ? Icons.history_edu : Icons.book),
                          label: Text(hasHistory ? "继续阅读" : "开始阅读"),
                        ),
                      ),
                    ],
                  ),
                ),

                // 🔥 显示上次阅读的章节提示
                if (hasHistory)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 24),
                    child: Text(
                      "上次读到: ${shelfBook.lastReadChapter}",
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),

                const Divider(),

                // 3. 简介
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("内容简介", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        _info!.introduction,
                        style: const TextStyle(height: 1.5, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}