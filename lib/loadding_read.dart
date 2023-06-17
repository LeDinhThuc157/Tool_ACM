import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:newapp/savefile.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

class NotificationDialogRead extends StatefulWidget {
  String selectedBaud;
  String selectedComLabel;
  List<int> data_save1;
  String filePath;
  NotificationDialogRead({Key ?key,
    required this.selectedBaud,required this.selectedComLabel, required this.data_save1,required this.filePath
  }) : super(key: key);
  @override
  _NotificationDialogReadState createState() => _NotificationDialogReadState();
}

class _NotificationDialogReadState extends State<NotificationDialogRead> {
  List<int> data_save = [];

  @override
  void initState() {
    super.initState();
    All_Read();
  }
  Future _sendAll2(Uint8List request, String mang, String lan)async{
    data_save = widget.data_save1;
    String filePathSave = widget.filePath;
    final port = SerialPort(
        "${widget.selectedComLabel}",
        BaudRate: int.parse(widget.selectedBaud!),
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
        int intValue = 0;
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
        try{
          await completer.future.then((data) async {
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
                          }
                          else{
                            check_read = false;
                            Error_Read ='Mảng $lan: Checksum sai';
                            return;
                          }

                        }
                        else{
                          check_read = false;
                          Error_Read = 'Mảng $lan: Tin tức sai cú pháp';
                          return;
                        }
                      }).catchError((error) {
                        check_read = false;
                        Error_Read = 'Mảng $lan: $error';
                        return;
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
                                replaceArrayInFile(filePathSave,'Mang${lan.toString()}',data_save);
                              }
                              else{
                                check_read = false;
                                Error_Read = 'Mảng $lan: Độ dài mảng thu được không đúng';
                                return;
                              }
                            }
                            else{
                              check_read = false;
                              Error_Read = 'Mảng $lan: Checksum sai';
                              return;
                            }

                          }else{
                            check_read = false;
                            Error_Read = 'Mảng $lan: Tin tức sai cú pháp';
                            return;
                          }
                        }).catchError((error) {
                          // Xử lý lỗi từ Completer
                          check_read = false;
                          Error_Read = 'Mảng $lan: $error';
                        });
                      }finally {
                        completer1 = Completer<List<int>>();
                        timeoutTimer.cancel();
                      }


                    }


                  }
                  if(intValue%n == 0){
                    if(intValue == data_save.length){
                      replaceArrayInFile(filePathSave,'Mang${lan.toString()}',data_save);
                    }else{
                      check_read = false;
                      Error_Read = 'Mảng $lan: Độ dài mảng thu về không đúng';
                      return;
                    }

                  }
                }
                else{
                  if(intValue == 0){
                    BantinRong.add(lan);
                    return;
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
                              int decimal = int.parse(mang, radix: 16);
                              replaceArrayInFile(filePathSave,'Mang${lan.toString()}',data_save);
                            }
                            else{
                              check_read = false;
                              Error_Read = 'Mảng $lan: Độ dài mảng thu về không đúng';
                              return;
                            }
                          }
                          else{
                            check_read = false;
                            Error_Read = 'Mảng $lan: Checksum sai';
                            return;
                          }

                        }
                        else{
                          check_read = false;
                          Error_Read = 'Mảng $lan: Tin tức sai cú pháp';
                          return;
                        }
                      }).catchError((error) {
                        check_read = false;
                        // Xử lý lỗi từ Completer
                        Error_Read = 'Mảng $lan: $error';
                        return;
                      });
                    }finally {
                      completer1 = Completer<List<int>>();
                      timeoutTimer.cancel();
                    }
                  }

                }
              }
              else{
                check_read = false;
                Error_Read = 'Mảng $lan: Checksum sai';
                return;
              }
            }
            else{
              check_read = false;
              Error_Read = 'Mảng $lan: Bản tin sai cú pháp';
              return;
            }
          }).catchError((error) {
            // Xử lý lỗi từ Completer
            check_read = false;
            Error_Read = 'Mảng $lan: $error';
            return;
          });
        }catch(e){

        }

      }
      else {
        check_read = false;
        Error_Read = 'Chưa kết nối!';
        print('Serial port is not open');
        return;

      }

    } catch (e) {
      print('Error: $e');
    }
  }
  var BantinRong = [];
  String Error_Read = '';

  bool check_read = true;
  double sttread = 0;
  Future<void> All_Read() async {
    check_read = true;
    Error_Read  = '';
    BantinRong = [];
    for(int i = 1; i <= 40; i++){
      check_read = true;
      setState(() {
        sttread = (i*2.5);
        print(sttread);
      });
      String _hex = i.toRadixString(16).padLeft(2, '0');
      String hex_read = '011002${_hex}00';
      int S = 0;
      List<String> hex10List = [];

      print("Start ");
      try{
        for (int i = 0; i < hex_read.length; i += 2) {
          String hexValue = hex_read.substring(i, i + 2);
          hex10List.add(hexValue);
        }
      }catch(e){
        print(e);
      }
      print("Ban tin hex10List: $hex10List");

      for (var hex in hex10List) {
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
      var hex_10 = hex_read+'${sum}02';
      List<String> Bantin = [];

      for (int i = 0; i < hex_10.length; i += 2) {
        String hexValue = hex_10.substring(i, i + 2);
        Bantin.add(hexValue);
      }
      print("Ban tin 2: $Bantin");
      List<int> intList = Bantin.map((hex) => int.parse(hex, radix: 16)).toList();

      print("Bản tin gửi đi là: $Bantin");
      await _sendAll2(Uint8List.fromList(intList),_hex,i.toString());
      if(check_read == false){
        print("Thoái");
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thông báo'),
              content: Text('Error: ${Error_Read}'),
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
    Navigator.of(context).pop();
    if(BantinRong!= []){
      print("Banr tin rong: $BantinRong");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Thông báo'),
            content: Text('Các mảng rỗng là: $BantinRong'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 15,),
            Text('Loading... $sttread%')
          ],
        ),
      ),
    );
  }
}
