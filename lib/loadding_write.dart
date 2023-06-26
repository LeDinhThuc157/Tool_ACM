import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:newapp/savefile.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

class NotificationDialogWrite extends StatefulWidget {
  String selectedBaud;
  String selectedComLabel;
  Map<String, List<int>> arrays;
  NotificationDialogWrite({Key ?key,
    required this.selectedBaud,required this.selectedComLabel, required this.arrays
  }) : super(key: key);
  @override
  _NotificationDialogWriteState createState() => _NotificationDialogWriteState();
}

class _NotificationDialogWriteState extends State<NotificationDialogWrite> {
  List<int> data_save = [];

  @override
  void initState() {
    super.initState();
    All_Write();
  }
  Tool_SoptAll(String mang, String lan) async {
    int  n = 10;
    List<int>? write_data = [];
    int decimal = int.parse(mang, radix: 16);
    write_data = widget.arrays['Mang$decimal'];
    if(write_data == null){
      print("Mang chua ton taij");
      return;
    }
    else{
      final port = SerialPort(
          "${widget.selectedComLabel}",
          BaudRate: int.parse(widget.selectedBaud!),
          openNow: false,
          ByteSize: 8,
          ReadIntervalTimeout: 1,
          ReadTotalTimeoutConstant: 2
      );

      if (port.isOpened) {
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
        for (int i = 0; i < hex20.length; i += 2) {
          String hexValue = hex20.substring(i, i + 2);
          hex20List.add(hexValue);
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
        const timeoutDuration = Duration(seconds: 2);
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
        try{
          await completer.future.then((data) async {
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
                  const timeoutDuration = Duration(seconds: 2);
                  // Tạo một Completer để theo dõi khi nào nhận được dữ liệu
                  Completer<List<int>> completer1 = Completer<List<int>>();
                  // Tạo một Timer để hủy bỏ nếu không nhận được dữ liệu sau thời gian chờ
                  Timer timeoutTimer;
                  if((write_data!.length/n).toInt() > 0){
                    bool check_write_only = true;
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
                          print("xxx: $Response23");
                          if(Response23[0] == '01' && Response23[1] == '23' && Response23[6] == '02' && Response23[2] == '02'){
                            if(sum == Response23[5]){
                              if(Response23[3] == '01'){
                                check_write = true;
                              }
                              if(Response23[3] == '00'){
                                check_write_only = false;
                                check_write = false;
                                Error_Write = 'Mảng $lan: Ghi không thành công';
                                return;
                              }
                            }else{
                              check_write_only = false;
                              check_write = false;
                              Error_Write = 'Mảng $lan: Checksum sai';
                              return;
                            }
                          }
                          else{
                            check_write_only = false;
                            check_write = false;
                            Error_Write = 'Mảng $lan: Bản tin sai cú pháp';
                            return;
                          }

                        }).catchError((error) {
                          check_write_only = false;
                          if(error == 'Timeout'){
                            check_write = false;
                            Error_Write = 'Mảng $lan: $error';
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
                            print("xxx: $Response23");
                            if(Response23[0] == '01' && Response23[1] == '23' && Response23[6] == '02' && Response23[2] == '02'){
                              if(sum == Response23[5]){
                                if(Response23[3] == '01'){
                                  check_write = true;
                                }
                                else{
                                  check_write_only = false;
                                  check_write = false;
                                  Error_Write = 'Mảng $lan: Ghi không thành công';
                                  return;
                                }
                                print("Response Hoàn thành");
                              }else{
                                check_write_only = false;
                                check_write = false;
                                Error_Write = 'Mảng $lan: Checksum sai';
                                return;
                              }
                            }
                            else{
                              check_write_only = false;
                              check_write = false;
                              Error_Write = 'Mảng $lan: Bản tin sai cú pháp';
                              return;
                            }

                          }).catchError((error) {
                            check_write_only = false;
                            check_write = false;
                            Error_Write = 'Mảng $lan: $error';
                            return;
                          });
                        }finally {
                          completer1 = Completer<List<int>>();
                          timeoutTimer.cancel();
                        }

                      }
                      if(check_write_only == false){
                        print("Đã gặp lỗi");
                        return;
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
                    var length_22 = (6 + (write_data.length)*2).toRadixString(16).padLeft(2,'0');
                    hex22 = '0122${length_22}${mang}00${byte3}${((write_data.length)%n).toRadixString(16).padLeft(2, '0')}00';
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
                        print("xxx: $List_hex");
                        if(List_hex[0] == '01' && List_hex[1] == '23' && List_hex[6] == '02' && List_hex[2] == '02'){
                          if(sum == List_hex[List_hex.length-2]){
                            if(List_hex[3] == '01'){
                              check_write = true;
                            }
                            else{
                              check_write = false;
                              Error_Write = 'Mảng $lan: Ghi không thành công';
                              return;
                            }
                            print("Response Hoàn thành");
                          }
                          else{
                            check_write = false;
                            Error_Write = 'Mảng $lan: Checksum Sai';
                            return;
                          }

                        }
                        else{
                          check_write = false;
                          Error_Write = 'Mảng $lan: Tin tức sai cú pháp';
                          return;
                        }
                      }).catchError((error) {
                        // Xử lý lỗi từ Completer
                        check_write = false;
                        Error_Write = 'Mảng $lan: $error';
                        return;
                      });
                    }finally {
                      completer1 = Completer<List<int>>();
                      timeoutTimer.cancel();
                    }
                  }

                }
                else{
                  check_write = false;
                  Error_Write = 'Mảng $lan: Over length';
                  return;
                }
              }
              else{

                check_write = false;
                Error_Write = 'Mảng $lan: Checksum sai';
                return;
              }

            }
            else{

              check_write = false;
              Error_Write = 'Mảng $lan: Bản tin sai cú pháp';
              return;
            }

          }).
          catchError((error) {
            // Xử lý lỗi từ Completer
            if(error == 'Timeout'){
              check_write = false;
              Error_Write = 'Mảng $lan: $error';
              return;
            }


          });
        }catch(e){

        }
      }
      else {
        check_write = false;
        Error_Write = 'Chưa kết nối!';
        print('Serial port is not open');
        return;

      }
    }

  }
  String Error_Write = '';
  bool check_write = true;
  double sttwrite = 0;
  Future<void> All_Write() async{
    check_write = true;
    Error_Write = '';
    for(int i = 1; i <= 40; i++){
      setState(() {
        sttwrite = (i*2.5);
        print(sttwrite);
      });
      check_write = true;
      String _hex = i.toRadixString(16).padLeft(2, '0');
      await Tool_SoptAll(_hex,i.toString());
      if(check_write == false){
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Thông báo'),
              content: Text('Error: $Error_Write'),
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
    if(check_write = true){
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Thông báo'),
            content: Text('Ghi thành công!'),
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
            Text('Loading... $sttwrite%')
          ],
        ),
      ),
    );
  }
}
