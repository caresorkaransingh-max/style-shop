// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

void downloadTextFile(String filename, String content) {
  final blob = html.Blob([content], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

final Set<String> _registeredViews = <String>{};

Widget buildPlatformVideoPlayer(String url, double height) {
  final viewType = 'style-shop-video-${url.hashCode}-$height';
  if (!_registeredViews.contains(viewType)) {
    _registeredViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final video = html.VideoElement()
        ..src = url
        ..controls = true
        ..autoplay = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = '#000000';
      return video;
    });
  }
  return HtmlElementView(viewType: viewType);
}