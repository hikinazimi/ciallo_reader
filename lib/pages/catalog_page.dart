import 'package:flutter/material.dart';
import '../models/volume.dart';
import '../models/chapter.dart';
import '../api/wenku_api.dart'; // ✅ 引入 API
import 'reader_page.dart';

class CatalogPage extends StatefulWidget {
  final String bookId;
  final String? title;

  const CatalogPage({
    super.key,
    required this.bookId,
    this.title,
  });

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  List<Volume> volumes = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 依然保留这个辅助方法，用于给 ReaderPage 计算 baseUrl
  String getIndexUrl(String bookId) {
    int id = int.tryParse(bookId) ?? 0;
    int subDir = id ~/ 1000;
    return "https://www.wenku8.net/novel/$subDir/$id/index.htm";
  }

  Future<void> _loadData() async {
    try {
      // ✅ 使用 API 请求数据，不再直接写 HTTP 请求
      final list = await WenkuApi().fetchChapters(widget.bookId);

      if (mounted) {
        setState(() {
          volumes = list;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "加载失败: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? "目录")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
          ? Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(errorMessage),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _loadData, child: const Text("重试"))
        ],
      ))
          : ListView.builder(
        itemCount: volumes.length,
        itemBuilder: (context, index) {
          final volume = volumes[index];
          return ExpansionTile(
            title: Text(volume.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            initiallyExpanded: index == 0, // 默认只展开第一卷
            children: volume.chapters.map((chapter) {
              return ListTile(
                title: Text(chapter.title),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 30, right: 10),
                onTap: () {
                  // 计算 baseUrl 传给阅读页
                  String fullIndexUrl = getIndexUrl(widget.bookId);
                  String baseUrl = fullIndexUrl.replaceAll("index.htm", "");

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
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}