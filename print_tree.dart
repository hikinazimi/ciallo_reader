import 'dart:io';

void main() {
  // 🔥 这里定义你想忽略的文件夹
  const Set<String> ignoredFolders = {
    'build',
    '.dart_tool',
    '.idea',
    '.git',
    'android',
    'ios',
    'linux',
    'macos',
    'web',
    'windows',
    'test',
  };

  // 🔥 这里定义你想忽略的文件后缀或文件名
  const Set<String> ignoredFiles = {
    '.DS_Store',
    'print_tree.dart', // 忽略脚本自己
    'pubspec.lock',
    '.gitignore',
    '.metadata',
    'analysis_options.yaml',
    'iallo_reader.iml', // 你的项目iml文件
  };

  final root = Directory.current;
  print(root.path.split(Platform.pathSeparator).last + "/");
  _printDirectory(root, "", ignoredFolders, ignoredFiles);
}

void _printDirectory(Directory dir, String prefix, Set<String> ignoredFolders, Set<String> ignoredFiles) {
  List<FileSystemEntity> entities;
  try {
    entities = dir.listSync()
      ..sort((a, b) {
        // 让文件夹排在文件前面
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return a.path.compareTo(b.path);
      });
  } catch (e) {
    return;
  }

  for (var i = 0; i < entities.length; i++) {
    final entity = entities[i];
    final name = entity.path.split(Platform.pathSeparator).last;
    final isLast = i == entities.length - 1;

    // 过滤逻辑
    if (name.startsWith('.')) continue; // 忽略隐藏文件
    if (ignoredFiles.contains(name)) continue;
    if (entity is Directory && ignoredFolders.contains(name)) continue;

    print('$prefix${isLast ? '└── ' : '├── '}$name');

    if (entity is Directory) {
      _printDirectory(entity, '$prefix${isLast ? '    ' : '│   '}', ignoredFolders, ignoredFiles);
    }
  }
}