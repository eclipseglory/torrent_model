import 'package:test/test.dart';
import 'package:torrent_model/torrent_model.dart';

const PATH = './test/';

void main() {
  /// Magnet URI id：588E1129AE56386B02C67DA8FA3F0E04025D031D
  test('Test parse torrent file from a file', () async {
    // If the file is changed, please remember to modify the verification information below accordingly.
    var result = await Torrent.parse('${PATH}sample.torrent');
    assert(result.infoHash == '588e1129ae56386b02c67da8fa3f0e04025d031d');
    assert(result.announces.length == 132);
    assert(result.files.length == 1);
    assert(result.length == 2352463340);
  });

  test('Test save torrent file and validate the model is the same', () async {
    var model = await Torrent.parse('${PATH}sample.torrent');
    var newFile = await model.saveAs('${PATH}sample2.torrent', true);
    var newModel = await Torrent.parse(newFile.path);

    assert(model.name == newModel.name);
    assert(model.infoHash == newModel.infoHash);
    assert(model.length == newModel.length);
    assert(model.pieceLength == newModel.pieceLength);
    assert(model.filePath != newModel.filePath);

    assert(model.announces.length == newModel.announces.length);

    for (var index = 0; index < model.announces.length; index++) {
      var a1 = model.announces.elementAt(index);
      var a2 = newModel.announces.elementAt(index);
      assert(a1 == a2);
    }
  });
}
