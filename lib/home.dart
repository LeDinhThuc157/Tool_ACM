import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
// import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
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
  final List<String> comPorts = List.generate(100, (index) => 'COM${index + 1}');
  final List<String> Baud = List.castFrom(['9600', '19200', '38400', '115200']);
  List<int> data_save = [];
  var intValue;
  String filePath = '';
  _Load_Document() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String path = file.path;
      String convertedPath = path.replaceAll(r'\', '/');
      print("Converted: $convertedPath");

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
      filePath = convertedPath;
    } else {
      // User canceled the picker
    }
  }


  String read_or_write = '';
  // late Uint8List request;
  var check_read2 = 0;
  var BanTin11 = [];
  var intList_write;
  int  n = 10;
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
  // Future<void> waitForData(int k , int intValue) async {
  //   final port = SerialPort(
  //       "${com.text}",
  //       BaudRate: int.parse(brand.text),
  //       openNow: false,
  //       ByteSize: 8,
  //       ReadIntervalTimeout: 1,
  //       ReadTotalTimeoutConstant: 2
  //   );
  //   final completer = Completer<void>();
  //   // Lắng nghe sự kiện nhận dữ liệu
  //   port.readBytesOnListen(2*20+5, (value){
  //     print('Received data: $value');
  //
  //     List<String> List_hex = [];
  //     for (var byte in value) {
  //       String hex = byte.toRadixString(16).padLeft(2, '0');
  //       List_hex.add(hex);
  //     }
  //     print("Lisst 2 :\n ${List_hex}");
  //     if(List_hex[0] == '01' && List_hex[1] == '13' && List_hex[44] =='02'){
  //       List<String> _value =[];
  //       for(int i = 3; i < List_hex.length - 3;i = i + 2){
  //         _value.add(int.parse(List_hex[i+1]+List_hex[i], radix: 16).toString());
  //       }
  //       data_save.addAll(_value);
  //       print("Gia tri nhan duoc 0:$_value");
  //       if(k == (intValue/20).toInt() -1){
  //         showDialog(
  //           context: context,
  //           builder: (BuildContext context) {
  //             return AlertDialog(
  //               title: Text('Thông báo'),
  //               content: Text('Đọc dữ liệu thành công!\n$data_save'),
  //               actions: [
  //                 TextButton(
  //                   onPressed: () {
  //                     Navigator.of(context).pop();
  //                   },
  //                   child: Text('Đóng'),
  //                 ),
  //               ],
  //             );
  //           },
  //         );
  //       }
  //     }
  //     completer.complete();
  //
  //   });
  //   await completer.future;
  //   // try {
  //   //   await completer.future.timeout(Duration(seconds: 10));
  //   //   check_read2 = 100;// Chờ đến khi nhận được dữ liệu hoặc timeout sau 10s
  //   // } catch (e) {
  //   //     print('Timeout: No data received ${completer.isCompleted}');
  //   //     check_read2  = 0;
  //   // }
  // }

  ///
  _BanTin2(int intValue, List<String> hexList, String mang, SerialPort port) async {

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
        String hex1 = '011206' +'${mang}'+'00'+'${byte3}'+'0A00';
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
            String sum = S.toRadixString(16);
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
                    replaceArrayInFile(filePath,'Mang$mang',data_save);
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
            replaceArrayInFile(filePath,'Mang$mang',data_save);
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
                replaceArrayInFile(filePath,'Mang$mang',data_save);
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
    print("COM: $selectedComLabel");
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
                content: Text('Error: $error\nKết nối Modbus thất bại!'),
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
      }else{
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
            content: Text('Đã được kết nối vui lòng không ấn kết nối'),
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

  Read_1(){
    var x1 = [0x01, 0x10, 0x02, 0x01, 0x00, 0x14, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'01');
  }
  Read_2(){
    var x1 = [0x01, 0x10, 0x02, 0x02, 0x00, 0x15, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'02');
  }
  Read_3(){
    var x1 = [0x01, 0x10, 0x02, 0x03, 0x00, 0x16, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'03');
  }
  Read_4(){
    var x1 = [0x01, 0x10, 0x02, 0x04, 0x00, 0x17, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'04');
  }
  Read_5(){
    var x1 = [0x01, 0x10, 0x02, 0x05, 0x00, 0x18, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'05');
  }
  Read_6(){
    var x1 = [0x01, 0x10, 0x02, 0x06, 0x00, 0x19, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'06');
  }
  Read_7(){
    var x1 = [0x01, 0x10, 0x02, 0x07, 0x00, 0x1A, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'07');
  }
  Read_8(){
    var x1 = [0x01, 0x10, 0x02, 0x08, 0x00, 0x1B, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'08');
  }
  Read_9(){
    var x1 = [0x01, 0x10, 0x02, 0x09, 0x00, 0x1C, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'09');
  }
  Read_10(){
    var x1 = [0x01, 0x10, 0x02, 0x0A, 0x00, 0x1D, 0x02];
    _sendModbusRequest(Uint8List.fromList(x1),'0A');
  }

  Tool_Sopt(String mang) async {
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
      int S = 0;
      for (int hex = 0; hex < Response.length - 2; hex++) {
        int hexValue = int.parse(Response[hex], radix: 16);
        S += hexValue;
      }
      while(int.parse(S.toRadixString(16), radix: 16) > int.parse('FF', radix: 16)){
        S = S - 256;
      }
      String sum = S.toRadixString(16);
      print("Data: $write_data");
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
                hex22 = '01222E${mang}00${byte3}1400';
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
                  print("Vi tri thu: $byte3");
                  hex22 = '01222E${mang}00${byte3}${(write_data.length)%n}00';
                  print("Dư $hex22");
                  List<String> hexList22 = [];

                  for (int number = (((write_data.length)/n).toInt()*n); number < write_data.length; number++) {
                    String hex = number.toRadixString(16).padLeft(4, '0');
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
                  print("Ban tin 2: $Bantin");
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

              hex22 = '01222E${mang}00${byte3}${((write_data.length)%n).toRadixString(16).padLeft(2, '0')}00';
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
              print("Ban tin 2: $Bantin");
              List<int> intList = Bantin22.map((hex) => int.parse(hex, radix: 16)).toList();
              print("Bantin :$intList");

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
  Write_1(){
    Tool_Sopt('01');
  }
  Write_2(){
    Tool_Sopt('02');
  }
  Write_3(){
    Tool_Sopt('03');
  }
  Write_4(){
    Tool_Sopt('04');
  }
  Write_5(){
    Tool_Sopt('05');
  }
  Write_6(){
    Tool_Sopt('06');
  }
  Write_7(){
    Tool_Sopt('07');
  }
  Write_8(){
    Tool_Sopt('08');
  }
  Write_9(){
    Tool_Sopt('09');
  }
  Write_10(){
    Tool_Sopt('0A');
  }


  @override
  Widget build(BuildContext context) {

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
              height: 40,
              decoration: BoxDecoration(
                  color: Colors.white
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                  ),

                  PopupMenuButton(
                      child: Container(
                          child: Text(
                            "File",
                            style: TextStyle(
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
                          var save = (data_save.toString()).substring(1,(data_save.toString().length)-1);
                          print("Gia tr luu dc là: $save");
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
                  SizedBox(
                  ),
                  Container(
                    height: 300,
                    width: 100,
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
                  Container(
                    height: 300,
                    width: 100,
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
                        });
                        //print('Selected COM Port: $newValue');
                      },
                    ),),
                  SizedBox(
                  ),
                ],
              ),
            ),
            SizedBox(
            ),
            Container(
              height: 40,
              width: 1200,
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
                          print("Start");
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
                        onPressed: () {},
                        child: Text(
                          "All",
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
                            read_or_write = 'read';
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
                            read_or_write = 'write';
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
            read_or_write == 'read' ? Container(
              height: 200,
              width: 700,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black12
              ),
              child: Column(
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
            ) : SizedBox(),
            read_or_write == 'write' ? Container(
              height: 200,
              width: 700,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black12
              ),
              child: Column(
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
            ) : SizedBox(),


            SizedBox(
            ),
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
                child: Text(
                    "Log"
                )
            ),
            SizedBox(
            ),
          ],
        ),
      ),
    );
  }
}