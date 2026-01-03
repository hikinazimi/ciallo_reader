import 'chapter.dart';

class Volume {
   String title;
   List<Chapter> chapters;

  Volume({required this.title, required this.chapters});

   factory Volume.empty() {
     return Volume(title: "", chapters: []);
   }
}