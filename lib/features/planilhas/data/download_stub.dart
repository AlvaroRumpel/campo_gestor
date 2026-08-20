// Stub para plataformas não-web. ponytail: adicionar path_provider + share
// quando mobile pedir export.
import 'dart:typed_data';

void downloadBytes(String fileName, Uint8List bytes) {
  throw UnsupportedError('Download de arquivo só está disponível na web.');
}
