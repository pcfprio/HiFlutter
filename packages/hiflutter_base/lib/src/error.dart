import 'dart:async';

/// Category of a [HiError].
enum HiErrorKind {
  /// The network is unreachable or the connection failed.
  network,

  /// The operation did not complete in time.
  timeout,

  /// The caller is not authenticated (for example HTTP 401).
  unauthorized,

  /// The caller is authenticated but not allowed (for example HTTP 403).
  forbidden,

  /// The requested resource does not exist (for example HTTP 404).
  notFound,

  /// The server failed or rejected the request with a business error.
  server,

  /// A response or stored value could not be decoded.
  decode,

  /// The operation was cancelled by the caller.
  cancelled,

  /// Local storage failed or refused the operation.
  storage,

  /// Anything else.
  unknown,
}

/// The single failure type of HiFlutter.
///
/// Every failure is one of the sealed subtypes, so UI code can switch over
/// them exhaustively. The original exception that caused the failure is kept
/// only as diagnostic text and never exposed as an object, so no third-party
/// type leaks through the public API.
sealed class HiError implements Exception {
  const HiError._({
    this.message,
    this._cause,
    this.stackTrace,
    this._retryable,
  });

  /// Normalizes any thrown object into a [HiError].
  ///
  /// A [HiError] is returned unchanged; a [TimeoutException] becomes a
  /// [HiTimeoutError]; a [FormatException] becomes a [HiDecodeError];
  /// anything else becomes a [HiUnknownError]. The original object is kept
  /// as diagnostics only.
  factory HiError.from(
    Object error, [
    StackTrace? stackTrace,
  ]) => switch (error) {
    HiError() => error,
    TimeoutException() => HiTimeoutError(cause: error, stackTrace: stackTrace),
    FormatException() => HiDecodeError(cause: error, stackTrace: stackTrace),
    _ => HiUnknownError(cause: error, stackTrace: stackTrace),
  };

  /// Optional human-readable detail, such as a server-provided message.
  final String? message;

  /// Where the failure originated, when known.
  final StackTrace? stackTrace;

  final Object? _cause;
  final bool? _retryable;

  /// Category of this failure.
  HiErrorKind get kind;

  /// Whether retrying the same operation may succeed.
  bool get retryable => _retryable ?? _retryableByDefault;

  bool get _retryableByDefault => false;

  /// How UI should present this failure; see [HiErrorDisplay].
  HiErrorDisplay get display => switch (kind) {
    HiErrorKind.network => HiErrorDisplay.network,
    HiErrorKind.timeout => HiErrorDisplay.timeout,
    HiErrorKind.unauthorized => HiErrorDisplay.unauthorized,
    HiErrorKind.forbidden => HiErrorDisplay.forbidden,
    HiErrorKind.notFound => HiErrorDisplay.notFound,
    HiErrorKind.server => HiErrorDisplay.server,
    HiErrorKind.decode => HiErrorDisplay.data,
    HiErrorKind.cancelled => HiErrorDisplay.none,
    HiErrorKind.storage || HiErrorKind.unknown => HiErrorDisplay.generic,
  };

  /// Developer-facing description including the original cause, for logs
  /// and crash reports. Not meant to be shown to end users.
  String get diagnostics {
    final cause = _cause;
    return cause == null ? toString() : '$this\nCaused by: $cause';
  }

  /// Extra `name: value` fields for [toString].
  Map<String, Object?> get _fields => const {};

  @override
  String toString() {
    final fields = {
      ..._fields,
      'message': message,
    }.entries.where((e) => e.value != null).map((e) => '${e.key}: ${e.value}');
    return '$runtimeType(${fields.join(', ')})';
  }
}

/// Presentation category of a [HiError].
///
/// UI layers map each value to a localized title, description and image.
enum HiErrorDisplay {
  /// Connection problem.
  network,

  /// Took too long.
  timeout,

  /// Needs sign-in.
  unauthorized,

  /// Not permitted.
  forbidden,

  /// Content missing.
  notFound,

  /// Server-side failure.
  server,

  /// Data could not be read.
  data,

  /// Generic failure.
  generic,

  /// Should not be shown at all (for example a cancelled request).
  none,
}

/// The network is unreachable or the connection failed. Retryable by default.
final class HiNetworkError extends HiError {
  /// Creates a network error; [cause] is kept for diagnostics only.
  const HiNetworkError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.network;

  @override
  bool get _retryableByDefault => true;
}

/// The operation did not complete in time. Retryable by default.
final class HiTimeoutError extends HiError {
  /// Creates a timeout error; [cause] is kept for diagnostics only.
  const HiTimeoutError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.timeout;

  @override
  bool get _retryableByDefault => true;
}

/// The caller is not authenticated.
final class HiUnauthorizedError extends HiError {
  /// Creates an unauthorized error; [cause] is kept for diagnostics only.
  const HiUnauthorizedError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.unauthorized;
}

/// The caller is authenticated but not allowed.
final class HiForbiddenError extends HiError {
  /// Creates a forbidden error; [cause] is kept for diagnostics only.
  const HiForbiddenError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.forbidden;
}

/// The requested resource does not exist.
final class HiNotFoundError extends HiError {
  /// Creates a not-found error; [cause] is kept for diagnostics only.
  const HiNotFoundError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.notFound;
}

/// The server failed, or rejected the request with a business error.
///
/// Retryable by default only for HTTP 5xx [statusCode]s.
final class HiServerError extends HiError {
  /// Creates a server error; [cause] is kept for diagnostics only.
  const HiServerError({
    this.statusCode,
    this.code,
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  /// HTTP status code, when the failure came from an HTTP response.
  final int? statusCode;

  /// Business error code from the response envelope, when present.
  final String? code;

  @override
  HiErrorKind get kind => HiErrorKind.server;

  @override
  Map<String, Object?> get _fields => {'statusCode': statusCode, 'code': code};

  @override
  bool get _retryableByDefault {
    final status = statusCode;
    return status != null && status >= 500 && status < 600;
  }
}

/// A response or stored value could not be decoded.
final class HiDecodeError extends HiError {
  /// Creates a decode error; [cause] is kept for diagnostics only.
  const HiDecodeError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.decode;
}

/// The operation was cancelled by the caller.
final class HiCancelledError extends HiError {
  /// Creates a cancellation error; [cause] is kept for diagnostics only.
  const HiCancelledError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.cancelled;
}

/// Local storage failed or refused the operation.
final class HiStorageError extends HiError {
  /// Creates a storage error; [cause] is kept for diagnostics only.
  const HiStorageError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.storage;
}

/// A failure that fits no other category.
final class HiUnknownError extends HiError {
  /// Creates an unknown error; [cause] is kept for diagnostics only.
  const HiUnknownError({
    super.message,
    super.cause,
    super.stackTrace,
    super.retryable,
  }) : super._();

  @override
  HiErrorKind get kind => HiErrorKind.unknown;
}
