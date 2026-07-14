import 'dart:developer' as developer;

/// Logger for the FAKit library.
///
/// Uses the standard `dart:developer` logging. To configure log output,
/// set up a [Logger] handler in your app's main():
///
/// ```dart
/// import 'dart:developer';
///
/// void main() {
///   hierarchicalLoggingEnabled = true;
///   FALogger.logger.level = Level.ALL;
///   FALogger.logger.onRecord.listen((record) {
///     print('${record.level.name}: ${record.message}');
///   });
/// }
/// ```
///
/// Or integrate with `package:logging`:
/// ```dart
/// import 'package:logging/logging.dart';
/// FALogger.setLogger(Logger('FurAffinity'));
/// ```
class FALogger {
  static const String _libraryName = 'fa_kit';

  /// Create a logger instance for a specific subsystem.
  static FALoggerImpl loggerFor(String subsystem) {
    return FALoggerImpl(subsystem);
  }

  /// The main library logger.
  static FALoggerImpl get logger => loggerFor(_libraryName);
}

/// Logger implementation that wraps dart:developer log().
class FALoggerImpl {
  final String _name;
  bool _isInfoEnabled = true;
  bool _isDebugEnabled = false;
  final bool _isWarningEnabled = true;
  final bool _isErrorEnabled = true;

  FALoggerImpl(this._name);

  /// Enable or disable info-level logging.
  set infoEnabled(bool value) => _isInfoEnabled = value;

  /// Enable or disable debug-level logging.
  set debugEnabled(bool value) => _isDebugEnabled = value;

  /// Log an info message.
  void info(String message) {
    if (_isInfoEnabled) {
      _log('INFO', message);
    }
  }

  /// Log a debug message.
  void debug(String message) {
    if (_isDebugEnabled) {
      _log('DEBUG', message);
    }
  }

  /// Log a warning message.
  void warning(String message) {
    if (_isWarningEnabled) {
      _log('WARNING', message);
    }
  }

  /// Log an error message.
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_isErrorEnabled) {
      final buffer = StringBuffer(message);
      if (error != null) {
        buffer.write(' — Error: $error');
      }
      _log('ERROR', buffer.toString(), stackTrace);
    }
  }

  void _log(String level, String message, [StackTrace? stackTrace]) {
    final formattedMessage = '[$_name] $level: $message';
    developer.log(formattedMessage, name: _name);
    if (stackTrace != null) {
      developer.log(stackTrace.toString(), name: _name);
    }
  }
}
