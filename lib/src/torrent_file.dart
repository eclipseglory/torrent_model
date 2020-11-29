///
/// Torrent file description
///
class TorrentFile {
  /// file name
  final String name;

  /// file path
  final String path;

  /// file length
  final int length;

  /// file offset
  final int offset;
  TorrentFile(this.name, this.path, this.length, this.offset);

  @override
  String toString() {
    return 'File{name : $name ,path : $path, length : $length, offset : $offset}';
  }
}
