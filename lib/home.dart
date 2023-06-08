import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
// import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:future_progress_dialog/future_progress_dialog.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

import 'openfile.dart';
import 'savefile.dart';

class Home extends StatefulWidget {
  const Home({Key ? key,});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home>{
  Map<String, List<int>> arrays = {};
  // var com = TextEditingController();
  String? selectedComLabel;
  String? selectedBaud = '9600';
  final List<String> comPorts = SerialPort.getAvailablePorts();
  final List<String> Baud = List.castFrom(['9600', '19200', '38400', '115200']);
  List<int> data_save = [];
  var intValue;
  String filePathOpen = '';
  String filePathSave = '';
  int page  = 0;
  _Load_Document() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String path = file.path;
      String convertedPath = path.replaceAll(r'\', '/');
      print("Converted: $convertedPath");
      filePathOpen = convertedPath;
      arrays = readArraysFromFile(convertedPath);
      print("Datamap: $arrays");
    } else {
      // User canceled the picker
    }
  }

  _Load_Document_Save() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String path = file.path;
      String convertedPath = path.replaceAll(r'\', '/');
      print("Converted: $convertedPath");
      filePathSave = convertedPath;
    } else {
      // User canceled the picker
    }
  }


  String read_or_write = '';
  // late Uint8List request;
  var check_read2 = 0;
  var BanTin11 = [];
  var intList_write;

  void _sendModbusRequest(Uint8List request, String mang) async {

    final port = SerialPort(
        "${selectedComLabel}",
        BaudRate: int.parse(selectedBaud!),
        openNow: false,
        ByteSize: 8,
        ReadIntervalTimeout: 1,
        ReadTotalTimeoutConstant: 2
    );
    try {
      data_save = [];
      if (port.isOpened) {
        await port.writeBytesFromUint8List(request);

        List<String> hexList = [];
        intValue = 0;
        // Thiết lập thời gian chờ là 5 giây
        const timeoutDuration = Duration(seconds: 5);
        // Tạo một Completer để theo dõi khi nào nhận được dữ liệu
        Completer<List<int>> completer = Completer<List<int>>();
        // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
        Timer timeoutTimer = Timer(timeoutDuration, () {
          // Hủy bỏ Completer nếu thời gian chờ kết thúc
          if (!completer.isCompleted) {
            completer.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
          }
        });
        port.readBytesOnListen(8, (value) async {
          // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
          if (!timeoutTimer.isActive) {
            return; // Không làm gì nếu đã hết thời gian chờ
          }
          // Hoàn thành Completer nếu nhận được dữ liệu
          if (!completer.isCompleted) {
            completer.complete(value); // Gửi dữ liệu tới Completer
          }
        });
        // Đợi hoặc xử lý kết quả từ Completer
        completer.future.then((data) {
          // Xử lý dữ liệu thành công
          print('Received data: $data');
          hexList = [];
          for (var byte in data) {
            String hex = byte.toRadixString(16).padLeft(2, '0');
            hexList.add(hex);
          }
          print(hexList);
          int S = 0;
          for (int hex = 0; hex < hexList.length - 2; hex++) {
            int hexValue = int.parse(hexList[hex], radix: 16);
            S += hexValue;
          }
          while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
            S = S - 256;
          }
          String sum = S.toRadixString(16);
          if(hexList[0] == '01' && hexList[1] == '11' && hexList[6] == '02'){
            if(sum == hexList[5]){
              BanTin11 = hexList;
              _BanTin2(intValue, hexList, mang, port);
            }
            else{
              setState(() {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('Error: Checksum sai'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
                return;
              });
            }
          }
          else{
            setState(() {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Thông báo'),
                    content: Text('Error: Bản tin sai cú pháp'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Đóng'),
                      ),
                    ],
                  );
                },
              );
            });
            return;
          }
        }).catchError((error) {
          // Xử lý lỗi từ Completer
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Thông báo'),
                content: Text('Error: $error'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Đóng'),
                  ),
                ],
              );
            },
          );
          return;
        });
      } else {
        print('Serial port is not open');
      }

    } catch (e) {
      print('Error: $e');
    }
  }

  ///
  _BanTin2(int intValue, List<String> hexList, String mang, SerialPort port) async {
    int  n = 10;
    intValue = int.parse(hexList[4]+hexList[3], radix: 16);
    print("value: ${intValue/20}");
    const timeoutDuration = Duration(seconds: 5);
    // Tạo một Completer để theo dõi khi nào nhận được dữ liệu
    Completer<List<int>> completer1 = Completer<List<int>>();
    // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
    Timer timeoutTimer;
    if((intValue/n).toInt() > 0){
      for(int k = 0; k < (intValue/n).toInt();k++){
        // String byte3 = (k*n).toRadixString(16).padLeft(2, '0').padRight(4, '0');
        int number = (k*n);
        // Chuyển đổi số thành mã hex 2 byte
        String hexString = number.toRadixString(16).padLeft(4, '0');
        // Tạo danh sách 2 byte từ mã hex
        List<int> bytes = [];
        for (int i = 0; i < hexString.length; i += 2) {
          String hexByte = hexString.substring(i, i + 2);
          int byte = int.parse(hexByte, radix: 16);
          bytes.add(byte);
        }
        // Đảo ngược thứ tự byte
        List<int> reversedBytes = bytes.reversed.toList();
        // In mã hex với thứ tự byte thấp ở trước byte cao
        String byte3 = reversedBytes.map((byte) {
          String hex = byte.toRadixString(16).padLeft(2, '0');
          return hex;
        }).join('');


        print("Lần thứ $k");
        print("Byte thu 3: $byte3 \n ${(intValue/n).toInt()}");
        String hex1 = '011206' +'${mang}'+'00'+'${byte3}'+'0A00'; // Nhớ đổi giá trị sau byte3
        print("Mã hex1: $hex1");
        int S = 0;
        List<String> hex1List = [];

        print("Start ");
        try{
          for (int i = 0; i < hex1.length; i += 2) {
            String hexValue = hex1.substring(i, i + 2);
            hex1List.add(hexValue);
          }
        }catch(e){
          print(e);
        }
        // print("Ban tin 1: $hex1List");

        for (var hex in hex1List) {
          int hexValue = int.parse(hex, radix: 16);
          S += hexValue;
        }
        while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
          S = S - 256;
        }
        String sum = S.toRadixString(16);
        print("Sum nhận đucợ: $sum");
        sum.length %2 != 0 ? sum = '0'+sum:sum;

        // print("Checksum: $sum");
        var hex2 = hex1+'${sum}02';
        // print("Mã hex2: $hex2");
        List<String> Bantin = [];

        for (int i = 0; i < hex2.length; i += 2) {
          String hexValue = hex2.substring(i, i + 2);
          Bantin.add(hexValue);
        }
        print("Ban tin 2: $Bantin");
        List<int> intList = Bantin.map((hex) => int.parse(hex, radix: 16)).toList();
        await port.writeBytesFromUint8List(Uint8List.fromList(intList));
        timeoutTimer = Timer(timeoutDuration, () {
          // Hủy bỏ Completer nếu thời gian chờ kết thúc
          if (!completer1.isCompleted) {
            completer1.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
          }
        });
        port.readBytesOnListen(2*n+5, (value){
          // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
          if (!timeoutTimer.isActive) {
            return; // Không làm gì nếu đã hết thời gian chờ
          }
          // Hoàn thành Completer nếu nhận được dữ liệu
          if (!completer1.isCompleted) {
            completer1.complete(value); // Gửi dữ liệu tới Completer
          }


        });
        try{
          await completer1.future.then((data) {
            print("Phan nguyen thu  ,,,,,,,,,,,,,,,,,,,,,,,,,, $k");
            // Xử lý dữ liệu thành công
            List<String> List_hex = [];
            for (var byte in data) {
              String hex = byte.toRadixString(16).padLeft(2, '0');
              List_hex.add(hex);
            }
            print("mã nhạn được: $List_hex");
            S = 0;
            for (int hex = 0; hex < List_hex.length - 2; hex++) {
              int hexValue = int.parse(List_hex[hex], radix: 16);
              S += hexValue;
            }
            while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
              S = S - 256;
            }
            String sum = S.toRadixString(16).padLeft(2, '0');
            print("Sum là: $sum");
            print("bản tin nhận được :: $List_hex");
            if(List_hex[0] == '01' && List_hex[1] == '13' && List_hex[n*2+4] =='02'){

               if(sum == List_hex[n*2+3]){
                 List<int> _value =[];
                 for(int i = 3; i < List_hex.length - 3;i = i + 2){
                   _value.add(int.parse(List_hex[i+1]+List_hex[i], radix: 16));
                 }
                 data_save.addAll(_value);
                 print("Gia tri nhan duoc 0:$_value");
              }
              else{
                k = intValue;
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('Error: Checksum Sai'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
                return;
              }

            }
            else{
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Thông báo'),
                    content: Text('Error: Tin tức sai cú pháp'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Đóng'),
                      ),
                    ],
                  );
                },
              );
              return;
            }
          }).catchError((error) {
            // Xử lý lỗi từ Completer
            print('Error: $error');
            if(error == 'Timeout'){
              print('Error_thoat $k: $error');
              k = intValue;
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Thông báo'),
                    content: Text('Error: $error'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Đóng'),
                      ),
                    ],
                  );
                },
              );
            }
          });
        }finally {
          completer1 = Completer<List<int>>();
          timeoutTimer.cancel();
        }


        int residual = intValue%n;
        if(residual != 0 && k == (intValue/n).toInt() - 1){
          print("Phan dư ,,,,,,,,,,,,,,,,,,,,,,,,,, $k");
          // String _byte3 = ((intValue/n).toInt()*n).toRadixString(16).padLeft(2, '0').padRight(4, '0');
          int number = ((intValue/n).toInt()*n);
          // Chuyển đổi số thành mã hex 2 byte
          String hexString = number.toRadixString(16).padLeft(4, '0');
          // Tạo danh sách 2 byte từ mã hex
          List<int> bytes = [];
          for (int i = 0; i < hexString.length; i += 2) {
            String hexByte = hexString.substring(i, i + 2);
            int byte = int.parse(hexByte, radix: 16);
            bytes.add(byte);
          }
          // Đảo ngược thứ tự byte
          List<int> reversedBytes = bytes.reversed.toList();
          // In mã hex với thứ tự byte thấp ở trước byte cao
          String _byte3 = reversedBytes.map((byte) {
            String hex = byte.toRadixString(16).padLeft(2, '0');
            return hex;
          }).join('');

          print("byte3:$_byte3");
          String du = residual.toRadixString(16).toUpperCase();
          du.length == 1 ? du = '0$du' : du;
          print("So du là: $du");
          String hex1 = '011206' +'${mang}'+'00'+'${_byte3}'+'${du}00';
          int S = 0;
          List<String> hex1List = [];

          print("Banr tin cuoi");
          print("Kiem tra Hex1:$hex1");
          try{
            for (int i = 0; i < hex1.length; i += 2) {
              String hexValue = hex1.substring(i, i + 2);
              hex1List.add(hexValue);
            }
          }catch(e){
            print(e);
          }

          for (var hex in hex1List) {
            int hexValue = int.parse(hex, radix: 16);
            S += hexValue;
            print("Gia tri S là: $S");
          }

          while(S > int.parse('FF', radix: 16)){
            S = S - 256;
          }
          String sum = S.toRadixString(16);
          sum.length %2 != 0 ? sum = '0'+sum:sum;
          print("Checksum: $sum");
          var hex2 = hex1+'${sum}02';
          print("Mã hex2: $hex2");
          List<String> Bantin = [];

          for (int i = 0; i < hex2.length; i += 2) {
            String hexValue = hex2.substring(i, i + 2);
            Bantin.add(hexValue);
          }
          print("Ban tin 2: $Bantin");
          List<int> intList = Bantin.map((hex) => int.parse(hex, radix: 16)).toList();
          await port.writeBytesFromUint8List(Uint8List.fromList(intList));

          // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
          timeoutTimer = Timer(timeoutDuration, () {
            // Hủy bỏ Completer nếu thời gian chờ kết thúc
            if (!completer1.isCompleted) {
              completer1.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
            }
          });

          port.readBytesOnListen(n*2 + 5, (value){
            // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
            if (!timeoutTimer.isActive) {
              return; // Không làm gì nếu đã hết thời gian chờ
            }
            // Hoàn thành Completer nếu nhận được dữ liệu
            if (!completer1.isCompleted) {
              completer1.complete(value); // Gửi dữ liệu tới Completer
            }

          });
          try{
            await completer1.future.then((data) {
              List<String> List_hex = [];
              for (var byte in data) {
                String hex = byte.toRadixString(16).padLeft(2, '0');
                List_hex.add(hex);
              }
              print("....: $List_hex");
              S = 0;
              for (int hex = 0; hex < List_hex.length - 2; hex++) {
                int hexValue = int.parse(List_hex[hex], radix: 16);
                S += hexValue;
              }
              while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                S = S - 256;
              }
              String sum = S.toRadixString(16);
              if(List_hex[0] == '01' && List_hex[1] == '13' && List_hex[List_hex.length-1] == '02'){
                if(sum == List_hex[List_hex.length-2]){
                  List<int> _value =[];
                  for(int i = 3; i < List_hex.length - 3;i = i +2){
                    _value.add(int.parse(List_hex[i+1]+List_hex[i], radix: 16));
                  }
                  data_save.addAll(_value);
                  print("Gia tri nhan duoc 1:$_value");
                  // ĐỌc dữ liệu
                  if(intValue == data_save.length){
                    replaceArrayInFile(filePathSave,'Mang$mang',data_save);
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Thông báo'),
                          content: Text('Đọc dữ liệu thành công!\n $data_save'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Đóng'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                  else{
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Thông báo'),
                          content: Text('Độ dài cần đọc là $intValue\nĐộ dài đọc được: ${data_save.length}'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Đóng'),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }
                }
                else{
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Thông báo'),
                        content: Text('Error: Checksum Sai'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('Đóng'),
                          ),
                        ],
                      );
                    },
                  );
                }

              }else{
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('Error: Tin tức sai cú pháp'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
              }
            }).catchError((error) {
              // Xử lý lỗi từ Completer
              if(error == 'Timeout'){
                print('Error_thoat $k: $error');
                k = intValue;
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('Error: $error'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
              }
              print('Error: $error');
            });
          }finally {
            completer1 = Completer<List<int>>();
            timeoutTimer.cancel();
          }


        }

        if(residual == 0 && k == (intValue/20).toInt() -1){
          if(intValue == data_save.length){
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Đọc dữ liệu thành công!\n $data_save'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
            replaceArrayInFile(filePathSave,'Mang$mang',data_save);
          }else{
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Độ dài cần đọc là $intValue\nĐộ dài đọc được: ${data_save.length}'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
            data_save = [];
          }

        }
        // new Future.delayed(Duration(seconds: 2),() async {
        //   print("checkvalue_ $k: $check_read2");
        //   if(check_read2 == 0){
        //     showDialog(
        //       context: context,
        //       builder: (BuildContext context) {
        //         return AlertDialog(
        //           title: Text('Thông báo'),
        //           content: Text('Không có dữ liệu phản hồi 1'),
        //           actions: [
        //             TextButton(
        //               onPressed: () {
        //                 Navigator.of(context).pop();
        //               },
        //               child: Text('Đóng'),
        //             ),
        //           ],
        //         );
        //       },
        //     );
        //   }
        //   else{
        //
        //
        //   }
        // });
      }

    }
    else{
      print("Phan dư ,,,,,,,,,,,,,,,,,,,,,,,,,, ");
      int number = 0;
      // Chuyển đổi số thành mã hex 2 byte
      String hexString = number.toRadixString(16).padLeft(4, '0');
      // Tạo danh sách 2 byte từ mã hex
      List<int> bytes = [];
      for (int i = 0; i < hexString.length; i += 2) {
        String hexByte = hexString.substring(i, i + 2);
        int byte = int.parse(hexByte, radix: 16);
        bytes.add(byte);
      }
      // Đảo ngược thứ tự byte
      List<int> reversedBytes = bytes.reversed.toList();
      // In mã hex với thứ tự byte thấp ở trước byte cao
      String _byte3 = reversedBytes.map((byte) {
        String hex = byte.toRadixString(16).padLeft(2, '0');
        return hex;
      }).join('');

      print("byte3:$_byte3");
      String du = (intValue%20).toRadixString(16).toUpperCase();
      du.length == 1 ? du = '0$du' : du;
      print("So du là: $du");
      String hex1 = '011206' +'${mang}'+'00'+'${_byte3}'+'${du}00';
      int S = 0;
      List<String> hex1List = [];

      try{
        for (int i = 0; i < hex1.length; i += 2) {
          String hexValue = hex1.substring(i, i + 2);
          hex1List.add(hexValue);
        }
      }catch(e){
        print(e);
      }

      for (var hex in hex1List) {
        int hexValue = int.parse(hex, radix: 16);
        S += hexValue;
      }

      while(S > int.parse('FF', radix: 16)){
        S = S - 255;
      }
      String sum = S.toRadixString(16);
      sum.length %2 != 0 ? sum = '0'+sum:sum;
      print("Checksum: $sum");
      var hex2 = hex1+'${sum}02';
      print("Mã hex2: $hex2");
      List<String> Bantin = [];

      for (int i = 0; i < hex2.length; i += 2) {
        String hexValue = hex2.substring(i, i + 2);
        Bantin.add(hexValue);
      }
      print("Ban tin 2: $Bantin");
      List<int> intList = Bantin.map((hex) => int.parse(hex, radix: 16)).toList();
      await port.writeBytesFromUint8List(Uint8List.fromList(intList));

      // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
      timeoutTimer = Timer(timeoutDuration, () {
        // Hủy bỏ Completer nếu thời gian chờ kết thúc
        if (!completer1.isCompleted) {
          completer1.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
        }
      });

      port.readBytesOnListen(40 + 5, (value){
        // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
        if (!timeoutTimer.isActive) {
          return; // Không làm gì nếu đã hết thời gian chờ
        }
        // Hoàn thành Completer nếu nhận được dữ liệu
        if (!completer1.isCompleted) {
          completer1.complete(value); // Gửi dữ liệu tới Completer
        }

      });
      try{
        await completer1.future.then((data) {
          List<String> List_hex = [];
          for (var byte in data) {
            String hex = byte.toRadixString(16).padLeft(2, '0');
            List_hex.add(hex);
          }
          print("....: $List_hex");
          S = 0;
          for (int hex = 0; hex < List_hex.length - 2; hex++) {
            int hexValue = int.parse(List_hex[hex], radix: 16);
            S += hexValue;
          }
          while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
            S = S - 256;
          }
          String sum = S.toRadixString(16);
          if(List_hex[0] == '01' && List_hex[1] == '13' && List_hex[List_hex.length-1] == '02'){
            if(sum == List_hex[List_hex.length-2]){
              List<int> _value =[];
              for(int i = 3; i < List_hex.length - 3;i = i +2){
                _value.add(int.parse(List_hex[i+1]+List_hex[i], radix: 16));
              }
              data_save.addAll(_value);
              print("Gia tri nhan duoc 1:$_value");
              // ĐỌc dữ liệu
              if(intValue == data_save.length){
                replaceArrayInFile(filePathSave,'Mang$mang',data_save);
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('Đọc dữ liệu thành công!\n $data_save'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
              }
              else{
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('Độ dài cần đọc là $intValue\nĐộ dài đọc được: ${data_save.length}'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
                return;
              }
            }
            else{
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Thông báo'),
                    content: Text('Error: Checksum Sai'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Đóng'),
                      ),
                    ],
                  );
                },
              );
              return;
            }

          }
          else{
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Error: Tin tức sai cú pháp'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
            return;
          }
        }).catchError((error) {
          // Xử lý lỗi từ Completer
          if(error == 'Timeout'){
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Error: $error'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
          }
          print('Error: $error');
        });
      }finally {
        completer1 = Completer<List<int>>();
        timeoutTimer.cancel();
      }
    }
  }

  ///

  void connectToSerialPort() async {
    final port = SerialPort(
        "${selectedComLabel}",
        BaudRate: int.parse(selectedBaud!),
        openNow: false,
        ByteSize: 8,
        ReadIntervalTimeout: 1,
        ReadTotalTimeoutConstant: 2
    );
    try{
      port.open();
      if(port.isOpened){
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thông báo'),
              content: Text('Kết nối cổng thành công\nChờ kết nối ACM...'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Đóng'),
                ),
              ],
            );
          },
        );

        final Holding_Register = [0x10, 0x06, 0x00, 0x3C, 0x00, 0x01, 0x8B, 0x47];

        port.writeBytesFromUint8List(Uint8List.fromList(Holding_Register));
        const timeoutDuration = Duration(seconds: 5);
        // Tạo một Completer để theo dõi khi nào nhận được dữ liệu
        Completer<List<int>> completer = Completer<List<int>>();
        // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
        Timer timeoutTimer = Timer(timeoutDuration, () {
          // Hủy bỏ Completer nếu thời gian chờ kết thúc
          if (!completer.isCompleted) {
            completer.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
          }
        });
        port.readBytesOnListen(8, (value) async {
          // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
          if (!timeoutTimer.isActive) {
            return; // Không làm gì nếu đã hết thời gian chờ
          }
          // Hoàn thành Completer nếu nhận được dữ liệu
          if (!completer.isCompleted) {
            completer.complete(value); // Gửi dữ liệu tới Completer
          }
        });
        completer.future.then((data) {
          // Xử lý dữ liệu thành công
          print('Received data: $data');
          List<String> hexList = [];
          for (var byte in data) {
            String hex = byte.toRadixString(16).padLeft(2, '0');
            hexList.add(hex);
          }
          if(hexList[0] == '10'){
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Kết nối ACM thành công!'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
          }


        }).catchError((error) {
          port.close();
          // Xử lý lỗi từ Completer
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Thông báo'),
                content: Text('Error: $error\nKết nối ACM thất bại!'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Đóng'),
                  ),
                ],
              );
            },
          );
          return;
        });
      }
      else{
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thông báo'),
              content: Text('Kết nối không thành công'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Đóng'),
                ),
              ],
            );
          },
        );
        return;
      }
    }catch(e){
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Thông báo'),
            content: Text('Đã được kết nối vui lòng không ấn kết nối\n$e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Đóng'),
              ),
            ],
          );
        },
      );
      return;
    }

  }

  Future Read_1() async{
    var x1 = [0x01, 0x10, 0x02, 0x01, 0x00, 0x14, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'01');
  }
  Future Read_2() async{
    var x1 = [0x01, 0x10, 0x02, 0x02, 0x00, 0x15, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'02');
  }
  Future Read_3() async{
    var x1 = [0x01, 0x10, 0x02, 0x03, 0x00, 0x16, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'03');
  }
  Future Read_4() async{
    var x1 = [0x01, 0x10, 0x02, 0x04, 0x00, 0x17, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'04');
  }
  Future Read_5() async{
    var x1 = [0x01, 0x10, 0x02, 0x05, 0x00, 0x18, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'05');
  }
  Future Read_6() async{
    var x1 = [0x01, 0x10, 0x02, 0x06, 0x00, 0x19, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'06');
  }
  Future Read_7() async{
    var x1 = [0x01, 0x10, 0x02, 0x07, 0x00, 0x1A, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'07');
  }
  Future Read_8() async{
    var x1 = [0x01, 0x10, 0x02, 0x08, 0x00, 0x1B, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'08');
  }
  Future Read_9() async{
    var x1 = [0x01, 0x10, 0x02, 0x09, 0x00, 0x1C, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'09');
  }
  Future Read_10() async{
    var x1 = [0x01, 0x10, 0x02, 0x0A, 0x00, 0x1D, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0A');
  }
  Future Read_11() async{
    var x1 = [0x01, 0x10, 0x02, 0x0B, 0x00, 0x1E, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0B');
  }
  Future Read_12() async{
    var x1 = [0x01, 0x10, 0x02, 0x0C, 0x00, 0x1F, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0C');
  }
  Future Read_13() async{
    var x1 = [0x01, 0x10, 0x02, 0x0D, 0x00, 0x20, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0D');
  }
  Future Read_14() async{
    var x1 = [0x01, 0x10, 0x02, 0x0E, 0x00, 0x21, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0E');
  }
  Future Read_15() async{
    var x1 = [0x01, 0x10, 0x02, 0x0F, 0x00, 0x22, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0F');
  }
  Future Read_16() async{
    var x1 = [0x01, 0x10, 0x02, 0x10, 0x00, 0x23, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'10');
  }
  Future Read_17() async{
    var x1 = [0x01, 0x10, 0x02, 0x11, 0x00, 0x24, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'11');
  }
  Future Read_18() async{
    var x1 = [0x01, 0x10, 0x02, 0x12, 0x00, 0x25, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'12');
  }
  Future Read_19() async{
    var x1 = [0x01, 0x10, 0x02, 0x13, 0x00, 0x26, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'13');
  }
  Future Read_20() async{
    var x1 = [0x01, 0x10, 0x02, 0x14, 0x00, 0x27, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'14');
  }
  Future Read_21() async{
    var x1 = [0x01, 0x10, 0x02, 0x15, 0x00, 0x28, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'15');
  }
  Future Read_22() async{
    var x1 = [0x01, 0x10, 0x02, 0x16, 0x00, 0x29, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'16');
  }
  Future Read_23() async{
    var x1 = [0x01, 0x10, 0x02, 0x17, 0x00, 0x2A, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'17');
  }
  Future Read_24() async{
    var x1 = [0x01, 0x10, 0x02, 0x18, 0x00, 0x2B, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'18');
  }
  Future Read_25() async{
    var x1 = [0x01, 0x10, 0x02, 0x19, 0x00, 0x2C, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'19');
  }
  Future Read_26() async{
    var x1 = [0x01, 0x10, 0x02, 0x1A, 0x00, 0x2D, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'1A');
  }
  Future Read_27() async{
    var x1 = [0x01, 0x10, 0x02, 0x1B, 0x00, 0x2E, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'1B');
  }
  Future Read_28() async{
    var x1 = [0x01, 0x10, 0x02, 0x1C, 0x00, 0x2F, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'1C');
  }
  Future Read_29() async{
    var x1 = [0x01, 0x10, 0x02, 0x1D, 0x00, 0x30, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'1D');
  }
  Future Read_30() async{
    var x1 = [0x01, 0x10, 0x02, 0x1E, 0x00, 0x31, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'1E');
  }
  Future Read_31() async{
    var x1 = [0x01, 0x10, 0x02, 0x1F, 0x00, 0x32, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'1F');
  }
  Future Read_32() async{
    var x1 = [0x01, 0x10, 0x02, 0x20, 0x00, 0x33, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'20');
  }
  Future Read_33() async{
    var x1 = [0x01, 0x10, 0x02, 0x21, 0x00, 0x34, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'21');
  }
  Future Read_34() async{
    var x1 = [0x01, 0x10, 0x02, 0x22, 0x00, 0x35, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'22');
  }
  Future Read_35() async{
    var x1 = [0x01, 0x10, 0x02, 0x23, 0x00, 0x36, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'23');
  }
  Future Read_36() async{
    var x1 = [0x01, 0x10, 0x02, 0x24, 0x00, 0x37, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'24');
  }
  Future Read_37() async{
    var x1 = [0x01, 0x10, 0x02, 0x25, 0x00, 0x38, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'25');
  }
  Future Read_38() async{
    var x1 = [0x01, 0x10, 0x02, 0x26, 0x00, 0x39, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'26');
  }
  Future Read_39() async{
    var x1 = [0x01, 0x10, 0x02, 0x27, 0x00, 0x3A, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'27');
  }
  Future Read_40() async{
    var x1 = [0x01, 0x10, 0x02, 0x28, 0x00, 0x3B, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'28');
  }

  Tool_Sopt(String mang) async {
    int  n = 10;
    List<int>? write_data = [];
    write_data = arrays['Mang$mang'];
    if(write_data == null){
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Thông báo'),
            content: Text('Mảng chưa tồn tại!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Đóng'),
              ),
            ],
          );
        },
      );
      return;
    }
    final port = SerialPort(
        "${selectedComLabel}",
        BaudRate: int.parse(selectedBaud!),
        openNow: false,
        ByteSize: 8,
        ReadIntervalTimeout: 1,
        ReadTotalTimeoutConstant: 2
    );
    int leg = write_data!.length;
    print("leg: $leg");
    // String hex = leg.toRadixString(16).padLeft(2, '0').padRight(4, '0');
    // Chuyển đổi số thành mã hex 2 byte
    String hexString = leg.toRadixString(16).padLeft(4, '0');
    // Tạo danh sách 2 byte từ mã hex
    List<int> bytes = [];
    for (int i = 0; i < hexString.length; i += 2) {
      String hexByte = hexString.substring(i, i + 2);
      int byte = int.parse(hexByte, radix: 16);
      bytes.add(byte);
    }
    // Đảo ngược thứ tự byte
    List<int> reversedBytes = bytes.reversed.toList();
    // In mã hex với thứ tự byte thấp ở trước byte cao
    String byte3 = reversedBytes.map((byte) {
      String hex1 = byte.toRadixString(16).padLeft(2, '0');
      return hex1;
    }).join('');

    print("Mã hex cua do dai: $byte3");
    String hex20 = '012004${mang}00${byte3}';

    int S = 0;
    List<String> hex20List = [];

    print("Start ");
    try{
      for (int i = 0; i < hex20.length; i += 2) {
        String hexValue = hex20.substring(i, i + 2);
        hex20List.add(hexValue);
      }
    }catch(e){
      print(e);
    }
    print("Ban tin hex20List: $hex20List");

    for (var hex in hex20List) {
      int hexValue = int.parse(hex, radix: 16);
      S += hexValue;
    }
    print("S1: ${S.toRadixString(16)}");
    while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
      S = S - 256;
    }
    String sum = S.toRadixString(16);
    sum.length %2 != 0 ? sum = '0'+sum:sum;

    print("Checksum: $sum");
    var hex_20 = hex20+'${sum}02';
    // print("Mã hex2: $hex2");
    List<String> Bantin = [];

    for (int i = 0; i < hex_20.length; i += 2) {
      String hexValue = hex_20.substring(i, i + 2);
      Bantin.add(hexValue);
    }
    print("Ban tin 2: $Bantin");
    List<int> intList = Bantin.map((hex) => int.parse(hex, radix: 16)).toList();
    List<String> Response = [];
    await port.writeBytesFromUint8List(Uint8List.fromList(intList));
    // Thiết lập thời gian chờ là 5 giây
    const timeoutDuration = Duration(seconds: 5);
    // Tạo một Completer để theo dõi khi nào nhận được dữ liệu
    Completer<List<int>> completer = Completer<List<int>>();
    // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
    Timer timeoutTimer = Timer(timeoutDuration, () {
      // Hủy bỏ Completer nếu thời gian chờ kết thúc
      if (!completer.isCompleted) {
        completer.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
      }
    });
    port.readBytesOnListen(7, (value) async {
      // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
      if (!timeoutTimer.isActive) {
        return; // Không làm gì nếu đã hết thời gian chờ
      }
      // Hoàn thành Completer nếu nhận được dữ liệu
      if (!completer.isCompleted) {
        completer.complete(value); // Gửi dữ liệu tới Completer
      }
    });
    completer.future.then((data) async {
      // Xử lý dữ liệu thành công
      print('Received data: $data');
      for (var byte in data) {
        String hex = byte.toRadixString(16).padLeft(2, '0');
        Response.add(hex);
      }
      print("Received data Res: $Response");
      int S = 0;
      for (int hex = 0; hex < Response.length - 2; hex++) {
        int hexValue = int.parse(Response[hex], radix: 16);
        S += hexValue;
      }
      while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
        S = S - 256;
      }
      String sum = S.toRadixString(16);
      String hex22 = '';
      if(Response[0] == '01' && Response[1] == '21' && Response[6] == '02' && Response[2] == '02'){
        if(sum == Response[5]){
          if(Response[3] == '01'){
            const timeoutDuration = Duration(seconds: 5);
            // Tạo một Completer để theo dõi khi nào nhận được dữ liệu
            Completer<List<int>> completer1 = Completer<List<int>>();
            // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
            Timer timeoutTimer;
            if((write_data!.length/n).toInt() > 0){
              for(int i = 0; i < ((write_data.length)/n).toInt() ;i++){


                int number = (i*n);
                // Chuyển đổi số thành mã hex 2 byte
                String hexString = number.toRadixString(16).padLeft(4, '0');
                // Tạo danh sách 2 byte từ mã hex
                List<int> bytes = [];
                for (int i = 0; i < hexString.length; i += 2) {
                  String hexByte = hexString.substring(i, i + 2);
                  int byte = int.parse(hexByte, radix: 16);
                  bytes.add(byte);
                }
                // Đảo ngược thứ tự byte
                List<int> reversedBytes = bytes.reversed.toList();
                // In mã hex với thứ tự byte thấp ở trước byte cao
                String byte3 = reversedBytes.map((byte) {
                  String hex = byte.toRadixString(16).padLeft(2, '0');
                  return hex;
                }).join('');
                print("Byte Vi tri: $byte3");
                hex22 = '01221A${mang}00${byte3}0A00';
                print(hex22);
                List<String> hexList22 = [];

                for (int number = i*n;number < (i*n+n); number++) {
                  String hex = write_data[number].toRadixString(16).padLeft(4, '0');
                  String swappedHex = hex.substring(2, 4) + hex.substring(0, 2);
                  hexList22.add(swappedHex);
                }
                for (String data in hexList22){
                  hex22 = hex22 + data;
                }
                print("Mã hex nhân được lần thứ $i là: $hex22");
                //
                List<String> hex22List = [];
                int S22=0;
                for (int i = 0; i < hex22.length; i += 2) {
                  String hexValue = hex22.substring(i, i + 2);
                  hex22List.add(hexValue);
                }
                for (var hex in hex22List) {
                  int hexValue = int.parse(hex, radix: 16);
                  S22 += hexValue;
                }
                while(int.parse(S22.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                  S22 = S22 - 256;
                }
                String sum = S22.toRadixString(16);
                sum.length %2 != 0 ? sum = '0'+sum:sum;
                var hex_22 = hex22+'${sum}02';
                ///
                List<String> Bantin22 = [];

                for (int i = 0; i < hex_22.length; i += 2) {
                  String hexValue = hex_22.substring(i, i + 2);
                  Bantin22.add(hexValue);
                }
                print("Ban tin 2: $Bantin22");
                List<int> intList = Bantin22.map((hex) => int.parse(hex, radix: 16)).toList();
                print("Bantin :$intList");
                await port.writeBytesFromUint8List(Uint8List.fromList(intList));
                List<String> Response23 = [];
                timeoutTimer = Timer(timeoutDuration, () {
                  // Hủy bỏ Completer nếu thời gian chờ kết thúc
                  if (!completer1.isCompleted) {
                    completer1.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
                  }
                });
                port.readBytesOnListen(7, (value){
                  // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
                  if (!timeoutTimer.isActive) {
                    return; // Không làm gì nếu đã hết thời gian chờ
                  }
                  // Hoàn thành Completer nếu nhận được dữ liệu
                  if (!completer1.isCompleted) {
                    completer1.complete(value); // Gửi dữ liệu tới Completer
                  }


                });
                try{
                  await completer1.future.then((data) {
                    for (var byte in data) {
                      String hex = byte.toRadixString(16).padLeft(2, '0');
                      Response23.add(hex);
                    }
                    int S = 0;
                    for (int hex = 0; hex < Response23.length - 2; hex++) {
                      int hexValue = int.parse(Response23[hex], radix: 16);
                      S += hexValue;
                    }
                    while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                      S = S - 256;
                    }
                    String sum = S.toRadixString(16);
                    if(Response23[0] == '01' && Response23[1] == '23' && Response23[6] == '02' && Response23[2] == '02'){
                      if(sum == Response23[5]){
                        if(Response23[3] == '01' && i == ((write_data!.length)/n).toInt() - 1 && write_data.length % n == 0){
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Thông báo'),
                                content: Text('Ghi thanh công'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Đóng'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                        if(Response23[3] == '00'){
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Thông báo'),
                                content: Text('Lỗi'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Đóng'),
                                  ),
                                ],
                              );
                            },
                          );
                          i = write_data!.length;
                        }
                        print("Response Hoàn thành");
                      }else{
                        setState(() {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Thông báo'),
                                content: Text('Error: Checksum sai'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Đóng'),
                                  ),
                                ],
                              );
                            },
                          );
                          return;
                        });
                      }
                    }
                    else{
                      setState(() {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Thông báo'),
                              content: Text('Error: Bản tin sai cú pháp'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Đóng'),
                                ),
                              ],
                            );
                          },
                        );
                        return;
                      });
                    }

                  }).catchError((error) {
                    print('Error: $error');
                    if(error == 'Timeout'){
                      i = write_data!.length;
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Thông báo'),
                            content: Text('Error: $error'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Đóng'),
                              ),
                            ],
                          );
                        },
                      );
                      return;
                    }
                  });
                }finally {
                  completer1 = Completer<List<int>>();
                  timeoutTimer.cancel();
                }

                /// Nếu có dư
                if(i == ((write_data.length)/n).toInt() - 1 && (write_data.length)%n != 0){
                  int number = (((write_data.length)/n).toInt()*n);
                  // Chuyển đổi số thành mã hex 2 byte
                  String hexString = number.toRadixString(16).padLeft(4, '0');
                  // Tạo danh sách 2 byte từ mã hex
                  List<int> bytes = [];
                  for (int i = 0; i < hexString.length; i += 2) {
                    String hexByte = hexString.substring(i, i + 2);
                    int byte = int.parse(hexByte, radix: 16);
                    bytes.add(byte);
                  }
                  // Đảo ngược thứ tự byte
                  List<int> reversedBytes = bytes.reversed.toList();
                  // In mã hex với thứ tự byte thấp ở trước byte cao
                  String byte3 = reversedBytes.map((byte) {
                    String hex = byte.toRadixString(16).padLeft(2, '0');
                    return hex;
                  }).join('');
                  String length = (6+2*((write_data.length)%n)).toRadixString(16).padLeft(2, '0');
                  print("Do dai phan tu:$length");
                  print("Vi tri thu: $byte3");
                  hex22 = '0122${length}${mang}00${byte3}${((write_data.length)%n).toRadixString(16).padLeft(2, '0')}00';
                  print("Dư $hex22");
                  List<String> hexList22 = [];

                  for (int number = (((write_data.length)/n).toInt()*n); number < write_data.length; number++) {
                    String hex = write_data[number].toRadixString(16).padLeft(4, '0');
                    String swappedHex = hex.substring(2, 4) + hex.substring(0, 2);
                    hexList22.add(swappedHex);
                  }
                  for (String data in hexList22){
                    hex22 = hex22 + data;
                  }
                  print("Mã hex nhân được là: $hex22");
                  //
                  List<String> hex22List = [];
                  int S22=0;
                  for (int i = 0; i < hex22.length; i += 2) {
                    String hexValue = hex22.substring(i, i + 2);
                    hex22List.add(hexValue);
                  }
                  for (var hex in hex22List) {
                    int hexValue = int.parse(hex, radix: 16);
                    S22 += hexValue;
                  }
                  while(int.parse(S22.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                    S22 = S22 - 256;
                  }
                  String sum = S22.toRadixString(16);
                  sum.length %2 != 0 ? sum = '0'+sum:sum;
                  var hex_22 = hex22+'${sum}02';
                  List<String> Bantin22 = [];

                  for (int i = 0; i < hex_22.length; i += 2) {
                    String hexValue = hex_22.substring(i, i + 2);
                    Bantin22.add(hexValue);
                  }
                  print("Ban tin 2: $Bantin22");
                  List<int> intList = Bantin22.map((hex) => int.parse(hex, radix: 16)).toList();
                  print("Bantin :$intList");
                  await port.writeBytesFromUint8List(Uint8List.fromList(intList));
                  List<String> Response23 = [];
                  timeoutTimer = Timer(timeoutDuration, () {
                    // Hủy bỏ Completer nếu thời gian chờ kết thúc
                    if (!completer1.isCompleted) {
                      completer1.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
                    }
                  });
                  port.readBytesOnListen(7, (value){
                    // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
                    if (!timeoutTimer.isActive) {
                      return; // Không làm gì nếu đã hết thời gian chờ
                    }
                    // Hoàn thành Completer nếu nhận được dữ liệu
                    if (!completer1.isCompleted) {
                      completer1.complete(value); // Gửi dữ liệu tới Completer
                    }


                  });
                  try{
                    await completer1.future.then((data) {
                      for (var byte in data) {
                        String hex = byte.toRadixString(16).padLeft(2, '0');
                        Response23.add(hex);
                      }
                      int S = 0;
                      for (int hex = 0; hex < Response23.length - 2; hex++) {
                        int hexValue = int.parse(Response23[hex], radix: 16);
                        S += hexValue;
                      }
                      while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                        S = S - 256;
                      }
                      String sum = S.toRadixString(16);
                      if(Response23[0] == '01' && Response23[1] == '23' && Response23[6] == '02' && Response23[2] == '02'){
                        if(sum == Response23[5]){
                          if(Response23[3] == '01'){
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Thông báo'),
                                  content: Text('Ghi thanh công'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text('Đóng'),
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                          else{
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Thông báo'),
                                  content: Text('Lỗi'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text('Đóng'),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          }
                          print("Response Hoàn thành");
                        }else{
                          setState(() {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Thông báo'),
                                  content: Text('Error: Checksum sai'),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text('Đóng'),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          });
                        }
                      }
                      else{
                        setState(() {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Thông báo'),
                                content: Text('Error: Bản tin sai cú pháp'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text('Đóng'),
                                  ),
                                ],
                              );
                            },
                          );
                          return;
                        });
                      }

                    }).catchError((error) {
                      print('Error: $error');
                      if(error == 'Timeout'){
                        i = write_data!.length;
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Thông báo'),
                              content: Text('Error: $error'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Đóng'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                    });
                  }finally {
                    completer1 = Completer<List<int>>();
                    timeoutTimer.cancel();
                  }

                }
              }
            }
            else{
              int number = 0;
              // Chuyển đổi số thành mã hex 2 byte
              String hexString = number.toRadixString(16).padLeft(4, '0');
              // Tạo danh sách 2 byte từ mã hex
              List<int> bytes = [];
              for (int i = 0; i < hexString.length; i += 2) {
                String hexByte = hexString.substring(i, i + 2);
                int byte = int.parse(hexByte, radix: 16);
                bytes.add(byte);
              }
              // Đảo ngược thứ tự byte
              List<int> reversedBytes = bytes.reversed.toList();
              // In mã hex với thứ tự byte thấp ở trước byte cao
              String byte3 = reversedBytes.map((byte) {
                String hex = byte.toRadixString(16).padLeft(2, '0');
                return hex;
              }).join('');

              hex22 = '01221A${mang}00${byte3}${((write_data.length)%n).toRadixString(16).padLeft(2, '0')}00';
              print(hex22);
              List<String> hexList22 = [];

              for (int number = 0;number < ((write_data.length)%n); number++) {
                String hex = write_data[number].toRadixString(16).padLeft(4, '0');
                String swappedHex = hex.substring(2, 4) + hex.substring(0, 2);
                hexList22.add(swappedHex);
              }
              for (String data in hexList22){
                hex22 = hex22 + data;
              }
              print("Mã hex nhân được là: $hex22");
              List<String> hex22List = [];
              int S22=0;
              for (int i = 0; i < hex22.length; i += 2) {
                String hexValue = hex22.substring(i, i + 2);
                hex22List.add(hexValue);
              }
              for (var hex in hex22List) {
                int hexValue = int.parse(hex, radix: 16);
                S22 += hexValue;
              }
              while(int.parse(S22.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                S22 = S22 - 256;
              }
              String sum = S22.toRadixString(16);
              sum.length %2 != 0 ? sum = '0'+sum:sum;
              var hex_22 = hex22+'${sum}02';
              ///
              List<String> Bantin22 = [];

              for (int i = 0; i < hex_22.length; i += 2) {
                String hexValue = hex_22.substring(i, i + 2);
                Bantin22.add(hexValue);
              }
              print("Ban tin 22 dữ: $Bantin");
              List<int> intList = Bantin22.map((hex) => int.parse(hex, radix: 16)).toList();

              await port.writeBytesFromUint8List(Uint8List.fromList(intList));

              // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
              timeoutTimer = Timer(timeoutDuration, () {
                // Hủy bỏ Completer nếu thời gian chờ kết thúc
                if (!completer1.isCompleted) {
                  completer1.completeError('Timeout'); // Gửi một lỗi hoặc giá trị tùy ý để đánh dấu thời gian chờ kết thúc
                }
              });

              port.readBytesOnListen(7, (value){
                // Hủy bỏ Timer nếu nhận được dữ liệu trước thời gian chờ kết thúc
                if (!timeoutTimer.isActive) {
                  return; // Không làm gì nếu đã hết thời gian chờ
                }
                // Hoàn thành Completer nếu nhận được dữ liệu
                if (!completer1.isCompleted) {
                  completer1.complete(value); // Gửi dữ liệu tới Completer
                }

              });
              try{
                await completer1.future.then((data) {
                  List<String> List_hex = [];
                  for (var byte in data) {
                    String hex = byte.toRadixString(16).padLeft(2, '0');
                    List_hex.add(hex);
                  }
                  print("....: $List_hex");
                  S = 0;
                  for (int hex = 0; hex < List_hex.length - 2; hex++) {
                    int hexValue = int.parse(List_hex[hex], radix: 16);
                    S += hexValue;
                  }
                  while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
                    S = S - 256;
                  }
                  String sum = S.toRadixString(16);
                  if(List_hex[0] == '01' && List_hex[1] == '23' && List_hex[6] == '02' && List_hex[2] == '02'){
                    if(sum == List_hex[List_hex.length-2]){
                      if(List_hex[3] == '01'){
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Thông báo'),
                              content: Text('Ghi thanh công'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Đóng'),
                                ),
                              ],
                            );
                          },
                        );
                      }
                      else{
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Thông báo'),
                              content: Text('Lỗi'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Đóng'),
                                ),
                              ],
                            );
                          },
                        );
                        return;
                      }
                      print("Response Hoàn thành");
                    }
                    else{
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Thông báo'),
                            content: Text('Error: Checksum Sai'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Đóng'),
                              ),
                            ],
                          );
                        },
                      );
                      return;
                    }

                  }
                  else{
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Thông báo'),
                          content: Text('Error: Tin tức sai cú pháp'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Đóng'),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }
                }).catchError((error) {
                  // Xử lý lỗi từ Completer
                  if(error == 'Timeout'){
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Thông báo'),
                          content: Text('Error: $error'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Đóng'),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }
                  print('Error: $error');
                });
              }finally {
                completer1 = Completer<List<int>>();
                timeoutTimer.cancel();
              }
            }

          }
          else{
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Lỗi'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
            return;
          }
        }
        else{
          setState(() {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Thông báo'),
                  content: Text('Error: Checksum sai'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Đóng'),
                    ),
                  ],
                );
              },
            );
            return;
          });
        }

      }
      else{
        setState(() {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Thông báo'),
                content: Text('Error: Bản tin sai cú pháp'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Đóng'),
                  ),
                ],
              );
            },
          );
          return;
        });
      }

    }).catchError((error) {
      // Xử lý lỗi từ Completer
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Thông báo'),
            content: Text('Error: $error'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Đóng'),
              ),
            ],
          );
        },
      );
      return;
    });



  }

  Future Write_1() async{
    Tool_Sopt('01');
  }
  Future Write_2() async{
    Tool_Sopt('02');
  }
  Future Write_3() async{
    Tool_Sopt('03');
  }
  Future Write_4() async{
    Tool_Sopt('04');
  }
  Future Write_5() async{
    Tool_Sopt('05');
  }
  Future Write_6() async{
    Tool_Sopt('06');
  }
  Future Write_7() async{
    Tool_Sopt('07');
  }
  Future Write_8() async{
    Tool_Sopt('08');
  }
  Future Write_9() async{
    Tool_Sopt('09');
  }
  Future Write_10() async{
    Tool_Sopt('0A');
  }
  Future Write_11() async{
    Tool_Sopt('0B');
  }
  Future Write_12() async{
    Tool_Sopt('0C');
  }
  Future Write_13() async{
    Tool_Sopt('0D');
  }
  Future Write_14() async{
    Tool_Sopt('0E');
  }
  Future Write_15() async{
    Tool_Sopt('0F');
  }
  Future Write_16() async{
    Tool_Sopt('10');
  }
  Future Write_17() async{
    Tool_Sopt('11');
  }
  Future Write_18() async{
    Tool_Sopt('12');
  }
  Future Write_19() async{
    Tool_Sopt('13');
  }
  Future Write_20() async{
    Tool_Sopt('14');
  }
  Future Write_21() async{
    Tool_Sopt('15');
  }
  Future Write_22() async{
    Tool_Sopt('16');
  }
  Future Write_23() async{
    Tool_Sopt('17');
  }
  Future Write_24() async{
    Tool_Sopt('18');
  }
  Future Write_25() async{
    Tool_Sopt('19');
  }
  Future Write_26() async{
    Tool_Sopt('1A');
  }
  Future Write_27() async{
    Tool_Sopt('1B');
  }
  Future Write_28() async{
    Tool_Sopt('1C');
  }
  Future Write_29() async{
    Tool_Sopt('1D');
  }
  Future Write_30() async{
    Tool_Sopt('1E');
  }
  Future Write_31() async{
    Tool_Sopt('1F');
  }
  Future Write_32() async{
    Tool_Sopt('20');
  }
  Future Write_33() async{
    Tool_Sopt('21');
  }
  Future Write_34() async{
    Tool_Sopt('22');
  }
  Future Write_35() async{
    Tool_Sopt('23');
  }
  Future Write_36() async{
    Tool_Sopt('24');
  }
  Future Write_37() async{
    Tool_Sopt('25');
  }
  Future Write_38() async{
    Tool_Sopt('26');
  }
  Future Write_39() async{
    Tool_Sopt('27');
  }
  Future Write_40() async{
    Tool_Sopt('28');
  }

  Future<void> All_Read() async {
    try{
       Read_1(); Read_2(); Read_3(); Read_4(); Read_5();
       Read_6(); Read_7(); Read_8(); Read_9(); Read_10();
       Read_11(); Read_12(); Read_13(); Read_14(); Read_15();
       Read_16(); Read_17(); Read_18(); Read_19(); Read_20();
       Read_21(); Read_22(); Read_23(); Read_24(); Read_25();
       Read_26(); Read_27(); Read_28(); Read_29(); Read_30();
       Read_31(); Read_32(); Read_33(); Read_34(); Read_35();
       Read_36(); Read_37(); Read_38(); Read_39(); Read_40();
    }catch(e){

    }
  }
  Future<void> All_Write() async{
    for(int i = 1; i <= 40; i++){
      String _hex = i.toRadixString(16).padLeft(2, '0');
      if(arrays['Mang$_hex'] != null){
        Tool_Sopt(_hex);
      }
    }
  }
  void _dialogBuilder(BuildContext context, int time) async {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15,),
                  Text('Loading...')
                ],
              ),
            ),

          );
        });
    await Future.delayed( Duration(seconds: time));
    Navigator.of(context).pop();
  }

  int time = 5;
  @override
  Widget build(BuildContext context) {
    double  heightR,widthR;
    heightR = MediaQuery.of(context).size.height / 1080; //v26
    widthR = MediaQuery.of(context).size.width / 2400;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'ACM IR DATA FLASH TOOL!',
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.blue[100],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              height: 80*heightR,
              decoration: BoxDecoration(
                  color: Colors.white
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(width: 20*widthR,),

                  PopupMenuButton(
                      child: Container(
                          child: Text(
                            "File",
                            style: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold
                            ),
                          )
                      ),
                      // color: secondary,
                      // elevation: 20,
                      // enabled: true,
                      onSelected: (value) {
                        if (value == 'open') {
                          try {
                            _Load_Document();
                          } catch (e) {
                            print(e);
                          }
                        }
                        if (value == 'save') {
                          // var save = (data_save.toString()).substring(1,(data_save.toString().length)-1);
                          // print("Gia tr luu dc là: $save");\
                          _Load_Document_Save();



                        }
                      },
                      itemBuilder: (context) =>
                      [
                        PopupMenuItem(
                          child: Text("Open"),
                          value: "open",
                        ),
                        PopupMenuItem(
                          child: Text("Save"),
                          value: "save",
                        ),

                        // PopupMenuItem(
                        //   child: Text("Second"),
                        //   value: "Second",
                        // ),
                      ]),
                  SizedBox(width: 20*widthR,
                  ),
                  Container(
                    height: 100*heightR,
                    width: 300*widthR,
                    child: DropdownButton<String>(
                      value: selectedBaud, // Giá trị mặc định
                      items: Baud.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text('$value'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedBaud = newValue;
                        });
                        //print('Selected COM Port: $newValue');
                      },
                    ),),
                  SizedBox(width: 20*widthR,
                  ),
                  Container(
                    height: 100*heightR,
                    width: 300*widthR,
                    child: DropdownButton<String>(
                      value: selectedComLabel == null ?comPorts[0]: selectedComLabel, // Giá trị mặc định
                      items: comPorts.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text('$value'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedComLabel = newValue;
                          print(selectedComLabel);
                        });
                        //print('Selected COM Port: $newValue');
                      },
                    ),),
                  SizedBox(width: 20*widthR,),
                ],
              ),
            ),
            SizedBox(
            ),
            Container(
              height: 100*heightR,
              width: 2000*widthR,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                  ),
                  Container(
                    child: TextButton(
                        onPressed: () {
                          connectToSerialPort();
                        },
                        child: Text(
                          "Connect",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold
                          ),
                        )
                    ),
                  ),

                  Container(
                    child: TextButton(
                        onPressed: () {
                          setState(() {
                            if(filePathSave != ''){
                              read_or_write = 'read';
                            }
                            else{
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Thông báo'),
                                    content: Text('Chưa mở file để lưu dữ liệu'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Đóng'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }

                          });
                        },
                        child: read_or_write ==  'read' ? Text(
                          "Read",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            color: Colors.black
                          ),
                        ) : Text(
                          "Read",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold
                          ),
                        )
                    ),
                  ),

                  Container(
                    child: TextButton(
                        onPressed: () {
                          setState(() {
                            if(filePathOpen != ''){
                              read_or_write = 'write';
                            }
                            else{
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Thông báo'),
                                    content: Text('Chọn file để đọc viết dữ liệu'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('Đóng'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }

                          });
                        },
                        child: read_or_write == 'write' ? Text(
                          "Write",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            color: Colors.black
                          ),
                        ) : Text(
                          "Write",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold
                          ),
                        )
                    ),
                  ),

                  SizedBox(
                  ),
                ],
              ),
            ),
            SizedBox(
            ),
            read_or_write == 'read' ? Column(
              children: [
                SizedBox(),
                Container(
                  child: TextButton(
                      onPressed: () {
                        _dialogBuilder(context,time);
                        All_Read();

                        // Read_1();Read_2();Read_3();Read_4();Read_5();
                        // Read_6();Read_7();Read_8();Read_9();Read_10();
                        // Read_11();Read_12();Read_13();Read_14();Read_15();
                        // Read_16();Read_17();Read_18();Read_19();Read_20();
                        // Read_21();Read_22();Read_23();Read_24();Read_25();
                        // Read_26();Read_27();Read_28();Read_29();Read_30();
                        // Read_31();Read_32();Read_33();Read_34();Read_35();
                        // Read_36();Read_37();Read_38();Read_39();Read_40();
                      },
                      child: Text(
                        "All Read",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                        ),
                      )
                  ),
                ),
                SizedBox(height: 10*heightR),
                Container(
                  height: 200,
                  width: 700,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black12
                  ),
                  child: IndexedStack(
                    index: page,
                    children: <Widget>[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: ()  {
                                      _dialogBuilder(context,time);
                                      Read_1();
                                    },
                                    child: Text(
                                      "1",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_2();
                                    },
                                    child: Text(
                                      "2",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_3();
                                    },
                                    child: Text(
                                      "3",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_4();
                                    },
                                    child: Text(
                                      "4",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_5();
                                    },
                                    child: Text(
                                      "5",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_6();
                                    },
                                    child: Text(
                                      "6",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      Read_7();
                                      _dialogBuilder(context,time);
                                    },
                                    child: Text(
                                      "7",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_8();
                                    },
                                    child: Text(
                                      "8",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_9();
                                    },
                                    child: Text(
                                      "9",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_10();
                                    },
                                    child: Text(
                                      "10",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: ()  {
                                      _dialogBuilder(context,time);
                                      Read_11();
                                    },
                                    child: Text(
                                      "11",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_12();
                                    },
                                    child: Text(
                                      "12",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_13();
                                    },
                                    child: Text(
                                      "13",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_14();
                                    },
                                    child: Text(
                                      "14",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_15();
                                    },
                                    child: Text(
                                      "15",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_16();
                                    },
                                    child: Text(
                                      "16",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_17();
                                    },
                                    child: Text(
                                      "17",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_18();
                                    },
                                    child: Text(
                                      "18",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_19();
                                    },
                                    child: Text(
                                      "19",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_20();
                                    },
                                    child: Text(
                                      "20",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: ()  {
                                      _dialogBuilder(context,time);
                                      Read_21();
                                    },
                                    child: Text(
                                      "21",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_22();

                                    },
                                    child: Text(
                                      "22",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_23();
                                    },
                                    child: Text(
                                      "23",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_24();
                                    },
                                    child: Text(
                                      "24",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_25();
                                    },
                                    child: Text(
                                      "25",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_26();
                                    },
                                    child: Text(
                                      "26",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_27();
                                    },
                                    child: Text(
                                      "27",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_28();
                                    },
                                    child: Text(
                                      "28",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_29();
                                    },
                                    child: Text(
                                      "29",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_30();
                                    },
                                    child: Text(
                                      "30",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: ()  {
                                      _dialogBuilder(context,time);
                                      Read_31();
                                    },
                                    child: Text(
                                      "31",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_32();
                                    },
                                    child: Text(
                                      "32",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_33();
                                    },
                                    child: Text(
                                      "33",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_34();
                                    },
                                    child: Text(
                                      "34",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_35();
                                    },
                                    child: Text(
                                      "35",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_36();
                                    },
                                    child: Text(
                                      "36",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_37();
                                    },
                                    child: Text(
                                      "37",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_38();
                                    },
                                    child: Text(
                                      "38",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_39();
                                    },
                                    child: Text(
                                      "39",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Read_40();
                                    },
                                    child: Text(
                                      "40",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15*heightR),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(),
                      Container(
                        child: Row(
                          children: [
                            TextButton(onPressed: (){
                              setState(() {
                                page = 0;
                              });},
                                child: Text('1', style: TextStyle(fontSize: 20.0),)),

                            TextButton(onPressed: (){
                              setState(() {
                                page = 1;
                              });
                            },
                              child: Text('2',style: TextStyle(fontSize: 20.0),), ),
                            TextButton(onPressed: (){
                              setState(() {
                                page = 2;
                              });
                            },
                                child: Text('3', style: TextStyle(fontSize: 20.0),)),
                            TextButton(onPressed: (){
                              setState(() {
                                page = 3;
                              });
                            },
                                child: Text('4', style: TextStyle(fontSize: 20.0),)),
                          ],
                        ),
                      ),

                      SizedBox(),

                    ],
                  ),
                ),
                // SpinKitCircle(
                //   color: Colors.lightBlue,
                // ),

              ],
            ) : SizedBox(),

            read_or_write == 'write' ? Column(
              children: [
                SizedBox(),
                Container(
                  child: TextButton(
                      onPressed: () {
                        _dialogBuilder(context,time);
                        All_Write();
                        // for(int i = 1; i <= 40; i++){
                        //   String _hex = i.toRadixString(16).padLeft(2, '0');
                        //   if(arrays['Mang$_hex'] != null){
                        //     Tool_Sopt(_hex);
                        //   }
                        // }
                      },
                      child: Text(
                        "All Write",
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold
                        ),
                      )
                  ),
                ),
                SizedBox(height: 10*heightR),
                Container(
                  height: 200,
                  width: 700,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black12
                  ),
                  child: IndexedStack(
                    index: page,
                    children: <Widget>[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_1();
                                    },
                                    child: Text(
                                      "1",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Write_2();
                                    },
                                    child: Text(
                                      "2",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_3();
                                    },
                                    child: Text(
                                      "3",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_4();
                                    },
                                    child: Text(
                                      "4",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_5();
                                    },
                                    child: Text(
                                      "5",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_6();
                                    },
                                    child: Text(
                                      "6",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_7();
                                    },
                                    child: Text(
                                      "7",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_8();
                                    },
                                    child: Text(
                                      "8",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_9();
                                    },
                                    child: Text(
                                      "9",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_10();
                                    },
                                    child: Text(
                                      "10",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);
                                      Write_11();
                                    },
                                    child: Text(
                                      "11",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_12();
                                    },
                                    child: Text(
                                      "12",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_13();
                                    },
                                    child: Text(
                                      "13",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_14();
                                    },
                                    child: Text(
                                      "14",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_15();
                                    },
                                    child: Text(
                                      "15",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_16();
                                    },
                                    child: Text(
                                      "16",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_17();
                                    },
                                    child: Text(
                                      "17",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_18();
                                    },
                                    child: Text(
                                      "18",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_19();
                                    },
                                    child: Text(
                                      "19",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_20();
                                    },
                                    child: Text(
                                      "20",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_21();
                                    },
                                    child: Text(
                                      "21",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_22();
                                    },
                                    child: Text(
                                      "22",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_23();
                                    },
                                    child: Text(
                                      "23",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_24();
                                    },
                                    child: Text(
                                      "24",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_25();
                                    },
                                    child: Text(
                                      "25",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_26();
                                    },
                                    child: Text(
                                      "26",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_27();
                                    },
                                    child: Text(
                                      "27",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_28();
                                    },
                                    child: Text(
                                      "28",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_29();
                                    },
                                    child: Text(
                                      "29",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_30();
                                    },
                                    child: Text(
                                      "30",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_31();
                                    },
                                    child: Text(
                                      "31",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_32();
                                    },
                                    child: Text(
                                      "32",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_33();
                                    },
                                    child: Text(
                                      "33",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_34();
                                    },
                                    child: Text(
                                      "34",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_35();
                                    },
                                    child: Text(
                                      "35",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                              ),
                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_36();
                                    },
                                    child: Text(
                                      "36",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_37();
                                    },
                                    child: Text(
                                      "37",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_38();
                                    },
                                    child: Text(
                                      "38",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_39();
                                    },
                                    child: Text(
                                      "39",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.indigo
                                ),
                                child: TextButton(
                                    onPressed: () {
                                      _dialogBuilder(context,time);

                                      Write_40();
                                    },
                                    child: Text(
                                      "40",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                          color: Colors.white
                                      ),
                                    )
                                ),
                              ),

                              SizedBox(
                              ),
                            ],
                          ),
                          SizedBox(),
                        ],
                      ),
                    ],
                  ),

                ),
                SizedBox(height: 15*heightR),
                Container(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(),
                      Container(
                        child: Row(
                          children: [
                            TextButton(onPressed: (){
                              setState(() {
                                page = 0;
                              });},
                                child: Text('1', style: TextStyle(fontSize: 20.0),)),

                            TextButton(onPressed: (){
                              setState(() {
                                page = 1;
                              });
                            },
                              child: Text('2',style: TextStyle(fontSize: 20.0),), ),
                            TextButton(onPressed: (){
                              setState(() {
                                page = 2;
                              });
                            },
                                child: Text('3', style: TextStyle(fontSize: 20.0),)),
                            TextButton(onPressed: (){
                              setState(() {
                                page = 3;
                              });
                            },
                                child: Text('4', style: TextStyle(fontSize: 20.0),)),
                          ],
                        ),
                      ),

                      SizedBox(),

                    ],
                  ),
                ),
              ],
            ) : SizedBox(),



            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Thông báo'),
                      content: Text('$data_save'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text('Đóng'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.blue, // background
                  onPrimary: Colors.white, // foreground
                ),
                child: Text('Log', style: TextStyle(fontSize: 28),),
                onPressed: (){},
              ),

            ),
            SizedBox(
            ),
          ],
        ),
      ),
    );
  }
}