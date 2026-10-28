import 'dart:io';

/// Escritorio: guarda el archivo en la carpeta Descargas del usuario.
Future<String?> saveTextFile(String fileName, String content) async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null) return null;
  final downloads = Directory('$home${Platform.pathSeparator}Downloads');
  final dir = await downloads.exists() ? downloads : Directory(home);
  final file = File('${dir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content);
  return file.path;
}
