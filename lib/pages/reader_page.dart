import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:page_flip/page_flip.dart';
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
  bool _isLoading = true;
  bool _isPaging = false;

  Key _pageFlipKey = UniqueKey();

  // 🔥 新增：记录当前页码
  int _currentIndex = 0;

  double? _lastFontSize;
  bool? _lastUseTwoColumns;

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

  void _paginate(BoxConstraints constraints, double fontSize, bool useTwoColumns) async {
    if (_fullContent.isEmpty || _isPaging) return;
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;

    _isPaging = true;

    double paddingHorizontal = 32.0;
    double paddingVertical = 60.0;
    double pageWidth = constraints.maxWidth - paddingHorizontal;
    double pageHeight = constraints.maxHeight - paddingVertical;

    if (pageWidth <= 0 || pageHeight <= 0) {
      _isPaging = false;
      return;
    }

    if (useTwoColumns) {
      pageWidth = (pageWidth - 32) / 2;
    }

    final textStyle = TextStyle(fontSize: fontSize, height: 1.5, color: Colors.black87);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    List<String> tempPages = [];
    int startOffset = 0;

    while (startOffset < _fullContent.length) {
      final remainingText = _fullContent.substring(startOffset);
      textPainter.text = TextSpan(text: remainingText, style: textStyle);
      textPainter.layout(maxWidth: pageWidth);

      final fitLength = textPainter.getPositionForOffset(Offset(pageWidth, pageHeight)).offset;

      if (fitLength == 0) {
        if (remainingText.isNotEmpty) tempPages.add(remainingText);
        break;
      }

      final globalEndOffset = startOffset + fitLength;
      tempPages.add(_fullContent.substring(startOffset, globalEndOffset));
      startOffset = globalEndOffset;
    }

    if (mounted) {
      setState(() {
        _pages = tempPages;
        _isPaging = false;
        _pageFlipKey = UniqueKey();
        // 🔥 新增：重置页码为0
        _currentIndex = 0;
      });
    }
  }

  Widget _buildPageContent(String content, double fontSize) {
    return Text(
      content,
      style: TextStyle(fontSize: fontSize, height: 1.5, color: Colors.black87),
      textAlign: TextAlign.justify,
    );
  }

  List<Widget> _buildAllPages(double fontSize, bool useTwoColumns, double screenWidth) {
    List<Widget> widgetPages = [];

    final pageDecoration = BoxDecoration(
      color: const Color(0xFFF5F5DC),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 5,
          spreadRadius: 1,
        )
      ],
    );

    if (useTwoColumns) {
      for (int i = 0; i < _pages.length; i += 2) {
        String leftContent = _pages[i];
        String rightContent = (i + 1 < _pages.length) ? _pages[i + 1] : "";

        widgetPages.add(Container(
          decoration: pageDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Row(
            children: [
              Expanded(child: _buildPageContent(leftContent, fontSize)),
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black12, Colors.transparent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )),
              ),
              Expanded(child: rightContent.isNotEmpty ? _buildPageContent(rightContent, fontSize) : Container()),
            ],
          ),
        ));
      }
    } else {
      double horizontalPadding = 20;
      if (screenWidth > 600) horizontalPadding = screenWidth * 0.15;

      for (var pageText in _pages) {
        widgetPages.add(Container(
          decoration: pageDecoration,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
          child: _buildPageContent(pageText, fontSize),
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
                    onChanged: (val) {
                      ReaderSettings.useTwoColumns = val;
                    },
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: ValueListenableBuilder<Box>(
          valueListenable: ReaderSettings.listenable(),
          builder: (context, box, child) {
            double fontSize = box.get('fontSize', defaultValue: 18.0);
            bool useTwoColumns = box.get('useTwoColumns', defaultValue: false);
            double screenWidth = MediaQuery.of(context).size.width;

            return LayoutBuilder(
              builder: (context, constraints) {
                bool configChanged = fontSize != _lastFontSize || useTwoColumns != _lastUseTwoColumns;

                if (!_isLoading && _fullContent.isNotEmpty && !_isPaging && (_pages.isEmpty || configChanged)) {
                  _lastFontSize = fontSize;
                  _lastUseTwoColumns = useTwoColumns;

                  Future.microtask(() {
                    if (mounted && configChanged) {
                      setState(() {
                        _pages = [];
                      });
                    }
                    _paginate(constraints, fontSize, useTwoColumns);
                  });
                }

                if (_isLoading || (_pages.isEmpty && _fullContent.isNotEmpty)) {
                  return const Center(child: CircularProgressIndicator());
                }

                final widgetPages = _buildAllPages(fontSize, useTwoColumns, screenWidth);

                // 🔥 获取总页数（屏幕数）
                int totalScreens = widgetPages.length;

                return Stack(
                  children: [
                    // 1. 翻页组件
                    PageFlipWidget(
                      key: _pageFlipKey,
                      backgroundColor: const Color(0xFFE0DCC5),
                      children: widgetPages,
                      // 🔥 新增：监听翻页
                      onPageFlip: (int pageIndex) {
                        setState(() {
                          _currentIndex = pageIndex;
                        });
                      },
                    ),

                    // 2. 顶部标题
                    Positioned(
                      top: 5,
                      left: 50,
                      child: Text(
                        widget.chapter.title,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),

                    // 3. 返回按钮
                    Positioned(
                      top: 0,
                      left: 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.brown),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // 4. 设置按钮
                    Positioned(
                      bottom: 30,
                      right: 20,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.brown.withOpacity(0.8),
                        child: const Icon(Icons.settings, color: Colors.white),
                        onPressed: _showSettingsModal,
                      ),
                    ),

                    // 🔥 5. 新增：页码显示
                    Positioned(
                      bottom: 10,
                      right: 25,
                      child: Text(
                        "${_currentIndex + 1}/$totalScreens",
                        style: TextStyle(
                          color: Colors.brown.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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