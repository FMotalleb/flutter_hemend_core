import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../debug/developer_tools.dart';
import '../object_controllers/data_snap_handler/data_snap_handler.dart' as snap;
import '../task_manager/isolate_manager/isolation_core.dart';

class CrashHandler {
  static CrashHandler get instance => _instance;
  static late CrashHandler _instance;
  static int crashCounter = 0;
  final Uri _reportUri;
  final Map<String, String>? _reportHeaders;
  final Map<String, dynamic>? _extraInfo;
  final void Function(Object, StackTrace)? _onCrash;
  Map<String, dynamic> _deviceInfo = <String, dynamic>{
    'error': 'have not been initialized',
  };
  Map<String, dynamic> _appInfo = <String, dynamic>{
    'error': 'have not been initialized',
  };

  CrashHandler.register(
    this._reportUri, {
    void Function(Object, StackTrace)? onCrash,
    Map<String, String>? reportHeaders,
    Map<String, dynamic>? extraInfo,
  })  : _extraInfo = extraInfo,
        _onCrash = onCrash,
        _reportHeaders = reportHeaders {
    _instance = this;
  }
  Future<void> gatherBasicData() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      _deviceInfo = (await deviceInfo.androidInfo).toMap();
    } else if (Platform.isIOS) {
      _deviceInfo = (await deviceInfo.iosInfo).toMap();
    }
    final packageInfo = await PackageInfo.fromPlatform();
    _appInfo = {
      'appName': packageInfo.appName,
      'version': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'packageName': packageInfo.packageName,
      'signingKey': packageInfo.buildSignature,
    };
  }

  ///return result of a function in a try-catch block and return the result
  FutureOr<snap.DataSnapHandler<TResult>> call<TResult>(
    FutureOr<TResult> Function() function,
  ) async {
    try {
      final result = await function();
      return snap.DataSnapHandler<TResult>.done(data: result);
    } catch (ex, st) {
      (_onCrash ?? (_, __) {})(ex, st);

      final crashTime = DateTime.now().millisecondsSinceEpoch;

      final params = PostRequestParams(
        _reportUri,
        _reportHeaders,
        {
          'data': jsonEncode(
            {
              'packageInfo': _appInfo,
              'deviceInfo': _deviceInfo,
              'errorTime': crashTime,
              'exception': ex.toString(),
              'stacktrace': st.toString(),
              'crashIndex': (crashCounter++).toString(),
              'extraInfo': _extraInfo ?? 'none',
            },
          )
        },
        null,
      );
      IsolationCore.createIsolateForSingleTask<void>(
        task: onlineReport,
        taskParams: params,
        debugName: 'crash_report_$crashCounter',
      );

      return snap.DataSnapHandler<TResult>.error(
        exception: ex,
        sender: st,
      );
    }
  }

  static Future<void> onlineReport(dynamic input) async {
    final params = input as PostRequestParams;

    final result = await http.post(params.uri, body: params.body, headers: params.headers);
    result.body.printToConsole.runInDebugMode();
  }
}

class PostRequestParams {
  final Uri uri;
  final Map<String, String>? headers;
  final Map<String, dynamic>? body;
  final Map<String, dynamic>? params;
  const PostRequestParams(this.uri, this.headers, this.body, this.params);
}
