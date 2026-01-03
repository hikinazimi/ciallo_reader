// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookshelf_novel.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookshelfNovelAdapter extends TypeAdapter<BookshelfNovel> {
  @override
  final int typeId = 0;

  @override
  BookshelfNovel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BookshelfNovel(
      id: fields[0] as String,
      title: fields[1] as String,
      coverUrl: fields[2] as String,
      author: fields[3] as String,
      lastReadChapter: fields[4] as String,
      lastReadChapterId: fields[5] as String,
      lastUpdate: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BookshelfNovel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.coverUrl)
      ..writeByte(3)
      ..write(obj.author)
      ..writeByte(4)
      ..write(obj.lastReadChapter)
      ..writeByte(5)
      ..write(obj.lastReadChapterId)
      ..writeByte(6)
      ..write(obj.lastUpdate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookshelfNovelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
