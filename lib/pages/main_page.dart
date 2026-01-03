import 'package:flutter/material.dart';
import 'bookshelf_page.dart';
import 'home_page.dart'; // 你之前创建的排行榜页
import 'profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 默认选中第 1 项（中间的“阅读/首页”）
  int _currentIndex = 1;

  // 页面列表
  final List<Widget> _pages = const [
    BookshelfPage(), // index 0
    HomePage(),      // index 1
    ProfilePage(),   // index 2
  ];

  @override
  Widget build(BuildContext context) {
    // 获取屏幕宽度，用于判断是平板还是手机
    final width = MediaQuery.of(context).size.width;
    // 阈值设为 640，大于它认为是平板/桌面
    final isWideScreen = width > 640;

    return Scaffold(
      // === 手机模式：底部导航栏 ===
      bottomNavigationBar: isWideScreen
          ? null // 宽屏时隐藏底部栏
          : BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.local_library), label: '书架'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '阅读'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
        ],
      ),

      // === 主体内容 ===
      body: Row(
        children: [
          // === 平板模式：侧边导航栏 ===
          if (isWideScreen)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) => setState(() => _currentIndex = index),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.local_library), label: Text('书架')),
                NavigationRailDestination(icon: Icon(Icons.explore), label: Text('阅读')),
                NavigationRailDestination(icon: Icon(Icons.person), label: Text('我的')),
              ],
            ),

          if (isWideScreen) const VerticalDivider(thickness: 1, width: 1),

          // === 页面内容显示区 ===
          Expanded(
            // IndexedStack 可以保持页面状态（比如滚动位置、输入框内容）
            // 切换 Tab 时不会销毁页面
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}