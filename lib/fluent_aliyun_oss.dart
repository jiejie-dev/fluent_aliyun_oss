import 'dart:async';

import 'package:fluent_object_storage/put_object_event_handler.dart';
import 'package:fluent_object_storage/put_object_request.dart';
import 'package:fluent_object_storage/put_object_result.dart';
import 'package:flutter/services.dart';

/// 阿里云OSS插件
class FluentAliyunOss {
  static MethodChannel _channel = const MethodChannel('fluent_aliyun_oss')
    ..setMethodCallHandler(_methodHandler);

  static Map<String, ObjectStoragePutObjectEventHandler> _handlers = {};

  static final StreamController<ObjectStoragePutObjectResult>
      _streamController =
      new StreamController<ObjectStoragePutObjectResult>.broadcast()
        ..stream.listen((event) {
          final handler = _handlers[event.taskId];
          if (handler != null) {
            handler.dispatch(event);
            if (event.isFinished) _handlers.remove(event.taskId);
          }
        });

  /// 简单文件上传
  Future<ObjectStoragePutObjectEventHandler> putObject(
      ObjectStoragePutObjectRequest putObjectRequest) async {
    String taskId =
        await _channel.invokeMethod("putObject", putObjectRequest.toMap());
    final ObjectStoragePutObjectEventHandler handler =
        new ObjectStoragePutObjectEventHandler(taskId: taskId);
    _handlers[taskId] = handler;
    return handler;
  }

  static Future _methodHandler(MethodCall call) {
    final result = call.arguments;
    final taskId = result['taskId'];
    switch (call.method) {
      case 'onProgress':
        _streamController.sink.add(new ObjectStoragePutObjectResult(
            taskId: taskId,
            currentSize: result['currentSize'],
            totalSize: result['totalSize']));
        break;
      case 'onSuccess':
        _streamController.sink.add(new ObjectStoragePutObjectResult(
            taskId: taskId, url: result['url']));
        break;
      case 'onFailure':
        _streamController.sink.add(new ObjectStoragePutObjectResult(
            taskId: taskId, errorMessage: result['errorMessage']));
    }
    return Future.value();
  }

  /// 签名URL
  // Future<String> signUrl(
  //   String bucketName,
  //   String objectKey, {
  //   int expiredTimeInSeconds = 3600,
  // }) async {
  //   return await _channel.invokeMethod("signUrl", {
  //     "bucketName": bucketName,
  //     "objectKey": objectKey,
  //     "expiredTimeInSeconds": expiredTimeInSeconds,
  //     "clientKey": _clientKey
  //   });
  // }

  void dispose() {
    _streamController.close();
    _handlers.clear();
  }
}
