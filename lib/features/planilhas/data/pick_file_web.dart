// Seletor de planilha no navegador via <input type="file"> — substitui o
// file_picker, cujo web plugin (3.0.1) quebra com UnsupportedError ao anexar
// o input (`children.add` numa lista imutável do package:web). Web-only —
// o stub em pick_file_stub.dart cobre outras plataformas (app é web-first).
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'pick_file.dart' show PickedSheetFile;

Future<PickedSheetFile?> pickSheetFile() {
  final completer = Completer<PickedSheetFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.xlsx,.csv';

  void complete(PickedSheetFile? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  void onChange(web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    void onLoad(web.Event _) {
      final buffer = (reader.result as JSArrayBuffer).toDart;
      complete(PickedSheetFile(file.name, buffer.asUint8List()));
    }

    void onError(web.Event _) => complete(null);
    reader.addEventListener('load', onLoad.toJS);
    reader.addEventListener('error', onError.toJS);
    reader.readAsArrayBuffer(file);
  }

  // Navegadores modernos disparam 'cancel' quando o usuário fecha o diálogo
  // sem escolher; se não disparar, o Future só fica pendente (sem vazamento
  // visível — nenhum estado da UI espera por ele além do await).
  void onCancel(web.Event _) => complete(null);
  input.addEventListener('change', onChange.toJS);
  input.addEventListener('cancel', onCancel.toJS);
  input.click();
  return completer.future;
}
