import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:path_provider/path_provider.dart'; // 用於查找存儲路徑
import '../models/login_status.dart';
import '../models/novel.dart';
import '../models/volume.dart';
import '../utils/wenku_parser.dart'; // 引用你的 Parser
import '../models/novel_info.dart';

class WenkuApi {
  static const String baseUrl = 'https://www.wenku8.net';

  late Dio _dio;
  late PersistCookieJar _cookieJar; // 🔥 改用持久化 CookieJar

  // 單例模式
  static final WenkuApi _instance = WenkuApi._internal();
  factory WenkuApi() => _instance;

  WenkuApi._internal() {
    _dio = Dio(BaseOptions(
      responseType: ResponseType.bytes,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: true,
      headers: {
        // 使用 Android 瀏覽器 User-Agent (兼容性最好)
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        'Referer': baseUrl,
        'Connection': 'keep-alive',
      },
      validateStatus: (status) => true, // 允許所有狀態碼，防止報錯中斷
    ));


    // 添加拦截器，实现自动延时 (防封号)
    _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 打印请求路径，方便观察频率
          print("⏳ 准备请求: ${options.uri.path}");

          // 强制等待 500 毫秒 (半秒)，给服务器喘口气的机会
          // 如果还被封，可以改到 1000 或 2000
          await Future.delayed(const Duration(milliseconds: 200));

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // 如果遇到 Connection closed，尝试打印提示
          if (e.message != null && e.message!.contains("Connection closed")) {
            print("🚨 检测到连接中断，可能是请求过快被服务器阻断！请稍后重试。");
          }
          return handler.next(e);
        }
    ));

    init();

  }

  /// 🚀 初始化方法：在 App 啟動時調用
  /// 作用：設置 Cookie 存儲位置，實現"記住登錄狀態"
  Future<void> init() async {
    try {
      // 1. 獲取 App 的文檔目錄
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String appDocPath = appDocDir.path;

      // 2. 創建持久化 CookieJar，保存在 .cookies 文件夾下
      _cookieJar = PersistCookieJar(
          storage: FileStorage("$appDocPath/.cookies/")
      );

      // 3. 綁定到 Dio
      _dio.interceptors.add(CookieManager(_cookieJar));

      print("API: 持久化 Cookie 系統初始化完成");
    } catch (e) {
      print("API: Cookie 初始化失敗: $e");
      // 如果失敗，降級使用內存 Cookie (至少能跑，雖然重啟會掉)
      _dio.interceptors.add(CookieManager(CookieJar()));
    }
  }

  /// ---------------------------------------------------------
  /// 🟢 登錄功能
  /// ---------------------------------------------------------
  Future<LoginStatus> login(String username, String password) async {
    print("API: 開始登錄...");
    try {
      const loginUrl = '$baseUrl/login.php';

      final formData = FormData.fromMap({
        'username': username,
        'password': password,
        'usecookie': '315360000', // 設置為 10 年，讓服務器也記住我們
        'action': 'login',
        'submit': '登录'
      });

      final response = await _dio.post(
          loginUrl,
          data: formData,
          options: Options(contentType: Headers.formUrlEncodedContentType)
      );

      final html = gbk.decode(response.data);

      // 簡單判斷登錄結果
      if (html.contains("登录成功") || html.contains("点击此处")) {
        print("API: 登錄成功！Cookie 已保存到硬盤。");
        return LoginStatus.success;
      }

      // 調用 Parser 判斷具體錯誤 (如果 Parser 裡有此方法)
      return WenkuParser.parseLoginResult(html);

    } catch (e) {
      print("Login Error: $e");
      return LoginStatus.unknownError;
    }
  }

  // ---------------------------------------------------------
  // 🟢 获取小说列表 (支持分页、分类、排序)
  // ---------------------------------------------------------
  Future<List<Novel>> fetchTopList({
    int page = 1,           // 页码，默认第1页
    String? classId,        // 分类ID (如 "1", "2")，null 表示全部
    String sort = "lastupdate", // 排序 (lastupdate, postdate, goodnum 等)
  }) async {
    // print("API: 请求列表 - 第 $page 页, 分类: $classId"); // 调试用
    try {
      // 动态构建 URL
      String url = '$baseUrl/modules/article/articlelist.php?page=$page&sort=$sort';

      // 如果有分类 ID，拼接到 URL 后面
      if (classId != null && classId.isNotEmpty && classId != "0") {
        url += '&class=$classId';
      }

      final response = await _dio.get(url);

      // 解码 (GBK)
      String html = "";
      try {
        html = gbk.decode(response.data);
      } catch (e) {
        html = String.fromCharCodes(response.data);
      }

      // 检查登录状态
      if (html.contains("请输入登录帐号") || html.contains("您需要登录") || html.contains("403 Forbidden")) {
        throw 'NEED_LOGIN';
      }

      // 调用之前写好的 Parser
      List<Novel> novels = WenkuParser.parseArticleList(html);

      // print("API: 第 $page 页获取到 ${novels.length} 本");
      return novels;

    } catch (e) {
      if (e == 'NEED_LOGIN') rethrow;
      print("API List Error: $e");
      rethrow;
    }
  }

  /// ---------------------------------------------------------
  /// 🟢 獲取章節目錄
  /// ---------------------------------------------------------
  Future<List<Volume>> fetchChapters(String bookId) async {
    try {
      int id = int.tryParse(bookId) ?? 0;
      int subDir = id ~/ 1000;
      final url = "$baseUrl/novel/$subDir/$id/index.htm";

      final response = await _dio.get(url);
      final html = gbk.decode(response.data);

      return WenkuParser.parseVolumes(html);
    } catch (e) {
      print("Fetch Chapters Error: $e");
      rethrow;
    }
  }

  /// ---------------------------------------------------------
  /// 🟢 獲取小說正文
  /// ---------------------------------------------------------
  Future<String> fetchContent(String fullUrl) async {
    try {
      final response = await _dio.get(fullUrl);
      final html = gbk.decode(response.data);

      return WenkuParser.parseContent(html);
    } catch (e) {
      print("Fetch Content Error: $e");
      return "加載失敗，請檢查網絡";
    }
  }

  // ---------------------------------------------------------
  // 📖 获取小说详细信息
  // ---------------------------------------------------------
  Future<NovelInfo> fetchNovelInfo(String bookId) async {
    try {
      // 小说详情页 URL: https://www.wenku8.net/book/1234.htm
      // 这是一个静态页面，不需要计算 subDir，直接拼
      final url = "$baseUrl/book/$bookId.htm";

      final response = await _dio.get(url);

      String html = "";
      try {
        html = gbk.decode(response.data);
      } catch (e) {
        html = String.fromCharCodes(response.data);
      }

      return WenkuParser.parseNovelInfo(html, bookId);

    } catch (e) {
      print("Fetch Info Error: $e");
      rethrow;
    }
  }

// ---------------------------------------------------------
  // 🔍 搜索小说 (支持搜书名和搜作者)
  // ---------------------------------------------------------
  // searchType 默认为 'articlename'，也可以传入 'author'
  Future<List<Novel>> searchNovels(String keyword, {String searchType = 'articlename'}) async {
    try {
      if (keyword.isEmpty) return [];

      // 1. 关键词转 GBK 编码
      // 这一步非常关键，如果不转码，中文搜索会失败
      List<int> gbkBytes = gbk.encode(keyword);
      // 将字节转换为 URL 编码格式 (%AB%CD)
      String searchKey = gbkBytes.map((b) => '%${b.toRadixString(16).toUpperCase()}').join('');

      // 2. 构建 URL
      // 参考你提供的 URL: .../search.php?searchtype=articlename&searchkey=heart
      // 并添加 charset=gbk 以确保服务器正确识别
      final url = '$baseUrl/modules/article/search.php?searchtype=$searchType&searchkey=$searchKey&charset=gbk';

      print("正在搜索: $url");

      final response = await _dio.get(url);

      // 3. 解码响应内容
      String html = "";
      try {
        html = gbk.decode(response.data);
      } catch (e) {
        // 如果 GBK 解码失败，尝试 UTF-8 或直接转换
        html = String.fromCharCodes(response.data);
      }

      // 4. 使用新的 Grid 解析器！
      return WenkuParser.parseSearchResult(html);

    } catch (e) {
      print("Search Error: $e");
      return [];
    }
  }
}