import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:exnote/services/indexing/scan_request_retry.dart';

void main() {
  test(
    'DNS interruptions and overloaded providers recover without failing the scan',
    () async {
      int calls = 0;
      final retry = ScanRequestRetry(wait: (_) async {});
      final result = await retry.send(() async {
        calls++;
        if (calls == 1) throw http.ClientException('Failed host lookup');
        if (calls == 2) return http.Response('overloaded', 503);
        return http.Response('ready', 200);
      }, cancelled: () => false);
      expect(calls, 3);
      expect(result.body, 'ready');
    },
  );
  test('rate limits honor Retry-After', () async {
    int calls = 0;
    Duration waited = Duration.zero;
    final retry = ScanRequestRetry(
      wait: (duration) async {
        waited += duration;
      },
    );
    await retry.send(() async {
      calls++;
      return http.Response(
        '',
        calls == 1 ? 429 : 200,
        headers: {'retry-after': '3'},
      );
    }, cancelled: () => false);
    expect(waited, const Duration(seconds: 3));
  });
  test('credentials and note-specific errors are not retried', () async {
    for (final status in [400, 401, 402, 403, 413, 422]) {
      int calls = 0;
      final result = await ScanRequestRetry(wait: (_) async {}).send(() async {
        calls++;
        return http.Response('', status);
      }, cancelled: () => false);
      expect(calls, 1);
      expect(result.statusCode, status);
    }
  });
  test(
    'persistent timeouts become a recoverable connectivity failure',
    () async {
      int calls = 0;
      await expectLater(
        ScanRequestRetry(wait: (_) async {}).send(() async {
          calls++;
          throw TimeoutException('timed out');
        }, cancelled: () => false),
        throwsA(isA<TransientScanException>()),
      );
      expect(calls, 4);
    },
  );
  test('pause during backoff prevents another network request', () async {
    bool cancelled = false;
    int calls = 0;
    await expectLater(
      ScanRequestRetry(wait: (_) async {}).send(
        () async {
          calls++;
          return http.Response('', 503);
        },
        cancelled: () => cancelled,
        onRetry: (_, __) => cancelled = true,
      ),
      throwsA(isA<TransientScanException>()),
    );
    expect(calls, 1);
  });
}
