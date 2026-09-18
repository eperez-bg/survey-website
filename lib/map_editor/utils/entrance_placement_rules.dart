import 'dart:math' as math;
import 'dart:ui';

import 'package:survey_admin_web/map_editor/models/map_editor_models.dart';

import 'distance_geometry.dart';
import 'grid_geometry.dart';

/// A snapped entrance position expressed in saved-layout coordinates.
class EntranceWallPlacement {
  final WallSide wallSide;
  final int offsetCells;

  const EntranceWallPlacement({
    required this.wallSide,
    required this.offsetCells,
  });
}

/// The painted line segment occupied by an entrance.
class EntranceSceneSegment {
  final Offset start;
  final Offset end;

  const EntranceSceneSegment({required this.start, required this.end});

  bool get isVertical => start.dx == end.dx;

  Offset get center => Offset(
    (start.dx + end.dx) / 2,
    (start.dy + end.dy) / 2,
  );
}

/// A half-open rectangle of grid cells reserved around an entrance.
class EntranceClearanceArea {
  final int topRow;
  final int leftColumn;
  final int bottomRowExclusive;
  final int rightColumnExclusive;

  const EntranceClearanceArea({
    required this.topRow,
    required this.leftColumn,
    required this.bottomRowExclusive,
    required this.rightColumnExclusive,
  });

  bool containsCell(GridCoordinate cell) =>
      cell.row >= topRow &&
      cell.row < bottomRowExclusive &&
      cell.column >= leftColumn &&
      cell.column < rightColumnExclusive;

  bool overlapsTable(LayoutTable table) => _areasOverlap(
    firstTop: topRow,
    firstLeft: leftColumn,
    firstBottom: bottomRowExclusive,
    firstRight: rightColumnExclusive,
    secondTop: table.topRow,
    secondLeft: table.leftColumn,
    secondBottom: table.bottomRowExclusive,
    secondRight: table.rightColumnExclusive,
  );

  static bool _areasOverlap({
    required int firstTop,
    required int firstLeft,
    required int firstBottom,
    required int firstRight,
    required int secondTop,
    required int secondLeft,
    required int secondBottom,
    required int secondRight,
  }) {
    return firstLeft < secondRight &&
        firstRight > secondLeft &&
        firstTop < secondBottom &&
        firstBottom > secondTop;
  }
}

/// Pure geometry and collision rules for adding, selecting, and moving doors.
///
/// Widgets convert pointer locations into [EntranceWallPlacement] values. The
/// controller then validates those values against the current saved layout.
class EntrancePlacementRules {
  const EntrancePlacementRules._();

  /// Matches the entrance included with a newly created production layout.
  static const int defaultWidthCells = 6;
  static const int defaultClearanceDepthCells = 4;

  /// Snaps a pointer to the nearest room wall while centering the entrance.
  ///
  /// A point farther than [hitTolerancePixels] from every wall is rejected,
  /// which prevents a double-tap in the room or canvas from creating a door.
  static EntranceWallPlacement? placementForScenePoint({
    required Offset scenePoint,
    required double cellSize,
    required RoomBounds roomBounds,
    int widthCells = defaultWidthCells,
    double hitTolerancePixels = 14,
  }) {
    if (cellSize <= 0 || widthCells <= 0 || hitTolerancePixels < 0) {
      return null;
    }

    final left = roomBounds.leftColumn * cellSize;
    final right = roomBounds.rightColumnExclusive * cellSize;
    final top = roomBounds.topRow * cellSize;
    final bottom = roomBounds.bottomRowExclusive * cellSize;
    final targets = <_WallTarget>[
      _WallTarget(
        wallSide: WallSide.top,
        distance: (scenePoint.dy - top).abs(),
        positionAlongWall: scenePoint.dx,
        wallStart: left,
        wallEnd: right,
      ),
      _WallTarget(
        wallSide: WallSide.right,
        distance: (scenePoint.dx - right).abs(),
        positionAlongWall: scenePoint.dy,
        wallStart: top,
        wallEnd: bottom,
      ),
      _WallTarget(
        wallSide: WallSide.bottom,
        distance: (scenePoint.dy - bottom).abs(),
        positionAlongWall: scenePoint.dx,
        wallStart: left,
        wallEnd: right,
      ),
      _WallTarget(
        wallSide: WallSide.left,
        distance: (scenePoint.dx - left).abs(),
        positionAlongWall: scenePoint.dy,
        wallStart: top,
        wallEnd: bottom,
      ),
    ];

    final candidates = targets.where(
      (target) =>
          target.distance <= hitTolerancePixels &&
          target.positionAlongWall >= target.wallStart - hitTolerancePixels &&
          target.positionAlongWall <= target.wallEnd + hitTolerancePixels,
    );
    if (candidates.isEmpty) {
      return null;
    }

    final nearest = candidates.reduce(
      (current, candidate) =>
          candidate.distance < current.distance ? candidate : current,
    );
    final wallLengthCells = _wallLengthCells(nearest.wallSide, roomBounds);
    final maximumOffset = math.max(0, wallLengthCells - widthCells);
    final rawOffset =
        ((nearest.positionAlongWall - nearest.wallStart) / cellSize -
                widthCells / 2)
            .round();

    return EntranceWallPlacement(
      wallSide: nearest.wallSide,
      offsetCells: rawOffset.clamp(0, maximumOffset).toInt(),
    );
  }

  /// Finds the closest painted entrance under a pointer.
  static Entrance? entranceAtScenePoint({
    required Offset scenePoint,
    required double cellSize,
    required RoomBounds roomBounds,
    required Iterable<Entrance> entrances,
    double hitTolerancePixels = 14,
  }) {
    Entrance? closest;
    var closestDistance = double.infinity;

    for (final entrance in entrances) {
      final segment = sceneSegmentFor(
        entrance: entrance,
        roomBounds: roomBounds,
        cellSize: cellSize,
      );
      final distance = _distanceFromPointToSegment(scenePoint, segment);
      if (distance <= hitTolerancePixels && distance < closestDistance) {
        closest = entrance;
        closestDistance = distance;
      }
    }

    return closest;
  }

  static EntranceSceneSegment sceneSegmentFor({
    required Entrance entrance,
    required RoomBounds roomBounds,
    required double cellSize,
  }) {
    final left = roomBounds.leftColumn * cellSize;
    final right = roomBounds.rightColumnExclusive * cellSize;
    final top = roomBounds.topRow * cellSize;
    final bottom = roomBounds.bottomRowExclusive * cellSize;

    return switch (entrance.wallSide) {
      WallSide.top => EntranceSceneSegment(
        start: Offset(left + entrance.offsetCells * cellSize, top),
        end: Offset(
          left + (entrance.offsetCells + entrance.widthCells) * cellSize,
          top,
        ),
      ),
      WallSide.right => EntranceSceneSegment(
        start: Offset(right, top + entrance.offsetCells * cellSize),
        end: Offset(
          right,
          top + (entrance.offsetCells + entrance.widthCells) * cellSize,
        ),
      ),
      WallSide.bottom => EntranceSceneSegment(
        start: Offset(left + entrance.offsetCells * cellSize, bottom),
        end: Offset(
          left + (entrance.offsetCells + entrance.widthCells) * cellSize,
          bottom,
        ),
      ),
      WallSide.left => EntranceSceneSegment(
        start: Offset(left, top + entrance.offsetCells * cellSize),
        end: Offset(
          left,
          top + (entrance.offsetCells + entrance.widthCells) * cellSize,
        ),
      ),
    };
  }

  static EntranceClearanceArea clearanceAreaFor({
    required Entrance entrance,
    required RoomBounds roomBounds,
  }) {
    return switch (entrance.wallSide) {
      WallSide.top => EntranceClearanceArea(
        topRow: roomBounds.topRow - entrance.clearanceDepthCells,
        leftColumn: roomBounds.leftColumn + entrance.offsetCells,
        bottomRowExclusive:
            roomBounds.topRow + entrance.clearanceDepthCells,
        rightColumnExclusive:
            roomBounds.leftColumn + entrance.offsetCells + entrance.widthCells,
      ),
      WallSide.right => EntranceClearanceArea(
        topRow: roomBounds.topRow + entrance.offsetCells,
        leftColumn:
            roomBounds.rightColumnExclusive - entrance.clearanceDepthCells,
        bottomRowExclusive:
            roomBounds.topRow + entrance.offsetCells + entrance.widthCells,
        rightColumnExclusive:
            roomBounds.rightColumnExclusive + entrance.clearanceDepthCells,
      ),
      WallSide.bottom => EntranceClearanceArea(
        topRow:
            roomBounds.bottomRowExclusive - entrance.clearanceDepthCells,
        leftColumn: roomBounds.leftColumn + entrance.offsetCells,
        bottomRowExclusive:
            roomBounds.bottomRowExclusive + entrance.clearanceDepthCells,
        rightColumnExclusive:
            roomBounds.leftColumn + entrance.offsetCells + entrance.widthCells,
      ),
      WallSide.left => EntranceClearanceArea(
        topRow: roomBounds.topRow + entrance.offsetCells,
        leftColumn: roomBounds.leftColumn - entrance.clearanceDepthCells,
        bottomRowExclusive:
            roomBounds.topRow + entrance.offsetCells + entrance.widthCells,
        rightColumnExclusive:
            roomBounds.leftColumn + entrance.clearanceDepthCells,
      ),
    };
  }

  /// Returns a user-facing reason when [candidate] cannot be saved.
  static String? placementError({
    required Entrance candidate,
    required GardenCenterLayout layout,
    String? ignoredEntranceId,
  }) {
    final wallLength = _wallLengthCells(
      candidate.wallSide,
      layout.roomBounds,
    );
    if (candidate.offsetCells < 0 ||
        candidate.offsetCells + candidate.widthCells > wallLength) {
      return 'The entrance must fit completely on a room wall.';
    }

    final candidateClearance = clearanceAreaFor(
      entrance: candidate,
      roomBounds: layout.roomBounds,
    );
    for (final existing in layout.entranceList) {
      if (existing.entranceId == ignoredEntranceId) {
        continue;
      }

      final sharesWall = existing.wallSide == candidate.wallSide;
      final spansOverlap =
          candidate.offsetCells < existing.offsetCells + existing.widthCells &&
          candidate.offsetCells + candidate.widthCells > existing.offsetCells;
      if (sharesWall && spansOverlap) {
        return 'Entrances cannot overlap.';
      }

    }

    if (layout.layoutTableList.any(candidateClearance.overlapsTable)) {
      return 'Move tables out of the entrance clearance first.';
    }

    for (final distance in layout.distanceList) {
      if (DistanceGeometry.cellsForDistance(
        distance,
        layout,
      ).any(candidateClearance.containsCell)) {
        return 'Move or delete the distance blocking this entrance first.';
      }
    }

    if (layout.spigotList.any(
      (spigot) => _spigotOccupiesEntrance(
        spigot: spigot,
        entrance: candidate,
        roomBounds: layout.roomBounds,
      ),
    )) {
      return 'A spigot cannot occupy the same section of wall as an entrance.';
    }

    return null;
  }

  static int _wallLengthCells(WallSide side, RoomBounds roomBounds) {
    return side == WallSide.top || side == WallSide.bottom
        ? roomBounds.widthCells
        : roomBounds.heightCells;
  }

  static bool _spigotOccupiesEntrance({
    required Spigot spigot,
    required Entrance entrance,
    required RoomBounds roomBounds,
  }) {
    final start = entrance.offsetCells;
    final end = entrance.offsetCells + entrance.widthCells;

    return switch (entrance.wallSide) {
      WallSide.top =>
        spigot.rowLine == roomBounds.topRow &&
            spigot.columnLine >= roomBounds.leftColumn + start &&
            spigot.columnLine <= roomBounds.leftColumn + end,
      WallSide.right =>
        spigot.columnLine == roomBounds.rightColumnExclusive &&
            spigot.rowLine >= roomBounds.topRow + start &&
            spigot.rowLine <= roomBounds.topRow + end,
      WallSide.bottom =>
        spigot.rowLine == roomBounds.bottomRowExclusive &&
            spigot.columnLine >= roomBounds.leftColumn + start &&
            spigot.columnLine <= roomBounds.leftColumn + end,
      WallSide.left =>
        spigot.columnLine == roomBounds.leftColumn &&
            spigot.rowLine >= roomBounds.topRow + start &&
            spigot.rowLine <= roomBounds.topRow + end,
    };
  }

  static double _distanceFromPointToSegment(
    Offset point,
    EntranceSceneSegment segment,
  ) {
    final delta = segment.end - segment.start;
    final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    if (lengthSquared == 0) {
      return (point - segment.start).distance;
    }

    final relative = point - segment.start;
    final projection =
        (relative.dx * delta.dx + relative.dy * delta.dy) / lengthSquared;
    final clampedProjection = projection.clamp(0.0, 1.0).toDouble();
    final closest = segment.start + delta * clampedProjection;
    return (point - closest).distance;
  }
}

class _WallTarget {
  final WallSide wallSide;
  final double distance;
  final double positionAlongWall;
  final double wallStart;
  final double wallEnd;

  const _WallTarget({
    required this.wallSide,
    required this.distance,
    required this.positionAlongWall,
    required this.wallStart,
    required this.wallEnd,
  });
}
