import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final Widget? prefix;
  final Widget? suffix;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.style,
    this.decoration,
    this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return fluent.TextBox(
        controller: controller,
        focusNode: focusNode,
        placeholder: hintText,
        style: style,
        onSubmitted: onSubmitted,
        obscureText: obscureText,
        autofocus: autofocus,
        prefix: prefix,
        suffix: suffix,
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      decoration: decoration ?? InputDecoration(hintText: hintText),
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofocus: autofocus,
    );
  }
}
