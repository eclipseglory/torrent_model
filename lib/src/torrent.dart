import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:bencode_dart/bencode_dart.dart' as bencoding;
import 'package:crypto/crypto.dart';

import 'torrent_file.dart';

const PATH_SEPRATOR = '\\\\';

///
/// Torrent File Structure Model.
///
/// See [Torrent file structure](https://wiki.theory.org/BitTorrentSpecification#Metainfo_File_Structure)
class Torrent {
  /// decode .torrent file info object
  ///
  /// 这是为了能够重新生成torrent文件而准备的，因为解析出来的info会在生成模型的时候有所忽略
  /// ，如果直接用模型再此生成torrent文件，那么原本的info信息会不一致，再次解析就会无法获取
  /// 正确的sha1信息。
  ///
  dynamic get info => _info;

  /// If this model was parsed from file system, record the file path
  String filePath;

  final dynamic _info;

  final Set<Uri> _announces = {};

  /// The announce URL list of the trackers
  Set<Uri> get announces => _announces;

  /// creation date
  DateTime creationDate;

  /// free-form textual comments of the author
  String comment;

  /// name and version of the program used to create the torrent file
  String createdBy;

  /// the string encoding format used to generate the pieces part of the info dictionary in the torrent file metafile
  String encoding;

  /// Total file bytes size;
  int length;

  /// Torrent model name.
  final String name;

  final Set<Uri> _urlList = {};

  Set<Uri> get urlList => _urlList;

  final List<TorrentFile> _files = [];

  /// The files list
  List<TorrentFile> get files => _files;

  final String infoHash;

  Uint8List infoHashBuffer;

  int pieceLength;

  int lastPriceLength;

  bool private;

  final List<String> _pieces = [];

  List<String> get pieces => _pieces;

  Torrent(this._info, this.name, this.infoHash, this.infoHashBuffer,
      {this.createdBy, this.creationDate, this.filePath});

  void addPiece(String piece) {
    pieces.add(piece);
  }

  void removePiece(String piece) {
    pieces.remove(piece);
  }

  bool addAnnounce(Uri announce) {
    return _announces.add(announce);
  }

  bool removeAnnounce(Uri announce) {
    return _announces.remove(announce);
  }

  bool addURL(Uri url) {
    return _urlList.add(url);
  }

  bool removeURL(Uri url) {
    return _urlList.remove(url);
  }

  void addFile(TorrentFile file) {
    _files.add(file);
  }

  void removeFile(TorrentFile file) {
    _files.remove(file);
  }

  @override
  String toString() {
    return 'Torrent Model{name:$name,InfoHash:$infoHash}';
  }

  ///
  /// Parse torrent file。
  ///
  /// The parameter can be file path(```String```) or file content bytes (```Uint8List```).
  ///
  static Future<Torrent> parse(dynamic data) async {
    var t = await _compution<Torrent>(_process, data);
    if (data is String) t.filePath = data;
    return t;
  }

  /// Generate .torrent bencode bytes buffer from Torrent model
  Future<Uint8List> toByteBuffer() {
    return _compution<Uint8List>(_processModel2Buffer, this);
  }

  /// Save Torrent model to .torrent file
  ///
  /// If param [force] is true, the exist .torrent file will be re-write with
  /// the new content
  Future<File> saveAs(String path, [bool force = false]) async {
    if (path == null) throw Exception('File path is Null');
    var file = File(path);
    var exsits = await file.exists();
    if (exsits) {
      if (!force) throw Exception('file is exists');
    } else {
      file = await file.create(recursive: true);
    }
    var content = await toByteBuffer();
    return file.writeAsBytes(content);
  }

  /// Save current model to the current file
  Future<File> save() {
    return saveAs(filePath, true);
  }
}

/// IO操作太耗时间，用隔离来做
Future<T> _compution<T>(Function mainMethod, dynamic data) {
  var complete = Completer<T>();
  var port = ReceivePort();
  var errorPort = ReceivePort();

  Function cleanAll = (isolate) {
    port.close();
    errorPort.close();
    isolate.kill();
  };

  Isolate.spawn(mainMethod, {'sender': port.sendPort, 'data': data},
          onError: errorPort.sendPort)
      .then((isolate) {
    port.listen((message) {
      cleanAll(isolate);
      complete.complete(message);
    });

    errorPort.listen((error) {
      cleanAll(isolate);
      complete.completeError(error);
    });
  });
  return complete.future;
}

/// This method is for Isolate main method to create bytebuffer from Torrent model
void _processModel2Buffer(dynamic data) {
  if (data is Map) {
    var sender = data['sender'] as SendPort;
    var model = data['data'];
    if (model is! Torrent) {
      throw Exception('The input data isn\'t Torrent model');
    }
    var result = _torrentModel2Bytebuffer(model);
    sender.send(result);
  } else {
    throw Exception('The Isolate init input data is incorrect');
  }
}

void _process(dynamic data) async {
  if (data is Map) {
    var sender = data['sender'] as SendPort;
    var path = data['data'];
    var bytes;
    if (path is String) bytes = await File(path).readAsBytes();
    if (path is List) bytes = path;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('file path/contents is empty');
    }
    var result = parseTorrentFileContent(bytes);
    sender.send(result);
  } else {
    throw Exception('The parse file Isolate init input data is incorrect');
  }
}

void _checkFile(Map torrent) {
  assert(torrent['info'] != null, _ensureMessage('info'));
  assert(
      torrent['info']['name.utf-8'] != null || torrent['info']['name'] != null,
      _ensureMessage('info.name'));
  assert(torrent['info']['piece length'] != null,
      _ensureMessage('info[\'piece length\']'));
  assert(torrent['info']['pieces'] != null, _ensureMessage('info.pieces'));

  if (torrent['info']['files'] != null) {
    torrent['info']['files'].forEach((file) {
      // assert(typeof file.length === 'number', 'info.files[0].length')
      assert(file['path.utf-8'] != null || file['path'] != null,
          _ensureMessage('info.files[0].path'));
    });
  } else {
    assert(torrent['info']['length'] is num, 'info.length');
  }
}

/// Parse file bytes content ,return torrent file model
Torrent parseTorrentFileContent(Uint8List fileBytes) {
  var torrent = bencoding.decode(fileBytes);
  if (torrent == null) return null;
  // TODO parse nodes property
  // var nodes = torrent['nodes'];
  // if(nodes!=null){
  //   for(var node in nodes){
  //     var u = node[0];
  //     print(String.fromCharCodes(u));
  //   }
  // }
  // check the file is correct
  _checkFile(torrent);

  var torrentName =
      _decodeString((torrent['info']['name.utf-8'] ?? torrent['info']['name']));

  var sha1Info = sha1.convert(bencoding.encode(torrent['info']));
  var torrentModel = Torrent(
      torrent['info'], torrentName, sha1Info.toString(), sha1Info.bytes);

  if (torrent['encoding'] != null) {
    torrentModel.encoding = String.fromCharCodes(torrent['encoding']);
  }

  if (torrent['info']['private'] != null) {
    torrentModel.private = (torrent['info']['private'] == 1);
  }

  if (torrent['creation date'] != null) {
    torrentModel.creationDate =
        DateTime.fromMillisecondsSinceEpoch(torrent['creation date'] * 1000);
  }
  if (torrent['created by'] != null) {
    torrentModel.createdBy = _decodeString(torrent['created by']);
  }
  if (torrent['comment'] is Uint8List) {
    torrentModel.comment = _decodeString(torrent['comment']);
  }

  if ((torrent['announce-list'] is List) &&
      torrent['announce-list'].length > 0) {
    torrent['announce-list'].forEach((urls) {
      urls.forEach((url) {
        torrentModel.addAnnounce(Uri.parse(utf8.decode(url)));
      });
    });
  } else if (torrent['announce'] != null) {
    torrentModel.addAnnounce(Uri.parse(utf8.decode(torrent['announce'])));
  }

  // handle url-list (BEP19 / web seeding)
  if (torrent['url-list'] is Uint8List) {
    // some clients set url-list to empty string
    torrent['url-list'] =
        torrent['url-list'].length > 0 ? [torrent['url-list']] : [];
  }
  var tempUrlList = torrent['url-list'] ?? [];
  tempUrlList
      .forEach((url) => torrentModel.addURL(Uri.parse(_decodeString(url))));

  var files = torrent['info']['files'] ?? [torrent['info']];
  var tempfiles = [];
  for (var i = 0; i < files.length; i++) {
    var file = files[i];
    var filePath = (file['path.utf-8'] ?? file['path']) ?? [];
    var pars = []
      ..add(torrentModel.name)
      ..addAll(filePath);
    var parts = pars.map((e) {
      if (e is List) {
        return _decodeString(e);
      }
      if (e is String) return e;
    }).toList();
    var p = parts.fold<String>('',
        (previousValue, element) => previousValue + PATH_SEPRATOR + element);
    p = p.substring(2);
    tempfiles.add({
      'path': p,
      'name': parts[parts.length - 1],
      'length': file['length'],
      'offset': files.sublist(0, i).fold(0, _sumLength)
    });
    torrentModel.addFile(TorrentFile(parts[parts.length - 1], p, file['length'],
        files.sublist(0, i).fold(0, _sumLength)));
  }
  torrentModel.length = files.fold(0, _sumLength);

  var lastTorrentFile = torrentModel.files.last;
  torrentModel.pieceLength = torrent['info']['piece length'];
  torrentModel.lastPriceLength =
      (lastTorrentFile.offset + lastTorrentFile.length) %
          torrentModel.pieceLength;
  if (torrentModel.lastPriceLength == 0) {
    torrentModel.lastPriceLength = torrentModel.pieceLength;
  }
  var pices = _splitPieces(torrent['info']['pieces']);
  pices.forEach((piece) => torrentModel.addPiece(piece));

  return torrentModel;
}

/// 用torrent模型生成map，然后encode出byte buffer
Uint8List _torrentModel2Bytebuffer(Torrent torrentModel) {
  var torrent = {'info': torrentModel.info};
  var announce = torrentModel.announces;
  if (announce != null && announce.isNotEmpty) {
    if (announce.length == 1) {
      torrent['announce'] =
          utf8.encode(torrentModel.announces.elementAt(0).toString());
    } else {
      torrent['announce-list'] = [];
      for (var url in announce) {
        torrent['announce-list'].add([utf8.encode(url.toString())]);
      }
    }
  }

  if (torrentModel.urlList != null && torrentModel.urlList.isNotEmpty) {
    torrent['url-list'] = [];
    torrentModel.urlList.forEach((url) {
      torrent['url-list'].add(url.toString());
    });
  }
  if (torrentModel.private != null) {
    torrent['private'] = torrentModel.private ? 1 : 0;
  }

  if (torrentModel.creationDate != null) {
    torrent['creation date'] =
        torrentModel.creationDate.millisecondsSinceEpoch ~/ 1000;
  }

  if (torrentModel.creationDate != null) {
    torrent['created by'] = torrentModel.createdBy;
  }

  if (torrentModel.comment != null) torrent['comment'] = torrentModel.comment;

  return bencoding.encode(torrent);
}

// /**
//  * Check if `obj` is a W3C `Blob` or `File` object
//  * @param  {*} obj
//  * @return {boolean}
//  */
// function isBlob (obj) {
//   return typeof Blob !== 'undefined' && obj instanceof Blob
// }

int _sumLength(sum, file) {
  return sum + file['length'];
}

List _splitPieces(List buf) {
  var pieces = [];
  for (var i = 0; i < buf.length; i += 20) {
    var array = buf.sublist(i, i + 20);
    var str = array.fold<String>('', (previousValue, byte) {
      var hex = byte.toRadixString(16);
      if (hex.length != 2) hex = '0' + hex;
      return previousValue + hex;
    });
    pieces.add(str);
  }
  return pieces;
}

String _ensureMessage(fieldName) {
  return 'Torrent is missing required field: ${fieldName}';
}

String _decodeString(Uint8List list) {
  try {
    return utf8.decode(list);
  } catch (e) {
    return String.fromCharCodes(list);
  }
}
