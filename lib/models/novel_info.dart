class NovelInfo {
  final String id;
  final String title;
  final String author;
  final String status; // 连载中/已完结
  final String lastUpdate;
  final String coverUrl;
  final String introduction; // 简介
  final List<String> tags; // 标签 (如: 后宫, 奇幻)

  NovelInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.status,
    required this.lastUpdate,
    required this.coverUrl,
    required this.introduction,
    required this.tags,
  });

  // 空对象，用于初始化
  factory NovelInfo.empty() {
    return NovelInfo(
      id: "",
      title: "",
      author: "",
      status: "",
      lastUpdate: "",
      coverUrl: "",
      introduction: "",
      tags: [],
    );
  }
}