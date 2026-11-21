import 'package:hiflutter_base/hiflutter_base.dart';

import 'json_body.dart';
import 'reply.dart';
import 'response.dart';

/// Describes the response envelope of an API, such as
/// `{"code": 0, "message": "ok", "data": {...}}`, and decodes it.
///
/// Each `...Keys` argument lists candidate keys separated by `|` (see
/// [HiMapPick.pick]); the first candidate that is present and not `null`
/// wins. Codes are compared as strings, so `0` and `"0"` are the same code.
final class HiEnvelope {
  /// Creates an envelope description.
  const HiEnvelope({
    this.codeKeys = 'code',
    this.messageKeys = 'message|msg',
    this.dataKeys = 'data',
    this.successCodes = const {'0'},
    this.unauthorizedCodes = const {},
  });

  /// Candidate keys of the business code.
  final String codeKeys;

  /// Candidate keys of the human-readable message.
  final String messageKeys;

  /// Candidate keys of the payload.
  final String dataKeys;

  /// Business codes that mean success.
  final Set<String> successCodes;

  /// Business codes that mean the session is no longer valid; they raise a
  /// [HiUnauthorizedError] just like HTTP 401.
  final Set<String> unauthorizedCodes;

  /// A copy with the given fields replaced.
  HiEnvelope copyWith({
    String? codeKeys,
    String? messageKeys,
    String? dataKeys,
    Set<String>? successCodes,
    Set<String>? unauthorizedCodes,
  }) => HiEnvelope(
    codeKeys: codeKeys ?? this.codeKeys,
    messageKeys: messageKeys ?? this.messageKeys,
    dataKeys: dataKeys ?? this.dataKeys,
    successCodes: successCodes ?? this.successCodes,
    unauthorizedCodes: unauthorizedCodes ?? this.unauthorizedCodes,
  );

  /// Decodes the envelope of a 2xx [response].
  ///
  /// Throws a [HiDecodeError] when the body is not a JSON object or has no
  /// code, a [HiUnauthorizedError] for [unauthorizedCodes], and a
  /// [HiServerError] carrying the code and message for any other code not
  /// in [successCodes].
  HiReply decode(HiResponse response) {
    final json = decodeJsonBody(response);
    if (json is! Map<String, Object?>) {
      throw HiDecodeError(
        message: 'Expected a JSON object envelope, got ${json.runtimeType}.',
      );
    }
    final code = json.pickString(codeKeys);
    final message = json.pickString(messageKeys);
    if (code == null) {
      throw HiDecodeError(message: 'The envelope has no "$codeKeys" code.');
    }
    if (successCodes.contains(code)) {
      return HiReply(
        response: response,
        data: json.pick(dataKeys),
        code: code,
        message: message,
      );
    }
    if (unauthorizedCodes.contains(code)) {
      throw HiUnauthorizedError(message: message);
    }
    throw HiServerError(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }

  /// Reads the code and message of an error [response] on a best-effort
  /// basis, without throwing.
  (String? code, String? message) peek(HiResponse response) {
    try {
      final json = decodeJsonBody(response);
      if (json is Map<String, Object?>) {
        return (json.pickString(codeKeys), json.pickString(messageKeys));
      }
    } on HiDecodeError {
      // Not an envelope; report nothing.
    }
    return (null, null);
  }
}
