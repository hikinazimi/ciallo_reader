import 'package:html/parser.dart' as parser;
import '../models/novel.dart';
import '../models/login_status.dart';
import '../models/volume.dart';
import '../models/chapter.dart';
import '../models/novel_info.dart';

/// 对应原项目的 [Wenku8Parser] 对象
class WenkuParser {

  // ---------------------------------------------------------
  // 1. 防爬虫/错误检测
  // 对应 Kotlin: fun isInFiveSecond(html: String): Boolean
  // ---------------------------------------------------------
  static bool isSystemError(String html) {
    try {
      final document = parser.parse(html);
      final blockTitle = document.querySelector('.blocktitle');
      if (blockTitle != null) {
        final text = blockTitle.text.trim();
        // 原代码判断了简繁体两种情况
        return text == "出现错误！" || text == "出現錯誤！";
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  // ---------------------------------------------------------
  // 2. 登录结果解析
  // 对应 Kotlin: fun isLoginInfoCorrect / isLoginSuccessful
  // ---------------------------------------------------------
  static LoginStatus parseLoginResult(String html) {
    final document = parser.parse(html);

    // 优先检查成功 (isLoginSuccessful)
    try {
      final title = document.querySelector('.blocktitle')?.text.trim();
      if (title == "登录成功" || title == "登錄成功") {
        return LoginStatus.success;
      }
    } catch (_) {}

    // 检查具体错误 (isLoginInfoCorrect)
    String t = "";
    try {
      // 尝试获取 .blockcontent 下的 div
      t = document.querySelector('.blockcontent div')?.text ?? "";
      if (t.isEmpty) {
        // 尝试获取 #content caption
        t = document.querySelector('#content caption')?.text ?? "";
      }
    } catch (_) {}

    if (t.contains("用户不存在") || t.contains("用戶不存在")) return LoginStatus.userNotFoundError;
    if (t.contains("密码错误") || t.contains("密碼錯誤")) return LoginStatus.passwordError;
    if (t.contains("用户登录") || t.contains("用戶登錄")) return LoginStatus.unknownError; // 通常是被踢回登录页
    if (t.contains("校验码错误") || t.contains("校驗碼錯誤")) return LoginStatus.checkCodeError;

    // 如果没有错误信息且没显示成功，但在登录流程中，暂定未知
    return LoginStatus.unknownError;
  }

  // ---------------------------------------------------------
  // 3. 通用列表解析 (用于排行榜、分类列表)
  // 对应 Kotlin: fun parseToList(html: String, node: String): List<NovelCover>
  // ---------------------------------------------------------
  static List<Novel> parseToList(String html) {
    final result = <Novel>[];
    final document = parser.parse(html);

    final content = document.getElementById("content");
    if (content == null) return [];

    // 原代码逻辑：查找特定 style 的 div
    // style="width:373px;height:136px;float:left;margin:5px 0px 5px 5px;"
    // 在 Dart 中我们最好用更宽松的选择器，防止 style 只有微小差异
    final items = content.querySelectorAll('div[style*="width:373px"]');

    for (var novelItem in items) {
      try {
        // 解析图片
        var imgElement = novelItem.querySelector("img");
        var img = imgElement?.attributes['src'] ?? "";

        // 原代码逻辑：替换 http -> https
        if (img.startsWith("http://")) {
          img = img.replaceFirst("http://", "https://");
        }
        // 原代码逻辑：处理无封面图
        if (img == "/images/noimg.jpg") {
          img = "https://www.wenku8.net/modules/article/images/nocover.jpg";
        }

        // 解析标题
        final title = novelItem.querySelector("a")?.attributes['title'] ?? "";

        // 解析详情页 URL
        final linkElement = novelItem.querySelector("div a"); // 原代码: getElementsByTag("div").eq(0).select("a")
        final detailUrlRaw = linkElement?.attributes['href'] ?? "";
        // 补全 URL
        final detailUrl = detailUrlRaw.startsWith("http")
            ? detailUrlRaw
            : "https://www.wenku8.net$detailUrlRaw";

        // 解析 AID (核心 ID)
        String aid = "";
        try {
          if (detailUrl.contains("book/") && detailUrl.contains(".htm")) {
            final start = detailUrl.indexOf("book/") + 5;
            final end = detailUrl.indexOf(".htm");
            aid = detailUrl.substring(start, end);
          } else if (detailUrl.contains("aid=") && detailUrl.contains("&bid=")) {
            final start = detailUrl.indexOf("aid=") + 4;
            final end = detailUrl.indexOf("&bid=");
            aid = detailUrl.substring(start, end);
          }
        } catch (e) {
          // 解析 ID 失败
        }

        if (aid.isNotEmpty) {
          result.add(Novel(
              id: aid,
              title: title,
              coverUrl: img,
              url: detailUrl
          ));
        }
      } catch (e) {
        continue;
      }
    }
    return result;
  }

  // ---------------------------------------------------------
  // 4. 首页推荐解析 (结构最复杂的部分)
  // 对应 Kotlin: fun getRecommend(html: String): List<HomeBlock>
  // ---------------------------------------------------------


  static List<HomeBlock> getRecommend(String html) {
    final document = parser.parse(html);
    final centers = document.getElementById("centers");
    if (centers == null) return [];

    final homeBlockList = <HomeBlock>[];

    // --- Part 1: 解析 #centers 下的 .block (Kotlin循环 1..3) ---
    final blocks = centers.querySelectorAll(".block");
    // Kotlin 逻辑是 1..3 (跳过第0个)，我们检查长度
    for (var i = 1; i <= 3 && i < blocks.length; i++) {
      final block = blocks[i];
      final blockList = <Novel>[];

      // 获取标题
      var blockTitle = block.querySelector(".blocktitle")?.text ?? "";
      if (i == 1) blockTitle = blockTitle.split("(").first; // 对应 Kotlin: substringBefore("(")

      // 获取内容 items
      final items = block.querySelectorAll("div[style*='width: 95px']");

      for (var j in items) {
        try {
          final links = j.querySelectorAll("a");
          if (links.length < 2) continue;

          final title = links[1].text;
          var img = j.querySelector("img")?.attributes['src'] ?? "";

          if (!img.startsWith("https")) {
            img = img.replaceAll("http://", "https://");
          }

          final url = links[0].attributes['href'] ?? "";
          String aid = "";
          if (url.contains("book/") && url.contains(".htm")) {
            aid = url.substring(url.indexOf("book/") + 5, url.indexOf(".htm"));
          }

          blockList.add(Novel(id: aid, title: title, coverUrl: img, url: url));
        } catch (_) {}
      }
      homeBlockList.add(HomeBlock(title: blockTitle, novels: blockList));
    }

    // --- Part 2: 解析 .main 下的内容 (Kotlin循环 2..3) ---
    final mainDivs = document.querySelectorAll("div.main");

    // 正则校验图片 (对应 Kotlin regex)
    // RegExp regex = RegExp(r"^(http|https)://[^\s/$.?#].[^\s]*$");

    for (var i = 2; i <= 3 && i < mainDivs.length; i++) {
      final b = mainDivs[i];
      final blockList = <Novel>[];

      var blockTitle = b.querySelector(".blocktitle")?.text ?? "";
      if (i == 3) blockTitle = blockTitle.split("(").first;

      final items = b.querySelectorAll("div[style*='width: 95px']");

      for (var j in items) {
        try {
          final links = j.querySelectorAll("a");
          if (links.length < 2) continue;

          final title = links[1].text;
          var img = j.querySelector("img")?.attributes['src'] ?? "";

          // Kotlin 代码这里做了正则校验 throw IllegalArgumentException，Dart 里我们简单判断非空
          if (img.isEmpty) continue;

          if (!img.startsWith("https")) {
            img = img.replaceAll("http://", "https://");
          }

          final url = links[0].attributes['href'] ?? "";
          String aid = "";
          if (url.contains("book/") && url.contains(".htm")) {
            aid = url.substring(url.indexOf("book/") + 5, url.indexOf(".htm"));
          }

          blockList.add(Novel(id: aid, title: title, coverUrl: img, url: url));
        } catch (_) {
          continue;
        }
      }
      homeBlockList.add(HomeBlock(title: blockTitle, novels: blockList));
    }

    return homeBlockList;
  }
  static List<Volume> parseVolumes(String html) {
    final vcsslist = <Volume>[];
    final document = parser.parse(html);

    // 获取所有 td 标签，文库8的目录结构是平铺在 td 里的
    final tds = document.getElementsByTagName("td");

    var tempVcss = Volume.empty(); // 需确保 Volume 模型中有 empty() 工厂方法
    var tempCcssList = <Chapter>[];

    bool isFirst = true; // 防止第一卷之前产生空数据

    for (var td in tds) {
      // 1. 判断是否是卷名 (class="vcss")
      if (td.classes.contains('vcss')) {
        String vcssTitle = td.text.trim();

        if (!isFirst) {
          // 保存上一卷的数据
          // 注意：必须创建一个新的 List，否则引用会被覆盖
          tempVcss.chapters = List.from(tempCcssList);
          vcsslist.add(tempVcss);

          // 重置临时数据
          tempVcss = Volume(title: vcssTitle, chapters: []);
          tempCcssList = [];
        } else {
          // 是第一个遇到的卷名，更新当前卷名即可
          tempVcss = Volume(title: vcssTitle, chapters: []);
          isFirst = false;
        }
      }
      // 2. 判断是否是章节 (class="ccss")
      else if (td.classes.contains('ccss')) {
        final anchors = td.getElementsByTagName("a");
        for (var a in anchors) {
          String ccssTitle = a.text.trim();
          String ccssHtml = a.attributes['href'] ?? "";

          if (ccssTitle.isEmpty) continue;

          // 解析 CID (Chapter ID)
          // 链接格式通常是: ...&cid=1234 或 1234.htm
          String cid = "";
          if (ccssHtml.contains("&cid=")) {
            cid = ccssHtml.split("&cid=").last;
          } else if (ccssHtml.endsWith(".htm")) {
            cid = ccssHtml.substring(ccssHtml.lastIndexOf('/') + 1, ccssHtml.lastIndexOf('.'));
          }

          tempCcssList.add(Chapter(
            cid: cid,
            title: ccssTitle,
            url: ccssHtml,
          ));
        }
      }
    }

    // 循环结束后，必须把最后一卷添加进去
    if (tempCcssList.isNotEmpty || !isFirst) {
      tempVcss.chapters = List.from(tempCcssList);
      vcsslist.add(tempVcss);
    }

    return vcsslist;
  }
// ---------------------------------------------------------
  // 📖 正文解析器
  // 职责：提取小说正文，清洗 HTML 标签
  // ---------------------------------------------------------
  static String parseContent(String html) {
    try {
      final document = parser.parse(html);

      // 1. 找到正文容器
      var contentDiv = document.getElementById("content");
      if (contentDiv == null) return "解析失败：未找到正文内容";

      // 2. 移除广告元素 (如果有 ul/div 混在里面)
      contentDiv.querySelectorAll('ul, div.block').forEach((e) => e.remove());

      // 3. 处理换行
      // 文库8的正文换行通常是 <br> 或 <br />
      String text = contentDiv.innerHtml;

      // 将 <br> 替换为实际的换行符
      text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), "\n");

      // 4. 清洗 HTML 实体
      text = text.replaceAll("&nbsp;", " ");
      text = text.replaceAll("&amp;", "&");
      text = text.replaceAll("&lt;", "<");
      text = text.replaceAll("&gt;", ">");

      // 5. 移除所有剩余的 HTML 标签 (比如 <p>, <span> 等)
      text = text.replaceAll(RegExp(r'<[^>]*>'), "");

      // 6. 简单的排版优化
      // 移除开头结尾的空白，处理多重换行
      text = text.trim();
      text = text.replaceAll(RegExp(r'\n{3,}'), "\n\n"); // 把3个以上换行变成2个

      return text;

    } catch (e) {
      return "解析错误: $e";
    }
  }

  static List<Novel> parseHomeBlocks(String html) {
    final list = <Novel>[];
    final document = parser.parse(html);

    // 1. 全局查找所有 div
    final divs = document.querySelectorAll('div');

    for (var div in divs) {
      final style = div.attributes['style'] ?? "";

      // 2. 核心特征匹配：参考 Kotlin 文件中的 getRecommend 方法
      // Kotlin: select("div[style=float: left;text-align:center;width: 95px; height:155px;overflow:hidden;]")
      // 我们只要匹配到 "width: 95px" 或者是 "width:95px" 就可以确定这是封面块
      if (!style.contains("width: 95px") && !style.contains("width:95px")) {
        continue;
      }

      try {
        // 3. 提取链接
        // 结构通常是:
        // <div ...>
        //    <a href="..."><img src="..."></a> (图片链接)
        //    <br>
        //    <a href="...">书名</a> (文字链接)
        // </div>
        final links = div.getElementsByTagName("a");
        if (links.length < 2) continue; // 必须至少有两个链接

        final imgLink = links[0];  // 第一个是包着图片的链接
        final textLink = links[1]; // 第二个是包着书名的链接

        // --- 提取图片 ---
        var imgElement = imgLink.querySelector("img");
        if (imgElement == null) continue;

        String coverUrl = imgElement.attributes['src'] ?? "";
        // 参考 Kotlin: if (img.substring(0, 5) != "https")
        if (coverUrl.startsWith("http://")) {
          coverUrl = coverUrl.replaceFirst("http://", "https://");
        }

        // --- 提取标题 ---
        String title = textLink.text.trim();
        // 备份：如果文字取不到，取图片的 title 属性
        if (title.isEmpty) title = imgLink.attributes['title'] ?? "";

        // --- 提取链接和 ID ---
        String href = textLink.attributes['href'] ?? "";
        String aid = "";

        // 参考 Kotlin: aid = url.substring(url.indexOf("book/") + 5, url.indexOf(".htm"))
        if (href.contains("book/") && href.contains(".htm")) {
          aid = href.substring(href.indexOf("book/") + 5, href.indexOf(".htm"));
        }

        // --- 补全 URL ---
        String fullUrl = href.startsWith("http") ? href : "https://www.wenku8.net$href";

        if (aid.isNotEmpty && title.isNotEmpty) {
          list.add(Novel(
            id: aid,
            title: title,
            coverUrl: coverUrl,
            url: fullUrl,
          ));
        }
      } catch (e) {
        // 忽略解析错误的单项
        continue;
      }
    }

    // 去重 (首页不同板块可能会推荐同一本书)
    final uniqueIds = <String>{};
    final uniqueList = <Novel>[];
    for (var novel in list) {
      if (uniqueIds.add(novel.id)) {
        uniqueList.add(novel);
      }
    }

    return uniqueList;
  }


// ---------------------------------------------------------
  // ♻️ 恢复初始版解析器：直接从 HTML 标签提取图片
  // ---------------------------------------------------------
  static List<Novel> parseArticleList(String html) {
    final list = <Novel>[];
    final document = parser.parse(html);

    // 1. 找到页面上所有的 <a> 标签
    final allLinks = document.querySelectorAll('a');
    print("------- 正在开始解析列表，总链接数: ${allLinks.length} -------");

    for (var link in allLinks) {
      final href = link.attributes['href'] ?? "";
      if (href.contains("/book/") && href.contains(".htm")) {
        final imgTag = link.querySelector('img');

        // 🔍 测试点 1：打印每一个匹配到的详情页链接
        // print("检测到书籍链接: $href");

        if (imgTag != null) {
          String aid = "";
          int start = href.indexOf("book/") + 5;
          int end = href.indexOf(".htm");
          if (end > start) aid = href.substring(start, end);

          String title = link.attributes['tiptitle'] ?? link.attributes['title'] ?? "未知";
          String coverUrl = imgTag.attributes['src'] ?? "";

          // 🔍 测试点 2：关键日志！打印解析出来的原始图片地址
          print("✅ 成功解析书籍: $title | ID: $aid | 图片地址: $coverUrl");

          if (coverUrl.startsWith("//")) coverUrl = "https:$coverUrl";
          if (coverUrl.startsWith("http://")) coverUrl = coverUrl.replaceFirst("http://", "https://");

          list.add(Novel(
            id: aid,
            title: title,
            coverUrl: coverUrl,
            url: href.startsWith("http") ? href : "https://www.wenku8.net$href",
          ));
        }
      }
    }
    print("------- 解析结束，共计抓取到书籍: ${list.length} 本 -------");
    for (var link in allLinks) {
      try {
        final href = link.attributes['href'] ?? "";

        // 匹配详情页链接：包含 /book/ 且以 .htm 结尾
        if (href.contains("/book/") && href.contains(".htm")) {

          // 2. 关键点：寻找这个链接内部是否包含 <img> 标签
          // 之前的代码能出图是因为直接抓取了网页自带的图片地址
          final imgTag = link.querySelector('img');
          if (imgTag == null) continue; // 只有带图片的链接才解析，防止重复

          // 提取 ID
          String aid = "";
          int start = href.indexOf("book/") + 5;
          int end = href.indexOf(".htm");
          if (end > start) aid = href.substring(start, end);
          if (aid.isEmpty) continue;

          // 提取标题 (优先取 tiptitle)
          String title = link.attributes['tiptitle'] ?? link.attributes['title'] ?? "";
          if (title.isEmpty) title = "未知小说 $aid";

          // 提取图片原始地址
          String coverUrl = imgTag.attributes['src'] ?? "";

          // 处理协议头
          if (coverUrl.startsWith("//")) {
            coverUrl = "https:$coverUrl";
          } else if (coverUrl.startsWith("http://")) {
            coverUrl = coverUrl.replaceFirst("http://", "https://");
          }

          // 补全 URL
          String fullUrl = href.startsWith("http") ? href : "https://www.wenku8.net$href";

          list.add(Novel(
            id: aid,
            title: title,
            coverUrl: coverUrl,
            url: fullUrl,
          ));
        }
      } catch (e) {
        continue;
      }
    }

    // 去重
    final uniqueIds = <String>{};
    final uniqueList = <Novel>[];
    for (var novel in list) {
      if (uniqueIds.add(novel.id)) {
        uniqueList.add(novel);
      }
    }

    return uniqueList;
  }
  /// 私有辅助方法：根据链接位置提取附近的标题
  static String _extractTitleContext(String html, String href, int id) {
    try {
      int hrefIndex = html.indexOf(href);
      if (hrefIndex == -1) return "小说 $id";

      // 截取链接附近 200 个字符
      int searchEnd = hrefIndex + 200;
      if (searchEnd > html.length) searchEnd = html.length;
      String snippet = html.substring(hrefIndex, searchEnd);

      // 优先找 tiptitle="..."
      final tipMatch = RegExp(r'tiptitle="([^"]+)"').firstMatch(snippet);
      if (tipMatch != null) return tipMatch.group(1) ?? "小说 $id";

      // 其次找 title="..."
      final titleMatch = RegExp(r'title="([^"]+)"').firstMatch(snippet);
      if (titleMatch != null) return titleMatch.group(1) ?? "小说 $id";

      return "小说 $id";
    } catch (e) {
      return "小说 $id";
    }
  }

  // ---------------------------------------------------------
  // 📖 解析小说详情页
  // ---------------------------------------------------------
  static NovelInfo parseNovelInfo(String html, String bookId) {
    try {
      final document = parser.parse(html);
      final content = document.getElementById("content");
      if (content == null) return NovelInfo.empty();

      final tables = content.getElementsByTagName("table");
      if (tables.isEmpty) return NovelInfo.empty();

      // 标题
      String title = "";
      try {
        title = tables[0].getElementsByTagName("span")[0].getElementsByTagName("b")[0].text.trim();
      } catch (e) {
        title = "未知小说";
      }

      // 作者、状态、更新
      String author = "未知";
      String status = "未知";
      String lastUpdate = "未知";
      try {
        final tds = tables[0].getElementsByTagName("td");
        for (var td in tds) {
          final text = td.text.trim();
          if (text.startsWith("小说作者：")) {
            author = text.replaceAll("小说作者：", "").trim();
          } else if (text.startsWith("文章状态：")) {
            status = text.replaceAll("文章状态：", "").trim();
          } else if (text.startsWith("最后更新：")) {
            lastUpdate = text.replaceAll("最后更新：", "").trim();
          }
        }
      } catch (e) {}

      // 封面
      String coverUrl = "";
      final img = content.querySelector("img");
      if (img != null) {
        coverUrl = img.attributes['src'] ?? "";
        if (coverUrl.startsWith("http://")) {
          coverUrl = coverUrl.replaceFirst("http://", "https://");
        }
      }

      // 简介
      String intro = "暂无简介";
      try {
        final spans = content.getElementsByTagName("span");
        for (var span in spans) {
          if (span.text.contains("内容简介")) {
            intro = span.parent?.text ?? "";
            intro = intro.replaceAll("内容简介：", "").trim();
            break;
          }
        }
      } catch (e) {}

      // Tags
      List<String> tags = [];
      try {
        final tds = tables[0].getElementsByTagName("td");
        for (var td in tds) {
          if (td.text.contains("小说类别：")) {
            tags.add(td.text.replaceAll("小说类别：", "").trim());
          }
        }
      } catch(e) {}

      return NovelInfo(
        id: bookId,
        title: title,
        author: author,
        status: status,
        lastUpdate: lastUpdate,
        coverUrl: coverUrl,
        introduction: intro,
        tags: tags,
      );

    } catch (e) {
      return NovelInfo.empty();
    }
  }

// ---------------------------------------------------------
  // 🔍 终极混合解析器 (稳定版)
  // ---------------------------------------------------------
  static List<Novel> parseSearchResult(String html) {
    final list = <Novel>[];
    final document = parser.parse(html);
    final uniqueIds = <String>{}; // 用于去重

    // --- 策略 A: 尝试 Grid 布局解析 (为了获取简介) ---
    final gridItems = document.querySelectorAll('div[style*="width:373px"]');

    if (gridItems.isNotEmpty) {
      for (var div in gridItems) {
        try {
          final titleLink = div.querySelector("b a");
          if (titleLink == null) continue;

          String href = titleLink.attributes['href'] ?? "";
          String id = _extractId(href); // 使用下方提取函数
          if (id.isNotEmpty) {
            print(" (ID: $id)");
          } else {
            print("⚠ 发现链接但无法提取ID: $href");
          }
          if (id.isEmpty) continue;

          if (uniqueIds.contains(id)) continue;

          String title = titleLink.text.trim();
          String coverUrl = div.querySelector("img")?.attributes['src'] ?? "";

          // 提取简介
          String intro = "暂无简介";
          for (var p in div.querySelectorAll("p")) {
            if (p.text.contains("简介:")) {
              intro = p.text.replaceAll("简介:", "").trim();
              break;
            }
          }

          list.add(Novel(
            id: id,
            title: title,
            coverUrl: _fixUrl(coverUrl),
            url: _fixUrl(href),
            introduction: intro,
          ));
          uniqueIds.add(id);
        } catch (_) {}
      }
    }

    // --- 策略 B: 如果策略 A 没找到结果，启用暴力扫描 (保底) ---
    // 这种情况通常发生在书名匹配度低，网站返回纯文本列表时
    if (list.isEmpty) {
      final allLinks = document.querySelectorAll('a');
      for (var link in allLinks) {
        String href = link.attributes['href'] ?? "";
        String id = _extractId(href);

        // 必须是有效 ID，且未被添加过
        if (id.isEmpty || uniqueIds.contains(id)) continue;

        String title = link.text.trim();
        // 过滤掉功能性链接
        if (title.isEmpty || ["加入书架", "推荐本书", "我要阅读", "加入收藏"].contains(title)) continue;

        // 生成封面 (列表模式没有封面，只能靠猜)
        final subDir = int.parse(id) ~/ 1000;
        final coverUrl = "https://img.wenku8.com/image/$subDir/$id/${id}s.jpg";

        list.add(Novel(
          id: id,
          title: title,
          coverUrl: coverUrl,
          url: _fixUrl(href),
          introduction: "暂无简介", // 列表模式无法获取简介
        ));
        uniqueIds.add(id);
      }
    }

    return list;
  }

  // 🛠️ 辅助函数：安全提取纯数字 ID (解决点击无效的关键)
  static String _extractId(String url) {
    if (!url.contains("book/") || !url.contains(".htm")) return "";
    try {
      final start = url.indexOf("book/") + 5;
      final end = url.indexOf(".htm");
      if (start >= end) return "";

      String id = url.substring(start, end);
      // 必须确保是纯数字，防止解析出 "1234/index" 这种错误
      if (int.tryParse(id) != null) {
        return id;
      }
    } catch (_) {}
    return "";
  }

  // 🛠️ 辅助函数：补全 HTTPS
  static String _fixUrl(String url) {
    if (url.isEmpty) return "";
    if (url.startsWith("//")) return "https:$url";
    if (url.startsWith("http://")) return url.replaceFirst("http://", "https://");
    if (!url.startsWith("http")) return "https://www.wenku8.net$url";
    return url;
  }

}