class ValueUtils {
  static bool equals(dynamic a, dynamic b) {
    if (identical(a, b)) {
      return true;
    }

    if (a is List && b is List) {
      if (a.length != b.length) {
        return false;
      }

      for (var i = 0; i < a.length; i++) {
        if (!equals(a[i], b[i])) {
          return false;
        }
      }

      return true;
    }

    if (a is Map && b is Map) {
      if (a.length != b.length) {
        return false;
      }

      for (final key in a.keys) {
        if (!b.containsKey(key)) {
          return false;
        }

        if (!equals(a[key], b[key])) {
          return false;
        }
      }

      return true;
    }

    return a == b;
  }

  static Map<String, dynamic> deepCopyMap(
    Map<String, dynamic> source,
  ) {
    return source.map(
      (key, value) => MapEntry(
        key,
        deepCopy(value),
      ),
    );
  }

  static dynamic deepCopy(dynamic value) {
    if (value is List) {
      return value.map(deepCopy).toList();
    }

    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(
          key,
          deepCopy(value),
        ),
      );
    }

    return value;
  }

}