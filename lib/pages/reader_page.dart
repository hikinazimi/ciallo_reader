import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 引入你的本地 PageFlip 库
import '../widgets/page_flip/page_flip.dart';

import '../models/chapter.dart';
import '../api/wenku_api.dart';
import '../utils/bookshelf_manager.dart';
import '../utils/reader_settings.dart';

class ReaderPage extends StatefulWidget {
  final Chapter chapter;
  final String baseUrl;
  final String bookId;

  const ReaderPage({
    super.key,
    required this.chapter,
    required this.baseUrl,
    required this.bookId,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  String _fullContent = "";
  List<String> _pages = [];
  bool _isLoading = true; // 加载网络内容中
  bool _isPaging = false; // 计算排版中

  Key _pageFlipKey = UniqueKey();
  int _currentIndex = 0;

  // 缓存上次的配置，避免重复计算
  double? _lastFontSize;
  bool? _lastUseTwoColumns;
  Size? _lastSize;

  // 布局常量
  final double _displayPaddingVertical = 40.0;
  final double _displayPaddingHorizontal = 20.0;
  final double _titleHeightReserved = 20.0;
  final double _pageNumberHeightReserved = 30.0;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      String fullUrl = widget.baseUrl + widget.chapter.url;
      final text = await WenkuApi().fetchContent(fullUrl);

      if (mounted) {
        setState(() {
          _fullContent = text;
          _isLoading = false;
        });

        if (BookshelfManager.isInBookshelf(widget.bookId)) {
          BookshelfManager.updateProgress(
            widget.bookId,
            widget.chapter.title,
            widget.chapter.cid,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 统一的样式配置（显示和计算必须完全一致）
  TextStyle _getTextStyle(double fontSize) {
    return TextStyle(
      fontSize: fontSize,
      height: 1.6, // 统一行高
      color: Colors.black87,
      fontFamily: 'Roboto',
      locale: const Locale('zh', 'CN'),
    );
  }

  // 🔥 强制行高支架（防止半截字的核心）
  StrutStyle _getStrutStyle(double fontSize) {
    return StrutStyle(
      fontSize: fontSize,
      height: 1.6,
      forceStrutHeight: true,
    );
  }

  // 🔥 单线程排版方法
  // 这里的 async 只是为了让 UI 有机会刷新 Loading 状态
  Future<void> _paginate(BoxConstraints constraints, double fontSize, bool useTwoColumns) async {
    if (_fullContent.isEmpty) return;

    // 简单的参数检查
    if (constraints.maxWidth < 50 || constraints.maxHeight < 50) return;

    // 显示“正在排版”
    setState(() => _isPaging = true);

    // 让 UI 线程喘口气，把 Loading 显示出来后再开始计算
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // 1. 计算可用空间
      double topReserved = _displayPaddingVertical + _titleHeightReserved;
      double bottomReserved = _displayPaddingVertical + _pageNumberHeightReserved;
      if (useTwoColumns) bottomReserved += 20.0; // 双页模式底部多留点空

      double rawHeight = constraints.maxHeight - topReserved - bottomReserved;
      double pageWidth = constraints.maxWidth - (_displayPaddingHorizontal * 2);

      if (useTwoColumns) {
        pageWidth = (pageWidth - 32) / 2;
      }

      // 2. 准备画笔
      final textStyle = _getTextStyle(fontSize);
      final strutStyle = _getStrutStyle(fontSize);
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        locale: const Locale('zh', 'CN'),
        strutStyle: strutStyle, // 计算时带上支架
      );

      // 3. 计算“一行字”的高度
      textPainter.text = TextSpan(text: "测试", style: textStyle);
      textPainter.layout(maxWidth: pageWidth);
      double singleLineHeight = textPainter.height;
      if (singleLineHeight <= 0) singleLineHeight = fontSize * 1.6;

      // 4. 计算一页能放多少行 (向下取整)
      int maxLines = (rawHeight / singleLineHeight).floor();
      // 安全减行：双页模式减2行，单页减1行
      maxLines -= (useTwoColumns ? 2 : 1);
      if (maxLines < 1) maxLines = 1;

      // 5. 算出“完美页高”
      double exactPageHeight = maxLines * singleLineHeight;

      // 6. 循环截取内容
      List<String> tempPages = [];
      int startOffset = 0;
      int contentLength = _fullContent.length;

      while (startOffset < contentLength) {
        // 每次取一部分内容来测量（性能优化）
        int endEstimate = startOffset + 1000;
        if (endEstimate > contentLength) endEstimate = contentLength;

        String chunk = _fullContent.substring(startOffset, endEstimate);

        textPainter.text = TextSpan(text: chunk, style: textStyle);
        textPainter.strutStyle = strutStyle;
        textPainter.layout(maxWidth: pageWidth);

        // 找截断点
        final endPos = textPainter.getPositionForOffset(Offset(pageWidth, exactPageHeight));
        int fitLength = endPos.offset;

        // 死循环保护：如果算出来是0，强行+1
        if (fitLength <= 0) fitLength = 1;

        // 边界修正
        if (startOffset + fitLength > contentLength) {
          fitLength = contentLength - startOffset;
        }

        tempPages.add(_fullContent.substring(startOffset, startOffset + fitLength));
        startOffset += fitLength;
      }

      if (mounted) {
        setState(() {
          _pages = tempPages;
          _isPaging = false; // 排版结束
          _pageFlipKey = UniqueKey();

          // 修正页码越界
          if (_currentIndex >= _pages.length) {
            _currentIndex = _pages.isNotEmpty ? _pages.length - 1 : 0;
          }
        });
      }
    } catch (e) {
      print("排版出错: $e");
      if (mounted) {
        setState(() {
          _isPaging = false;
          _pages = [_fullContent]; // 出错就显示全文，至少能看
        });
      }
    }
  }

  Widget _buildPageContent(String content, double fontSize) {
    return Text(
      content,
      style: _getTextStyle(fontSize),
      strutStyle: _getStrutStyle(fontSize), // 显示时也要带支架
      textAlign: TextAlign.justify,
    );
  }

  List<Widget> _buildAllPages(double fontSize, bool useTwoColumns) {
    List<Widget> widgetPages = [];
    final pageDecoration = BoxDecoration(
      color: const Color(0xFFF5F5DC),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
    );

    final contentPadding = EdgeInsets.only(
      left: _displayPaddingHorizontal,
      right: _displayPaddingHorizontal,
      top: _displayPaddingVertical + _titleHeightReserved,
      bottom: _displayPaddingVertical + _pageNumberHeightReserved,
    );

    if (useTwoColumns) {
      for (int i = 0; i < _pages.length; i += 2) {
        String left = _pages[i];
        String right = (i + 1 < _pages.length) ? _pages[i + 1] : "";
        widgetPages.add(Container(
          decoration: pageDecoration,
          padding: contentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPageContent(left, fontSize)),
              Container(width: 1, color: Colors.black12, margin: const EdgeInsets.symmetric(horizontal: 16)),
              Expanded(child: right.isNotEmpty ? _buildPageContent(right, fontSize) : Container()),
            ],
          ),
        ));
      }
    } else {
      for (var txt in _pages) {
        widgetPages.add(Container(
          decoration: pageDecoration,
          padding: contentPadding,
          alignment: Alignment.topLeft,
          child: _buildPageContent(txt, fontSize),
        ));
      }
    }

    if (widgetPages.isEmpty) return [Container(decoration: pageDecoration)];
    return widgetPages;
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return ValueListenableBuilder<Box>(
          valueListenable: ReaderSettings.listenable(),
          builder: (context, box, child) {
            double fontSize = box.get('fontSize', defaultValue: 18.0);
            bool useTwoColumns = box.get('useTwoColumns', defaultValue: false);

            return Container(
              height: 250,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("阅读设置", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.format_size, color: Colors.grey),
                      const SizedBox(width: 10),
                      const Text("字号"),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 14,
                          max: 30,
                          divisions: 16,
                          label: fontSize.toString(),
                          onChanged: (val) => ReaderSettings.fontSize = val,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text("双页模式"),
                    subtitle: const Text("模拟书本左右分页显示"),
                    secondary: const Icon(Icons.menu_book, color: Colors.grey),
                    value: useTwoColumns,
                    onChanged: (val) => ReaderSettings.useTwoColumns = val,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0DCC5),
      body: SafeArea(
        child: ValueListenableBuilder<Box>(
          valueListenable: ReaderSettings.listenable(),
          builder: (context, box, child) {
            double fontSize = box.get('fontSize', defaultValue: 18.0);
            bool useTwoColumns = box.get('useTwoColumns', defaultValue: false);

            return LayoutBuilder(
              builder: (context, constraints) {
                // 检查是否需要重新排版
                // 条件：内容已加载 + (配置变了 OR 屏幕大小变了 OR 还没排过版)
                bool needRepaginate = false;
                if (!_isLoading && _fullContent.isNotEmpty && !_isPaging) {
                  if (_pages.isEmpty ||
                      fontSize != _lastFontSize ||
                      useTwoColumns != _lastUseTwoColumns ||
                      constraints.biggest != _lastSize) {
                    needRepaginate = true;
                  }
                }

                if (needRepaginate) {
                  // 更新缓存
                  _lastFontSize = fontSize;
                  _lastUseTwoColumns = useTwoColumns;
                  _lastSize = constraints.biggest;

                  // 触发排版 (使用 microtask 避免 setState 冲突)
                  Future.microtask(() => _paginate(constraints, fontSize, useTwoColumns));
                }

                // 如果正在加载或正在排版
                if (_isLoading || _isPaging || _pages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("正在处理...", style: TextStyle(color: Colors.brown)),
                      ],
                    ),
                  );
                }

                final widgetPages = _buildAllPages(fontSize, useTwoColumns);
                int totalScreens = widgetPages.length;

                return Stack(
                  children: [
                    PageFlipWidget(
                      key: _pageFlipKey,
                      backgroundColor: const Color(0xFFE0DCC5),
                      children: widgetPages,
                      initialIndex: _currentIndex,
                      onPageFlip: (int pageIndex) {
                        // 简单的微任务回调
                        Future.microtask(() {
                          if (mounted) setState(() => _currentIndex = pageIndex);
                        });
                      },
                    ),

                    Positioned(
                        top: 5, left: 50,
                        child: Text(widget.chapter.title, style: const TextStyle(color: Colors.grey, fontSize: 12))
                    ),
                    Positioned(
                      top: 0, left: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.brown),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      bottom: 30, right: 20,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.brown.withOpacity(0.8),
                        child: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _showSettingsModal,
                      ),
                    ),
                    Positioned(
                      bottom: 10, right: 25,
                      child: Text("${_currentIndex + 1}/$totalScreens",
                          style: TextStyle(color: Colors.brown.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}