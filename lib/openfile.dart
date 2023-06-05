import 'dart:io';

Map<String, List<int>> readArraysFromFile(String filePath,) {
  File file = File(filePath);

  if (!file.existsSync()) {
    print('File not found.');
    return {};
  }

  String content = file.readAsStringSync();

  List<String> lines = content.split('\n');
  Map<String, List<int>> arrays = {};

  for (String line in lines) {
    if (line.isNotEmpty) {
      List<String> parts = line.split(':');
      if (parts.length == 2) {
        String arrayName = parts[0].trim();
        String arrayValues = parts[1].trim().replaceAll('[', '').replaceAll(']', '');
        List<int> array = arrayValues.split(',').map(int.parse).toList();
        arrays[arrayName] = array;
      }
    }
  }

  // In kết quả
  arrays.forEach((key, value) {
    print('$key: $value');
  });
  return arrays;
}