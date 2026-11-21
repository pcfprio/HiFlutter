import 'package:hiflutter_base/hiflutter_base.dart';

import 'response.dart';

/// Builds a `T` from one JSON object, such as a `User.fromJson` factory.
typedef HiFromJson<T> = T Function(Map<String, dynamic> json);

/// A successful reply, after the status check and envelope decoding.
///
/// Unpack [data] with [object], [list] or [decode]; any failure while doing
/// so, including an exception thrown by the injected `fromJson`, becomes a
/// [HiDecodeError].
final class HiReply {
  /// Creates a reply.
  const HiReply({required this.response, this.data, this.code, this.message});

  /// The raw response.
  final HiResponse response;

  /// The payload: the envelope's data, or the whole JSON body when the
  /// client has no envelope.
  final Object? data;

  /// The envelope's business code, as a string, if any.
  final String? code;

  /// The envelope's message, if any.
  final String? message;

  /// Converts [data] with [convert].
  T decode<T>(T Function(Object? data) convert) {
    try {
      return convert(data);
    } on HiError {
      rethrow;
    } catch (e, s) {
      throw HiDecodeError(
        message: 'Could not decode the reply data.',
        cause: e,
        stackTrace: s,
      );
    }
  }

  /// Decodes [data], which must be a JSON object, with [fromJson].
  T object<T>(HiFromJson<T> fromJson) => decode(
    (data) => switch (data) {
      Map<String, dynamic>() => fromJson(data),
      _ => throw HiDecodeError(
        message: 'Expected a JSON object, got ${data.runtimeType}.',
      ),
    },
  );

  /// Decodes [data], which must be a JSON array of objects or `null`
  /// (an empty list), with [fromJson] for each element.
  List<T> list<T>(HiFromJson<T> fromJson) => decode(
    (data) => switch (data) {
      null => <T>[],
      List<Object?>() => [
        for (final item in data)
          if (item is Map<String, dynamic>)
            fromJson(item)
          else
            throw HiDecodeError(
              message:
                  'Expected a JSON object element, got ${item.runtimeType}.',
            ),
      ],
      _ => throw HiDecodeError(
        message: 'Expected a JSON array, got ${data.runtimeType}.',
      ),
    },
  );
}

/// Unpacks a pending [HiReply] in one chain, such as
/// `await client.get('me').object(User.fromJson)`.
extension HiReplyFuture on Future<HiReply> {
  /// See [HiReply.decode].
  Future<T> decode<T>(T Function(Object? data) convert) async =>
      (await this).decode(convert);

  /// See [HiReply.object].
  Future<T> object<T>(HiFromJson<T> fromJson) async =>
      (await this).object(fromJson);

  /// See [HiReply.list].
  Future<List<T>> list<T>(HiFromJson<T> fromJson) async =>
      (await this).list(fromJson);
}
