/// Errors that can occur during HTML page parsing.
class FAPagesError implements Exception {
  final FAPagesErrorType type;
  final String? message;

  const FAPagesError(this.type, [this.message]);

  @override
  String toString() {
    switch (type) {
      case FAPagesErrorType.unexpectedStructure:
        return 'FAPagesError: Unexpected HTML structure${message != null ? ' - $message' : ''}';
      case FAPagesErrorType.invalidParameter:
        return 'FAPagesError: Invalid parameter${message != null ? ' - $message' : ''}';
      case FAPagesErrorType.parserFailure:
        return 'FAPagesError: Parser failure at ${message ?? 'unknown location'}';
    }
  }
}

enum FAPagesErrorType {
  /// The HTML structure did not match expected patterns.
  unexpectedStructure,

  /// An invalid parameter was provided.
  invalidParameter,

  /// A parser failure occurred at a specific location.
  parserFailure,
}

/// Content rating on FurAffinity. (DEPRECATED — use Rating from fa_submission_page.dart)
@Deprecated('Use Rating from fa_submission_page.dart')
enum Rating {
  general,
  mature,
  adult;

  static Rating fromString(String value) {
    switch (value.toLowerCase()) {
      case 'general':
        return Rating.general;
      case 'mature':
        return Rating.mature;
      case 'adult':
        return Rating.adult;
      default:
        return Rating.general;
    }
  }

  @override
  String toString() {
    switch (this) {
      case Rating.general:
        return 'General';
      case Rating.mature:
        return 'Mature';
      case Rating.adult:
        return 'Adult';
    }
  }
}
