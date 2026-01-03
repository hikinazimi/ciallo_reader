class Novel {
  final String id;
  final String title;
  String coverUrl;
  final String url;
  final String introduction;
  Novel({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.url,
    this.introduction = "",
  });
}

class HomeBlock {
  final String title; // 比如 "热门推荐"
  final List<Novel> novels; // 这个栏目下的小说列表

  HomeBlock({required this.title, required this.novels});
}