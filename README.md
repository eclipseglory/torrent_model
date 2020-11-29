A Dart library for parsing .torrent file to Torrent model/saving Torrent model to .torrent file.

## Usage

A simple usage example:

### Parse .torrent file

```dart
import 'package:torrent_model/torrent_model.dart';

main() {
  ....

  var model = Torrent.parse('some.torrent');

  ....
}
```

Use ```Torrent``` class' static method ```parse``` to get a torrent model. The important informations of .torrent file can be found in the torrent model , such as ```announces``` list , ```infoHash``` ,etc..

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/eclipseglory/torrent_model/issues
