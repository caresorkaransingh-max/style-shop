import 'package:flutter/material.dart';

void downloadTextFile(String filename, String content) {}

Widget buildPlatformVideoPlayer(String url, double height) {
  return Container(
    height: height,
    color: Colors.black87,
    alignment: Alignment.center,
    child: Text(url, style: const TextStyle(color: Colors.white)),
  );
}