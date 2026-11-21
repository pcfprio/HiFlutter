/// A scalar value attached to analytics events or crash reports.
///
/// Only strings, integers, doubles and booleans are allowed, so every vendor
/// SDK can accept the value. Adapters switch over the sealed subtypes
/// exhaustively to convert them.
sealed class HiScalar {
  const HiScalar._();

  /// Wraps a [String], [int], [double] or [bool].
  ///
  /// Throws an [ArgumentError] for any other type, including `null`.
  factory HiScalar(Object? value) => switch (value) {
    final String v => HiStringScalar(v),
    final int v => HiIntScalar(v),
    final double v => HiDoubleScalar(v),
    final bool v => HiBoolScalar(v),
    _ => throw ArgumentError.value(
      value,
      'value',
      'must be a String, int, double or bool',
    ),
  };

  /// The wrapped Dart value.
  Object get value;

  @override
  bool operator ==(Object other) =>
      other is HiScalar &&
      other.runtimeType == runtimeType &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => '$value';
}

/// A [String] scalar.
final class HiStringScalar extends HiScalar {
  /// Wraps [value].
  const HiStringScalar(this.value) : super._();

  @override
  final String value;
}

/// An [int] scalar.
final class HiIntScalar extends HiScalar {
  /// Wraps [value].
  const HiIntScalar(this.value) : super._();

  @override
  final int value;
}

/// A [double] scalar.
final class HiDoubleScalar extends HiScalar {
  /// Wraps [value].
  const HiDoubleScalar(this.value) : super._();

  @override
  final double value;
}

/// A [bool] scalar.
final class HiBoolScalar extends HiScalar {
  /// Wraps [value].
  const HiBoolScalar(this.value) : super._();

  @override
  final bool value;
}
