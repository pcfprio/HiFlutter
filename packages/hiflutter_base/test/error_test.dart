import 'dart:async';

import 'package:hiflutter_base/hiflutter_base.dart';
import 'package:test/test.dart';

void main() {
  group('HiError categories', () {
    final cases = <(HiError, HiErrorKind, bool)>[
      (const HiNetworkError(), HiErrorKind.network, true),
      (const HiTimeoutError(), HiErrorKind.timeout, true),
      (const HiUnauthorizedError(), HiErrorKind.unauthorized, false),
      (const HiForbiddenError(), HiErrorKind.forbidden, false),
      (const HiNotFoundError(), HiErrorKind.notFound, false),
      (const HiServerError(statusCode: 503), HiErrorKind.server, true),
      (const HiDecodeError(), HiErrorKind.decode, false),
      (const HiCancelledError(), HiErrorKind.cancelled, false),
      (const HiStorageError(), HiErrorKind.storage, false),
      (const HiUnknownError(), HiErrorKind.unknown, false),
    ];

    for (final (error, kind, retryable) in cases) {
      test('${error.runtimeType} is $kind, retryable: $retryable', () {
        expect(error.kind, kind);
        expect(error.retryable, retryable);
      });
    }
  });

  group('HiError.retryable', () {
    test('server errors retry only for 5xx statuses', () {
      expect(const HiServerError(statusCode: 499).retryable, isFalse);
      expect(const HiServerError(statusCode: 500).retryable, isTrue);
      expect(const HiServerError(statusCode: 599).retryable, isTrue);
      expect(const HiServerError(statusCode: 600).retryable, isFalse);
      expect(const HiServerError(code: 'E1001').retryable, isFalse);
    });

    test('can be overridden per error', () {
      expect(const HiNetworkError(retryable: false).retryable, isFalse);
      expect(const HiUnknownError(retryable: true).retryable, isTrue);
    });
  });

  group('HiError.display', () {
    final cases = <(HiError, HiErrorDisplay)>[
      (const HiNetworkError(), HiErrorDisplay.network),
      (const HiTimeoutError(), HiErrorDisplay.timeout),
      (const HiUnauthorizedError(), HiErrorDisplay.unauthorized),
      (const HiForbiddenError(), HiErrorDisplay.forbidden),
      (const HiNotFoundError(), HiErrorDisplay.notFound),
      (const HiServerError(), HiErrorDisplay.server),
      (const HiDecodeError(), HiErrorDisplay.data),
      (const HiCancelledError(), HiErrorDisplay.none),
      (const HiStorageError(), HiErrorDisplay.generic),
      (const HiUnknownError(), HiErrorDisplay.generic),
    ];

    for (final (error, display) in cases) {
      test('${error.runtimeType} displays as $display', () {
        expect(error.display, display);
      });
    }
  });

  group('HiError diagnostics', () {
    test('keep the original cause as text', () {
      final error = HiNetworkError(
        message: 'offline',
        cause: StateError('socket closed'),
      );

      expect(error.diagnostics, contains('HiNetworkError'));
      expect(error.diagnostics, contains('offline'));
      expect(error.diagnostics, contains('socket closed'));
    });

    test('describe server status and business code', () {
      const error = HiServerError(statusCode: 502, code: 'E42');

      expect(error.toString(), contains('502'));
      expect(error.toString(), contains('E42'));
    });
  });

  group('HiError.from', () {
    test('returns a HiError unchanged', () {
      const error = HiForbiddenError();

      expect(HiError.from(error), same(error));
    });

    test('maps a TimeoutException to a timeout error', () {
      final error = HiError.from(TimeoutException('slow'));

      expect(error, isA<HiTimeoutError>());
    });

    test('maps a FormatException to a decode error', () {
      final error = HiError.from(const FormatException('bad json'));

      expect(error, isA<HiDecodeError>());
      expect(error.diagnostics, contains('bad json'));
    });

    test('wraps anything else as unknown, keeping the stack trace', () {
      final trace = StackTrace.current;

      final error = HiError.from('boom', trace);

      expect(error, isA<HiUnknownError>());
      expect(error.stackTrace, same(trace));
      expect(error.diagnostics, contains('boom'));
    });
  });
}
