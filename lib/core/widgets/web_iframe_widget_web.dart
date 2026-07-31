import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget createIFrameWidget(String url) {
  final viewId = 'iframe-${url.hashCode}';
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int id) => html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allow', 'autoplay; encrypted-media; fullscreen; picture-in-picture; camera; microphone; display-capture'),
  );
  return HtmlElementView(viewType: viewId);
}
