/// A slice of text produced by [HiLinkDetector.split], representing either
/// plain text or a detected HTTP/HTTPS link.
final class HiTextSegment {
  /// Creates a text segment; [uri] is non-null when this segment is a link.
  const HiTextSegment(this.text, {this.uri});

  /// The slice of the original text.
  final String text;

  /// The parsed link URI, or `null` when this segment is plain text.
  final Uri? uri;

  /// Whether this segment is a detected link (`uri != null`).
  bool get isLink => uri != null;

  @override
  bool operator ==(Object other) =>
      other is HiTextSegment && other.text == text && other.uri == uri;

  @override
  int get hashCode => Object.hash(text, uri);

  @override
  String toString() =>
      isLink ? 'HiTextSegment.link($text, $uri)' : 'HiTextSegment($text)';
}

/// Splits plain text into alternating plain and HTTP/HTTPS link segments.
abstract final class HiLinkDetector {
  static final _candidatePattern = RegExp(
    r'''(?<![A-Za-z0-9])https?://[^\s"'<`\x00-\x1f\x7f-\uffff]+''',
    caseSensitive: false,
  );

  static const _trailingPunctuation = {'.', ',', ';', ':', '!', '?'};
  static const _closingBrackets = {')': '(', ']': '[', '>': '<'};

  /// Splits [text] into plain and link [HiTextSegment]s.
  ///
  /// Only `http://` and `https://` links with a non-empty host are recognized.
  /// Trailing sentence punctuation (`.`, `,`, `;`, `:`, `!`, `?`) and unpaired
  /// closing delimiters (`)`, `]`, `>`) are stripped from the end of a link
  /// and kept in the following plain segment, while balanced pairs inside the
  /// URL are preserved. Plain or empty input returns a single non-link segment.
  static List<HiTextSegment> split(String text) {
    final segments = <HiTextSegment>[];
    var cursor = 0;

    for (final match in _candidatePattern.allMatches(text)) {
      final start = match.start;
      final end = _trimTrailing(text, start, match.end);
      if (end <= start) continue;

      final candidate = text.substring(start, end);
      final uri = Uri.tryParse(candidate);
      if (uri == null || uri.host.isEmpty) continue;

      if (start > cursor) {
        segments.add(HiTextSegment(text.substring(cursor, start)));
      }
      segments.add(HiTextSegment(candidate, uri: uri));
      cursor = end;
    }

    if (segments.isEmpty || cursor < text.length) {
      segments.add(HiTextSegment(text.substring(cursor)));
    }
    return segments;
  }

  static int _trimTrailing(String text, int start, int end) {
    while (end > start) {
      final last = text[end - 1];
      if (_trailingPunctuation.contains(last)) {
        end--;
        continue;
      }
      final open = _closingBrackets[last];
      if (open != null &&
          _isTrailingCloseUnpaired(text, start, end, open, last)) {
        end--;
        continue;
      }
      break;
    }
    return end;
  }

  static bool _isTrailingCloseUnpaired(
    String text,
    int start,
    int end,
    String open,
    String close,
  ) {
    var balance = 0;
    for (var i = start; i < end - 1; i++) {
      final ch = text[i];
      if (ch == open) {
        balance++;
      } else if (ch == close && balance > 0) {
        balance--;
      }
    }
    return balance == 0;
  }
}
