import 'package:flutter_test/flutter_test.dart';
import 'package:firefox_vpn/core/core_api.dart';
import 'package:firefox_vpn/core/core_controller.dart';
import 'package:firefox_vpn/core/models.dart';

/// A core whose next [failNext] reads fail as if the connection dropped.
class _FlakyApi implements CoreApi {
  int failNext = 0;

  @override
  Future<CoreStatus> status() async {
    if (failNext > 0) {
      failNext--;
      throw const CoreUnavailable(CoreProblem.notAnswering, 'connection reset');
    }
    return CoreStatus.fromJson({
      'state': {'phase': 'off', 'message': 'Proxy off'},
    });
  }

  @override
  Future<AccountList> accounts() async => AccountList.fromJson({});

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A running core whose auto-connect tests the connection; it counts the
/// app's own tests.
class _AutoConnectingApi implements CoreApi {
  int tests = 0;
  bool autoConnecting = true;

  @override
  Future<CoreStatus> status() async => CoreStatus.fromJson({
    'state': {'phase': 'running', 'message': 'Proxy running'},
    'system_proxy': 'set',
    'system_proxy_supported': true,
    'auto_connecting': autoConnecting,
  });

  @override
  Future<ConnectionTest> test() async {
    tests++;
    return ConnectionTest.fromJson({'ok': false});
  }

  @override
  Future<AccountList> accounts() async => AccountList.fromJson({});

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A core with a standing, confirmed connection: its status carries a
/// test the test case ages as it pleases; [test] counts the app's own
/// tests and answers with a fresh passing one.
class _ConfirmedApi implements CoreApi {
  int tests = 0;

  /// The `at` of the status's last test, as an ISO string.
  String testAt = DateTime.now()
      .subtract(const Duration(seconds: 2))
      .toIso8601String();

  @override
  Future<CoreStatus> status() async => CoreStatus.fromJson({
    'state': {'phase': 'running', 'message': 'Proxy running'},
    'system_proxy': 'set',
    'system_proxy_supported': true,
    'proxy': {
      'started_at': DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toIso8601String(),
    },
    'last_test': {'at': testAt, 'ok': true, 'response_ms': 99},
  });

  @override
  Future<ConnectionTest> test() async {
    tests++;
    return ConnectionTest.fromJson({
      'at': DateTime.now().toIso8601String(),
      'ok': true,
      'response_ms': 99,
    });
  }

  @override
  Future<AccountList> accounts() async => AccountList.fromJson({});

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // A standing, confirmed connection is measured at connect time and
  // when the user asks (a tap on the ping), never on a timer: the
  // controller adds no tests of its own however old the last one gets.
  test('a confirmed connection is not re-tested as its test ages', () async {
    final api = _ConfirmedApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
    );
    await core.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.tests, 0, reason: 'a fresh confirming test is kept');

    api.testAt = DateTime.now()
        .subtract(const Duration(seconds: 30))
        .toIso8601String();
    await core.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.tests, 0, reason: 'no periodic re-test, however old');
    expect(core.lastTest?.responseMs, 99);

    await core.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.tests, 0, reason: 'still none on later polls');
    core.dispose();
  });

  // The core's auto-connect tests by itself; the app adds none meanwhile.
  test('no tests of its own while the core auto-connects', () async {
    final api = _AutoConnectingApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
    );
    await core.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(core.status?.autoConnecting, isTrue);
    expect(api.tests, 0);

    api.autoConnecting = false;
    await core.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.tests, 1, reason: 'unconfirmed once auto-connect is over');
    core.dispose();
  });

  // Android closes the app's connections when the phone's network goes
  // away; one failed read must not show the core as lost.
  test('one failed read is retried before the core counts as lost', () async {
    final api = _FlakyApi();
    final core = CoreController(
      () async => api,
      pollInterval: const Duration(hours: 1),
    );
    await core.refresh();
    expect(core.unavailable, isNull);

    api.failNext = 1;
    await core.refresh();
    expect(core.unavailable, isNull, reason: 'a single failure is retried');
    await core.refresh();
    expect(core.unavailable, isNull);

    api.failNext = 2;
    await core.refresh();
    await core.refresh();
    expect(core.unavailable?.problem, CoreProblem.notAnswering);
    await core.refresh();
    expect(core.unavailable, isNull, reason: 'it answers again');
    core.dispose();
  });
}
