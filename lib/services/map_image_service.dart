// map_image_service.dart
//
// Responsibility:
// Renders the map off-screen at a predictable export size. This avoids taking a
// screenshot of the visible InteractiveViewer, which could capture zoom/crop UI.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/survey_document.dart';
import '../widgets/survey_map_painter.dart';

class MapImageService {
  const MapImageService();

  Future<Uint8List> renderPng(SurveyDocument survey) async {
    if (survey.canvasRows <= 0 || survey.canvasColumns <= 0) {
      throw StateError('Cannot render a map with an empty canvas.');
    }

    final byWidth = 1800 / survey.canvasColumns;
    final byHeight = 1200 / survey.canvasRows;
    final cellSize = byWidth < byHeight ? byWidth : byHeight;
    final exportCellSize = cellSize.clamp(7.0, 22.0).toDouble();
    final width = (survey.canvasColumns * exportCellSize).ceil();
    final height = (survey.canvasRows * exportCellSize).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    SurveyMapPainter(
      survey: survey,
      cellSize: exportCellSize,
      showGrid: true,
    ).paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();

    if (byteData == null) {
      throw StateError('Flutter could not encode the map image.');
    }
    return byteData.buffer.asUint8List();
  }
}
