import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arman_vpn/core/android_core.dart';
import 'package:arman_vpn/core/core_api.dart';

class _LoopbackHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app/android');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'connects to the native API address with this profile’s token',
    () async {
      final dir = await Directory.systemTemp.createTemp('android-core-test');
      addTearDown(() => dir.delete(recursive: true));
      final sep = Platform.pathSeparator;
      await File('${dir.path}$sep${CoreLocator.tokenFile}')
          .writeAsString('test-profile-token');
      await File('${dir.path}$sep${CoreLocator.configFile}')
          .writeAsString('{"dashboard":{"listen":"127.0.0.1:1"}}');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      String? token;
      server.listen((request) async {
        token = request.headers.value('X-Local-Token');
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"state":{"phase":"off"}}');
        await request.response.close();
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        return switch (call.method) {
          'isRunning' => true,
          'dashboardAddress' => '127.0.0.1:${server.port}',
          _ => fail('Unexpected platform call: ${call.method}'),
        };
      });
      final api = await HttpOverrides.runWithHttpOverrides(
        () => AndroidCore(dir.path).connect(),
        _LoopbackHttpOverrides(),
      );
      addTearDown(api.close);
      expect(token, 'test-profile-token');
    },
  );

  test('surfaces a native startup failure instead of waiting for the API', () {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'isRunning' => false,
        'startCore' => 'cannot write local API token',
        _ => fail('Unexpected platform call: ${call.method}'),
      };
    });
    return expectLater(
      AndroidCore('').connect(),
      throwsA(
        isA<CoreUnavailable>()
            .having((e) => e.problem, 'problem', CoreProblem.exited)
            .having((e) => e.detail, 'detail', 'cannot write local API token'),
      ),
    );
  });
}
