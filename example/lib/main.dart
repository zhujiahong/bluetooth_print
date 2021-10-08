import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  BluetoothPrint bluetoothPrint = BluetoothPrint.instance;

  bool _connected = false;
  BluetoothDevice _device;
  Image convertedImage;
  String tips = 'no device connect';
  Uint8List imageUtf;
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => initBluetooth());
    imageInit();
  }

  imageInit() async {
    Widget widget = await createWidget();
    imageUtf = await widgetToImage(widget);
    setState(() {
      convertedImage = Image.memory(imageUtf);
    });
  }

  Future<Widget> createWidget() async {
    /// asset
    // AssetImage provider = AssetImage('assets/images/1.png');

    /// network
    // NetworkImage provider = NetworkImage('https://upload-images.jianshu.io/upload_images/1940075-56c284948fc4f9de.png');

    /// file
    // FileImage provider = FileImage(File((await getApplicationDocumentsDirectory()).path + '/1.png'));

    // await precacheImage(provider, context);
    // Image image = Image(image: provider);
    return Future(() {
      return Container(
          height: 600,
          width: 800,
          color: Colors.white,
          child: Text(
            'data aaaaaaaaaa',
            style: TextStyle(color: Colors.black, fontSize: 50),
          ));
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initBluetooth() async {
    bluetoothPrint.startScan(timeout: Duration(seconds: 4));

    bool isConnected = await bluetoothPrint.isConnected;

    bluetoothPrint.state.listen((state) {
      print('cur device status: $state');

      switch (state) {
        case BluetoothPrint.CONNECTED:
          setState(() {
            _connected = true;
            tips = 'connect success';
          });
          break;
        case BluetoothPrint.DISCONNECTED:
          setState(() {
            _connected = false;
            tips = 'disconnect success';
          });
          break;
        default:
          break;
      }
    });

    if (!mounted) return;

    if (isConnected) {
      setState(() {
        _connected = true;
      });
    }
  }

  Widget widgetToConvert;
  Future<Uint8List> widgetToImage(Widget widget) async {
    GlobalKey key = GlobalKey(); // 1.通过 key 来获取 BuildContext 从而获取 RenderObject
    Completer completer =
        Completer<Uint8List>(); // 2.因为要等待回调之后才能返回，所以需要使用到 Completer

    setState(() {
      widgetToConvert = RepaintBoundary(
          key: key,
          child: widget); // 3.将需要转换为图片的 widget 显示出来，才能获取到 BuildContext
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // 4.此时如果立刻执行下面的代码，是获取不到 BuildContext，因为 widget 还没有完成绘制
      // 所以需要等待这一帧绘制完成后，才能开始转换图片
      if (key.currentContext?.findRenderObject() != null) {
        RenderRepaintBoundary render = key.currentContext.findRenderObject();
        ui.Image image = await render.toImage();
        ByteData byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        completer.complete(byteData.buffer.asUint8List());
      }

      setState(() {
        widgetToConvert = null; // 5.图片已经绘制完成，不需要显示该 widget 了
      });
    });

    // 6.返回数据，使用 Completer 可以实现返回和回调数据相关的 Future
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('BluetoothPrint example app'),
        ),
        body: Stack(
          children: [
            Center(child: widgetToConvert ?? Container()),
            Positioned.fill(
                child: RefreshIndicator(
              onRefresh: () =>
                  bluetoothPrint.startScan(timeout: Duration(seconds: 4)),
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                      ),
                      child: convertedImage ?? Container(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 10),
                          child: Text(tips),
                        ),
                      ],
                    ),
                    Divider(),
                    StreamBuilder<List<BluetoothDevice>>(
                      stream: bluetoothPrint.scanResults,
                      initialData: [],
                      builder: (c, snapshot) => Column(
                        children: snapshot.data
                            .map((d) => ListTile(
                                  title: Text(d.name ?? ''),
                                  subtitle: Text(d.address),
                                  onTap: () async {
                                    setState(() {
                                      _device = d;
                                    });
                                  },
                                  trailing: _device != null &&
                                          _device.address == d.address
                                      ? Icon(
                                          Icons.check,
                                          color: Colors.green,
                                        )
                                      : null,
                                ))
                            .toList(),
                      ),
                    ),
                    Divider(),
                    Container(
                      padding: EdgeInsets.fromLTRB(20, 5, 20, 10),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              OutlinedButton(
                                child: Text('connect'),
                                onPressed: _connected
                                    ? null
                                    : () async {
                                        if (_device != null &&
                                            _device.address != null) {
                                          await bluetoothPrint.connect(_device);
                                        } else {
                                          setState(() {
                                            tips = 'please select device';
                                          });
                                          print('please select device');
                                        }
                                      },
                              ),
                              SizedBox(width: 10.0),
                              OutlinedButton(
                                child: Text('disconnect'),
                                onPressed: _connected
                                    ? () async {
                                        await bluetoothPrint.disconnect();
                                      }
                                    : null,
                              ),
                            ],
                          ),
                          OutlinedButton(
                            child: Text('print receipt(esc)'),
                            onPressed: _connected
                                ? () async {
                                    Map<String, dynamic> config = Map();

                                    // x、y坐标位置，单位dpi，1mm=8dpi

                                    List<LineText> list = [];

                                    ByteData data = await rootBundle
                                        .load("assets/images/123.png");
                                    List<int> imageBytes = data.buffer
                                        .asUint8List(data.offsetInBytes,
                                            data.lengthInBytes);
                                    String base64Image =
                                        base64Encode(imageBytes);
                                    list.add(LineText(
                                      type: LineText.TYPE_IMAGE,
                                      x: 10,
                                      y: 10,
                                      content: base64Image,
                                    ));

                                    // list.add(LineText(
                                    //     type: LineText.TYPE_QRCODE,
                                    //     content: 'sadfafasfasfa',
                                    //     align: LineText.ALIGN_LEFT,
                                    //     weight: 1,
                                    //     linefeed: 0));

                                    // list.add(LineText(
                                    //     type: LineText.TYPE_TEXT,
                                    //     content:
                                    //         'sadfafasfasfa  defweferfwefer  frefreferferfer  freferfer',
                                    //     align: LineText.ALIGN_RIGHT,
                                    //     weight: 1,
                                    //     linefeed: 1));
                                    // list.add(LineText(
                                    //     type: LineText.TYPE_TEXT,
                                    //     content: 'Cod.' + '156462',
                                    //     weight: 0,
                                    //     align: LineText.ALIGN_LEFT,
                                    //     linefeed: 1));
                                    // list.add(LineText(
                                    //     type: LineText.TYPE_TEXT,
                                    //     width: 1,
                                    //     height: 1,
                                    //     size: 1,
                                    //     content: 'M:' +
                                    //         StringSpliteUtil.getMoneyStyleStr(
                                    //             '5660') +
                                    //         ' ',
                                    //     align: LineText.ALIGN_LEFT,
                                    //     linefeed: 1));
                                    // list.add(LineText(
                                    //     type: LineText.TYPE_TEXT,
                                    //     width: 1,
                                    //     height: 1,
                                    //     size: 1,
                                    //     content: 'D:' +
                                    //         StringSpliteUtil.getMoneyStyleStr(
                                    //             '88500'),
                                    //     align: LineText.ALIGN_LEFT,
                                    //     linefeed: 1));

                                    // // list.add(LineText(linefeed: 1));
                                    // list.add(LineText(
                                    //   type: LineText.TYPE_BARCODE,
                                    //   content: '7877770601682',
                                    //   align: LineText.ALIGN_CENTER,
                                    //   size: 1,
                                    // ));

                                    await bluetoothPrint.printReceipt(
                                        config, list);
                                  }
                                : null,
                          ),
                          OutlinedButton(
                            child: Text('print label(tsc)'),
                            onPressed: _connected
                                ? () async {
                                    Map<String, dynamic> config = Map();
                                    config['width'] = 40; // 标签宽度，单位mm
                                    config['height'] = 70; // 标签高度，单位mm
                                    config['gap'] = 2; // 标签间隔，单位mm

                                    // x、y坐标位置，单位dpi，1mm=8dpi
                                    List<LineText> list = [];
                                    list.add(LineText(
                                        type: LineText.TYPE_TEXT,
                                        x: 10,
                                        y: 10,
                                        content: 'A Title'));
                                    list.add(LineText(
                                        type: LineText.TYPE_TEXT,
                                        x: 10,
                                        y: 40,
                                        content: 'this is content'));
                                    list.add(LineText(
                                        type: LineText.TYPE_QRCODE,
                                        x: 10,
                                        y: 70,
                                        content: 'qrcode i\n'));
                                    list.add(LineText(
                                        type: LineText.TYPE_BARCODE,
                                        x: 10,
                                        y: 190,
                                        content: 'qrcode i\n'));

                                    List<LineText> list1 = [];
                                    ByteData data = await rootBundle
                                        .load("assets/images/guide3.png");
                                    List<int> imageBytes = data.buffer
                                        .asUint8List(data.offsetInBytes,
                                            data.lengthInBytes);
                                    String base64Image =
                                        base64Encode(imageBytes);
                                    list1.add(LineText(
                                      type: LineText.TYPE_IMAGE,
                                      x: 10,
                                      y: 10,
                                      content: base64Image,
                                    ));

                                    await bluetoothPrint.printLabel(
                                        config, list);
                                    await bluetoothPrint.printLabel(
                                        config, list1);
                                  }
                                : null,
                          ),
                          OutlinedButton(
                            child: Text('print selftest'),
                            onPressed: _connected
                                ? () async {
                                    await bluetoothPrint.printTest();
                                  }
                                : null,
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ))
          ],
        ),
        floatingActionButton: StreamBuilder<bool>(
          stream: bluetoothPrint.isScanning,
          initialData: false,
          builder: (c, snapshot) {
            if (snapshot.data) {
              return FloatingActionButton(
                child: Icon(Icons.stop),
                onPressed: () => bluetoothPrint.stopScan(),
                backgroundColor: Colors.red,
              );
            } else {
              return FloatingActionButton(
                  child: Icon(Icons.search),
                  onPressed: () =>
                      bluetoothPrint.startScan(timeout: Duration(seconds: 4)));
            }
          },
        ),
      ),
    );
  }
}

class StringSpliteUtil {
  //将字符串切割成金额样式  比如1000000转成1.000.000  或  200000转成200.000
  //也可以将所有的.替换成,   这样就是以,分隔 比如1,000,000或者200,000
  // ignore: missing_return
  static String getMoneyStyleStr(String text) {
    try {
      if (text == null || text.isEmpty) {
        return "";
      } else {
        String temp = "";
        if (text.length <= 3) {
          temp = text;
          return temp;
        } else {
          int count = ((text.length) ~/ 3); //切割次数
          int startIndex = text.length % 3; //开始切割的位置
          if (startIndex != 0) {
            if (count == 1) {
              temp = text.substring(0, startIndex) +
                  "." +
                  text.substring(startIndex, text.length);
            } else {
              temp = text.substring(0, startIndex) + "."; //第一次切割0-startIndex
              int syCount = count - 1; //剩余切割次数
              for (int i = 0; i < syCount; i++) {
                temp += text.substring(
                        startIndex + 3 * i, startIndex + (i * 3) + 3) +
                    ".";
              }
              temp += text.substring(
                  (startIndex + (syCount - 1) * 3 + 3), text.length);
            }
          } else {
            for (int i = 0; i < count; i++) {
              if (i != count - 1) {
                temp += text.substring(3 * i, (i + 1) * 3) + ".";
              } else {
                temp += text.substring(3 * i, (i + 1) * 3);
              }
            }
          }
          return temp;
        }
      }
    } catch (e) {
      print(e);
    }
  }

  //将字符串按类似银行卡格式6210 xxxx xxxx xxxx xx的格式展示
  static getPayCodeStyleStr(String code) {
    int length = code.length;
    int count = length ~/ 4;
    int shengYu = length % 4;
    String result = '';
    if (length < 4) {
      return code;
    } else {
      for (int i = 0; i < count; i++) {
        String temp = code.substring(i * 4, (i + 1) * 4);
        result += temp + " ";
      }
      result += code.substring(length - shengYu, length);
      return result;
    }
  }
}
