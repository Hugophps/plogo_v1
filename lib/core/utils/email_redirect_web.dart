// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

String getWebRedirectOrigin() => html.window.location.origin;
