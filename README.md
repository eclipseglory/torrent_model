A Dart library for parsing .torrent file to Torrent model/saving Torrent model to .torrent file.

## Support 
- [BEP 0005 DHT Protocol](https://www.bittorrent.org/beps/bep_0005.html)
- [BEP 0012 Multitracker Metadata Extension](https://www.bittorrent.org/beps/bep_0012.html)
- [BEP 0019 WebSeed - HTTP/FTP Seeding (GetRight style)](https://www.bittorrent.org/beps/bep_0019.html)

## Usage

A simple usage example:

### Parse .torrent file

```dart
import 'package:dtorrent_parser/dtorrent_parser.dart';

main() {
  ....

  var model = Torrent.parse('some.torrent');

  ....
}
```

Use ```Torrent``` class' static method ```parse``` to get a torrent model. The important informations of .torrent file can be found in the torrent model , such as ```announces``` list , ```infoHash``` ,etc..

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/moham96/dtorrent_parser/issues
