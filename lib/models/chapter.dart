class Chapter {
  final String cid;
  final String title;
  final String url; // 真实数据需要 URL 来获取正文
  final String content; // 目录页获取不到正文，初始为空

  Chapter({
    required this.cid,
    required this.title,
    required this.url,
    this.content = '',
  });
}