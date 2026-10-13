import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

class TransientScanException implements Exception {
  final String message;
  const TransientScanException(this.message);
  @override
  String toString() => message;
}

/// Retries temporary transport/provider failures without conflating them with
/// credentials, malformed input, or an explicit user cancellation.
class ScanRequestRetry {
  final int attempts;
  final Future<void> Function(Duration) wait;
  ScanRequestRetry({this.attempts = 4, Future<void> Function(Duration)? wait})
    : wait = wait ?? Future<void>.delayed;

  static bool isTemporaryStatus(int status) =>
      status == 408 || status == 429 || status >= 500;

  Future<http.Response> send(
    Future<http.Response> Function() request, {
    required bool Function() cancelled,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    Object? lastError;
    for (int attempt = 1; attempt <= attempts; attempt++) {
      if (cancelled()) throw const TransientScanException('Request cancelled');
      Duration delay = Duration(seconds: 1 << attempt);
      try {
        final response = await request();
        if (!isTemporaryStatus(response.statusCode)) return response;
        lastError =
            'OpenRouter temporarily unavailable (${response.statusCode})';
        final retryAfter = response.headers['retry-after'];
        final seconds = int.tryParse(retryAfter ?? '');
        if (seconds != null && seconds >= 0) {
          delay = Duration(seconds: seconds);
        } else if (retryAfter != null) {
          try {
            final until = HttpDate.parse(
              retryAfter,
            ).difference(DateTime.now().toUtc());
            if (!until.isNegative) delay = until;
          } on FormatException {
            /* Use exponential backoff for an invalid header. */
          }
        }
      } on TimeoutException {
        lastError = 'The page request timed out';
      } on http.ClientException {
        lastError = 'The connection to OpenRouter was interrupted';
      } on SocketException {
        lastError = 'Could not connect to OpenRouter';
      }
      if (cancelled()) throw const TransientScanException('Request cancelled');
      if (attempt == attempts) break;
      onRetry?.call(attempt + 1, delay);
      // Short waits allow pausing a scan even when Retry-After is long.
      var remaining = delay;
      while (remaining > Duration.zero) {
        if (cancelled()) {
          throw const TransientScanException('Request cancelled');
        }
        final step = remaining > const Duration(milliseconds: 250)
            ? const Duration(milliseconds: 250)
            : remaining;
        await wait(step);
        remaining -= step;
      }
    }
    throw TransientScanException(
      '$lastError after $attempts attempts. Resume or retry this note.',
    );
  }
}
