import 'dart:convert';

import 'package:hiflutter_base/hiflutter_base.dart';

void main() {
  // Backends disagree on field names and types; read them leniently.
  final json = jsonDecode(
    '{"uid":"42","nick":"Ada","vip":"1","score":"9.5"}',
  ) as Map<String, dynamic>;
  final id = json.pickInt('id|uid') ?? 0;
  final name = json.pickString('name|nick') ?? 'anonymous';
  final vip = json.pickBool('is_vip|vip') ?? false;
  final score = HiConvert.asDouble(json['score']) ?? 0;
  print('user $id: $name, vip: $vip, score: $score');

  // Normalize any failure into the layered error model for the UI.
  final error = HiError.from(const FormatException('unexpected token'));
  final action = switch (error) {
    HiNetworkError() || HiTimeoutError() => 'check your connection',
    HiUnauthorizedError() => 'sign in again',
    HiCancelledError() => 'nothing to show',
    _ => error.retryable ? 'try again' : 'contact support',
  };
  print('${error.kind} (${error.display}): $action');
  print(error.diagnostics);
}
