import 'package:flutter/material.dart';
import '../api/wenku_api.dart';
import '../models/novel.dart';
import 'book_detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 控制器
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // 状态数据
  List<Novel> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  // 搜索类型：默认为 articlename (小说标题)，可选 author (作者)
  String _searchType = 'articlename';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 执行搜索逻辑
  Future<void> _doSearch() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入搜索关键词')),
      );
      return;
    }

    // 收起键盘
    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _results = [];
    });

    try {
      // 调用 API 进行搜索
      final list = await WenkuApi().searchNovels(keyword, searchType: _searchType);

      if (mounted) {
        setState(() {
          _results = list;
          if (list.isEmpty) {
            _errorMessage = "未找到相关结果";
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "搜索发生错误，请检查网络或重试";
        });
      }
      print("Search Page Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取主题颜色，方便适配深色模式
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // 1. 左侧下拉选择框 (搜书名/搜作者)
              _buildTypeDropdown(),

              // 分割线
              Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey[400]
              ),

              // 2. 右侧输入框
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true, // 进入页面自动聚焦
                  textInputAction: TextInputAction.search, // 键盘显示搜索按钮
                  onSubmitted: (_) => _doSearch(), // 点击键盘搜索键触发
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: "输入关键词...",
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),

              // 清除按钮 (仅当有内容时显示)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox();
                  return IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: () {
                      _controller.clear();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        actions: [
          // 顶部搜索按钮
          TextButton(
            onPressed: _doSearch,
            child: const Text("搜索", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // 构建下拉菜单
  Widget _buildTypeDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: Theme.of(context).cardColor,
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: _searchType,
            icon: const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14
            ),
            items: const [
              DropdownMenuItem(value: 'articlename', child: Text('书名')),
              DropdownMenuItem(value: 'author', child: Text('作者')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _searchType = value;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  // 构建主体内容
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 10),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _doSearch,
              child: const Text("重试"),
            )
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return GestureDetector(
        onTap: () => _focusNode.unfocus(), // 点击空白处收起键盘
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.manage_search, size: 80, color: Colors.black12),
              SizedBox(height: 10),
              Text("输入书名或作者开始搜索", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
      itemBuilder: (context, index) {
        final novel = _results[index];
        return InkWell(
          onTap: () {
            // 调试日志
            print("正在跳转 ID: '${novel.id}'");

            if (novel.id.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("书籍ID解析错误，无法打开"))
              );
              return;
            }
            // 跳转详情页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailPage(bookId: novel.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            height: 120, // 高度适配简介
            child: Row(
              children: [
                // 1. 封面图 (带 Headers)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: CachedNetworkImage(
                      imageUrl: novel.coverUrl,
                      fit: BoxFit.cover,

                      // 🔥🔥🔥 关键：必须带上 Header，否则下载失败，缓存无效
                      httpHeaders: const {
                        "Referer": "https://www.wenku8.net/",
                        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                      },

                      // 1. 加载时的占位图 (转圈圈)
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)
                            )
                        ),
                      ),

                      // 2. 加载失败的占位图 (显示破碎图标)
                      errorWidget: (context, url, error) {
                        return Container(
                          color: Colors.grey[300],
                          alignment: Alignment.center,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.grey, size: 24),
                              SizedBox(height: 4),
                              Text("暂无", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        );
                      },

                      // 3. 淡入动画 (让体验更丝滑)
                      fadeInDuration: const Duration(milliseconds: 300),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. 文字信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Text(
                        novel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 简介
                      Expanded(
                        child: Text(
                          novel.introduction,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                        ),
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