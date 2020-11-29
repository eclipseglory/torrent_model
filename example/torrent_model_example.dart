import 'package:torrent_model/torrent_model.dart';

void main() async {
  readAndSave('./example/sample.torrent', './example/sample2.torrent');
  readAndSave('./example/sample3.torrent', './example/sample4.torrent');
}

void readAndSave(String path, String newPath) async {
  var result = await Torrent.parse(path);
  printModelInfo(result);
  var newFile = await result.saveAs(newPath, true);
  var result2 = await Torrent.parse(newFile.path);
  printModelInfo(result2);
}

void printModelInfo(Torrent model) {
  print('${model.filePath} Info Hash : ${model.infoHash}');
  print('${model.filePath} announces :');
  for (var announce in model.announces) {
    print('${announce}');
  }

  print('${model.filePath} files :');
  for (var file in model.files) {
    print('${file}');
  }
}
