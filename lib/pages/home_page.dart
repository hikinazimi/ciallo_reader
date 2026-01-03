import 'package:flutter/material.dart';
// 1. 導入我們封裝好的圖片組件 (確保你已經創建了 lib/widgets/wenku_image.dart)
import '../widgets/wenku_image.dart';
import '../models/novel.dart';
import '../api/wenku_api.dart';
import '../utils/category_constants.dart';
import 'book_detail_page.dart';
import 'login_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // 數據源
  List<Novel> _novels = [];

  // 狀態控制
  bool _isLoading = true;      // 首次加載
  bool _isLoadingMore = false; // 加載更多
  String _errorMsg = '';       // 錯誤信息
  bool _isLoginRequired = false; // 🔥 核心狀態：是否需要登錄

  // 分頁與篩選
  int _currentPage = 1;
  String _currentClassId = "0";
  bool _hasMore = true; // 是否還有數據

  // 控制器
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 初始化 Tab
    _tabController = TabController(length: CategoryConstants.list.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newClassId = CategoryConstants.list[_tabController.index].key;
        if (newClassId != _currentClassId) {
          _changeCategory(newClassId);
        }
      }
    });

    // 監聽滾動 (觸底加載邏輯)
    _scrollController.addListener(() {
      if (!_hasMore || _isLoadingMore || _isLoading || _isLoginRequired) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      // 設置 200px 的緩衝區，提升體驗
      if (currentScroll >= maxScroll - 200) {
        _loadMoreData();
      }
    });

    // 初始加載
    _loadData(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 🔄 核心數據加載邏輯
  // ---------------------------------------------------------
  Future<void> _loadData({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final data = await WenkuApi().fetchTopList(
        page: _currentPage,
        classId: _currentClassId,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _novels = data;
          } else {
            // 去重添加
            final ids = _novels.map((e) => e.id).toSet();
            for (var novel in data) {
              if (!ids.contains(novel.id)) {
                _novels.add(novel);
              }
            }
          }

          _isLoading = false;
          _isLoadingMore = false;
          _errorMsg = '';
          _isLoginRequired = false; // ✅ 獲取成功，說明無需登錄

          if (data.length < 10) {
            _hasMore = false;
          }
        });

        // 🔥 大螢幕適配：檢查是否填滿，未填滿則自動加載下一頁
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkIfScreenIsFull();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;

          // 🔥 攔截登錄錯誤，不跳轉，只更新 UI 狀態
          if (e.toString().contains('NEED_LOGIN')) {
            _isLoginRequired = true;
            _errorMsg = "";
          } else {
            if (refresh) _errorMsg = "加載失敗: $e";
          }
        });
      }
    }
  }

  // 檢查螢幕填充情況
  void _checkIfScreenIsFull() {
    if (!_hasMore || _isLoadingMore || _novels.isEmpty || _isLoginRequired) return;
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    // 如果內容高度還不夠滾動 (maxScroll 很小)，自動請求下一頁
    if (maxScroll < 100) {
      // print("UI: 內容過少，自動加載下一頁...");
      _loadMoreData();
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadData(refresh: false);
  }

  void _changeCategory(String classId) {
    setState(() {
      _currentClassId = classId;
      _novels.clear();
      _isLoading = true;
    });
    _loadData(refresh: true);
  }

  // 處理手動點擊登錄
  void _handleLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    // 登錄成功返回後，刷新列表
    if (result == true) {
      setState(() => _isLoginRequired = false);
      _loadData(refresh: true);
    }
  }

  // ---------------------------------------------------------
  // 🎨 UI 構建部分
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文庫8'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchPage())
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: CategoryConstants.list.map((e) => Tab(text: e.value)).toList(),
        ),
      ),
      // 使用 _buildBody 方法根據狀態返回不同界面
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. 加載中
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. 🔥 需要登錄 (顯示占位圖和按鈕)
    if (_isLoginRequired) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "此內容需要登錄才能查看",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _handleLogin,
              icon: const Icon(Icons.login),
              label: const Text("立即登錄"),
            ),
          ],
        ),
      );
    }

    // 3. 發生錯誤
    if (_errorMsg.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMsg, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _loadData(refresh: true),
              child: const Text("重試"),
            )
          ],
        ),
      );
    }

    // 4. 正常顯示列表
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    if (width > 600) crossAxisCount = 4;
    if (width > 900) crossAxisCount = 5;

    return RefreshIndicator(
      onRefresh: () => _loadData(refresh: true),
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _novels.length + 1,
        itemBuilder: (context, index) {
          // 底部狀態條
          if (index == _novels.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: _hasMore
                    ? const CircularProgressIndicator()
                    : const Text("已經到底啦 ~", style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          final novel = _novels[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailPage(
                    bookId: novel.id,
                    title: novel.title, // 傳遞標題和封面，優化跳轉體驗
                    coverUrl: novel.coverUrl,
                  ),
                ),
              );
            },
            child: Card(
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    // 🔥 2. 使用我們封裝好的 WenkuImage 組件
                    // 自動處理：緩存、防盜鏈 Header、加載動畫、錯誤佔位
                    child: WenkuImage(
                      url: novel.coverUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text(
                      novel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}