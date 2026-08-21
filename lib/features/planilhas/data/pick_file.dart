import 'dart:typed_data';

export 'pick_file_stub.dart'
    if (dart.library.js_interop) 'pick_file_web.dart';

/// Arquivo escolhido pelo usuário (nome + bytes).
class PickedSheetFile {
  const PickedSheetFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
