import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';

class NotesChangeNotifier extends ChangeNotifier {
  void updateNotes() {
    notifyListeners();
  }
}

NotesChangeNotifier notesChangeNotifier = NotesChangeNotifier();

class IsolateHandler {

  Future<void> start() async {
    late final ReceivePort mainReceivePort;
    late final SendPort mainSendPort;
    late final ReceivePort intermediateReceivePort;
    late final SendPort intermediateSendPort;
    late final SendPort isolateSendPort;
    late final RootIsolateToken rootIsolateToken;

    mainReceivePort = ReceivePort();
    mainSendPort = mainReceivePort.sendPort;
    intermediateReceivePort = ReceivePort();
    intermediateSendPort = intermediateReceivePort.sendPort;
    rootIsolateToken = RootIsolateToken.instance!;

    final isolateData = {
      'intermediateSendPort': intermediateSendPort,
      'rootIsolateToken': rootIsolateToken,
    };
    await Isolate.spawn(_intermediateIsolate, isolateData);

    intermediateReceivePort.listen((message) {
      if(message is SendPort) {
        isolateSendPort = message;
        main(mainReceivePort, isolateSendPort);
        return;
      }
      mainSendPort.send(message);
    });
  }

  void main(ReceivePort mainReceivePort, SendPort isolateSendPort) {}

  Future<void> _intermediateIsolate(isolateData) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(isolateData["rootIsolateToken"]);
    SendPort intermediateSendPort = isolateData["intermediateSendPort"];
    ReceivePort isolateReceivePort = ReceivePort();
    intermediateSendPort.send(isolateReceivePort.sendPort);
    isolate(isolateReceivePort, intermediateSendPort);
  }

  Future<void> isolate(ReceivePort isolateReceivePort, SendPort mainSendPort) async {}

}