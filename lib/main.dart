import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 引入
import 'pages/main_page.dart';
import 'api/wenku_api.dart';
import 'models/bookshelf_novel.dart'; // 引入模型
import 'utils/reader_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1. 初始化 Hive
  await Hive.initFlutter();

  // 2. 注册刚才生成的适配器
  Hive.registerAdapter(BookshelfNovelAdapter());

  // 3. 打开书架的盒子 (Box)，相当于打开一张表
  await Hive.openBox<BookshelfNovel>('bookshelfBox');

  await ReaderSettings.init();

  // 🔥 启动前先让 API 准备好硬盘存储
  await WenkuApi().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ciallo Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 🔥 关键修改：启动页改为 MainPage (带有底部导航栏的页面)
      // MainPage 会默认加载 HomePage (排行榜)，不需要传参数
      home: const MainPage(),
    );
  }
}