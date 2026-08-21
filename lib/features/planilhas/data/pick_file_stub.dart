// Stub não-web do seletor de planilha (app é web-first; o import só é
// alcançável nos headers desktop/web).
import 'pick_file.dart' show PickedSheetFile;

Future<PickedSheetFile?> pickSheetFile() async =>
    throw UnsupportedError('Importar planilha só está disponível na web.');
