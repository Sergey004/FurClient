import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../../utils/platform_utils.dart';

/// Adaptive page route — FluentPageRoute on Windows, MaterialPageRoute on others.
PageRoute<void> adaptiveRoute({required WidgetBuilder builder}) {
  if (isWindows) {
    return fluent.FluentPageRoute<void>(builder: builder);
  }
  return MaterialPageRoute<void>(builder: builder);
}
