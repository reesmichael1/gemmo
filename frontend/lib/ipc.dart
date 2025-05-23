import 'dart:convert';
import 'dart:io';

import 'gemtext.dart';

bool _inRange(num source, num low, num high) {
  return source >= low && source <= high;
}

Future<Socket> openSocket() async {
  final address = InternetAddress(
    '/run/user/1000/gemino.sock',
    type: InternetAddressType.unix,
  );

  return await Socket.connect(address, 0);
}

void sendInput(
  String input,
  String url,
  void Function(ServerResponse) callback,
) async {
  final socket = await openSocket();
  socket.listen((data) {
    final json = utf8.decode(data).trim();
    final response = ServerResponse.fromJson(jsonDecode(json));
    callback(response);
  });

  final msg = _UserInputMsg(contents: input, url: url);
  String json = jsonEncode(msg);
  socket.writeln(json);
}

class _UserInputMsg {
  const _UserInputMsg({required this.contents, required this.url});

  final String contents;
  final String url;

  Map<String, dynamic> toJson() => {
    'userInput': {'url': url, 'input': contents},
  };
}

urlSubmit(String url, void Function(ServerResponse) callback) async {
  final socket = await openSocket();
  socket.listen((data) {
    final json = utf8.decode(data);
    final response = ServerResponse.fromJson(jsonDecode(json));
    callback(response);
  });

  final msg = LoadUrlMsg(url);
  String json = jsonEncode(msg);
  socket.writeln(json);
}

linkClick(
  String url,
  String path,
  void Function(ServerResponse) callback,
) async {
  final socket = await openSocket();
  socket.listen((data) {
    final json = utf8.decode(data);
    final response = ServerResponse.fromJson(jsonDecode(json));
    callback(response);
  });

  final msg = _LinkClickMsg(url: url, path: path);
  String json = jsonEncode(msg);
  socket.writeln(json);
}

sealed class ServerResponse {
  const ServerResponse();

  factory ServerResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('error')) {
      return ErrorResponse.fromJson(json);
    } else if (json['status'] == 20) {
      return SuccessResponse.fromJson(json);
    } else if (_inRange(json['status'] as int, 10, 19)) {
      return InputResponse.fromJson(json);
    } else if (_inRange(json['status'] as int, 40, 44)) {
      return TempfailResponse.fromJson(json);
    } else if (_inRange(json['status'] as int, 50, 59)) {
      return PermfailResponse.fromJson(json);
    } else {
      throw Exception('unrecognized server response: $json');
    }
  }
}

enum ResponseKind { normal, sensitive }

ResponseKind _parseKind(String kind) {
  if (kind == 'normal') {
    return ResponseKind.normal;
  } else if (kind == 'sensitive') {
    return ResponseKind.sensitive;
  } else {
    throw Exception('unrecognized input kind');
  }
}

class InputResponse implements ServerResponse {
  final ResponseKind kind;
  final String prompt;
  final String url;

  InputResponse({required this.kind, required this.prompt, required this.url});

  factory InputResponse.fromJson(Map<String, dynamic> json) => InputResponse(
    kind: _parseKind(json['input']['kind']),
    prompt: json['input']['prompt'],
    url: json['input']['url'],
  );
}

class ErrorResponse implements ServerResponse {
  final String msg;

  ErrorResponse({required this.msg});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) =>
      ErrorResponse(msg: json['error']);
}

class SuccessResponse implements ServerResponse {
  final String mime;
  final String url;
  final List<GemLine> lines;

  SuccessResponse({required this.mime, required this.lines, required this.url});

  factory SuccessResponse.fromJson(Map<String, dynamic> json) {
    final lines =
        (json['lines'] as List).map((item) => GemLine.fromJson(item)).toList();

    return SuccessResponse(lines: lines, mime: json['mime'], url: json['url']);
  }
}

class TempfailResponse implements ServerResponse {
  final String msg;
  final int status;

  TempfailResponse({required this.msg, required this.status});

  factory TempfailResponse.fromJson(Map<String, dynamic> json) =>
      TempfailResponse(
        msg: json['tempfail']['msg'] ?? "",
        status: json['status'],
      );
}

class PermfailResponse implements ServerResponse {
  final String msg;
  final int status;

  PermfailResponse({required this.msg, required this.status});

  factory PermfailResponse.fromJson(Map<String, dynamic> json) =>
      PermfailResponse(
        msg: json['permfail']['msg'] ?? "",
        status: json['status'],
      );
}

class _LinkClickMsg {
  final String url;
  final String path;

  _LinkClickMsg({required this.url, required this.path});

  Map<String, dynamic> toJson() => {
    'linkClick': {'url': url, 'path': path},
  };
}

class LoadUrlMsg {
  final String url;

  LoadUrlMsg(this.url);

  LoadUrlMsg.fromJson(Map<String, dynamic> json)
    : url = json['loadUrl']['url'] as String;

  Map<String, dynamic> toJson() => {
    'loadUrl': {'url': url},
  };
}

class AppExitMsg {
  AppExitMsg();

  String toJson() => 'appExit';
}
