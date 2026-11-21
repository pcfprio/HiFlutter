import 'dart:convert';

import 'package:hiflutter_base/hiflutter_base.dart';

import 'response.dart';

/// Decodes the body of [response] as JSON; an empty body is `null`.
///
/// Throws a [HiDecodeError] when the body is not valid JSON.
Object? decodeJsonBody(HiResponse response) {
  final text = response.bodyText;
  if (text.trim().isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException catch (e, s) {
    throw HiDecodeError(
      message: 'The response body is not valid JSON.',
      cause: e,
      stackTrace: s,
    );
  }
}
