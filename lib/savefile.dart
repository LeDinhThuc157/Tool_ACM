import 'dart:io';


void replaceArrayInFile(String filePath, String arrayName, List<int> newArray) {
  final file = File(filePath);

  // Đọc nội dung của tệp tin
  List<String> lines = file.readAsLinesSync();

  // Tìm và thay thế mảng nếu nó tồn tại
  bool arrayFound = false;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains(arrayName)) {
      lines[i] = '$arrayName: $newArray';
      arrayFound = true;
      break;
    }
  }

  // Ghi nội dung mới vào tệp tin
  if (!arrayFound) {
    lines.add('$arrayName: $newArray');
  }

  file.writeAsStringSync(lines.join('\n'));
}
