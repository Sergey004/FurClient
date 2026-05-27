import 'dart:io' show Platform;

bool get isWindows => Platform.isWindows;
bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isMacOS => Platform.isMacOS;
bool get isDesktop => isWindows || isMacOS || Platform.isLinux;
bool get isMobile => isAndroid || isIOS;
