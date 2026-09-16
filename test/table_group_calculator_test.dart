import 'package:flutter_test/flutter_test.dart';
import 'package:survey_admin_web/models/survey_map_model.dart';
import 'package:survey_admin_web/utils/table_group_calculator.dart';

void main() {
  const calculator = TableGroupCalculator();

  test('counts transitive edge-connected tables as one group', () {
    final tables = [
      _table('a', topRow: 0, leftColumn: 0),
      _table(
        'b',
        topRow: 0,
        leftColumn: 3,
        orientation: TableOrientation.vertical,
      ),
      _table('c', topRow: 3, leftColumn: 3),
      _table('separate', topRow: 10, leftColumn: 10),
    ];

    expect(calculator.countGroups(tables), 2);
  });

  test('does not connect tables that touch only at a corner', () {
    final tables = [
      _table('a', topRow: 0, leftColumn: 0),
      _table(
        'b',
        topRow: 2,
        leftColumn: 3,
        orientation: TableOrientation.vertical,
      ),
    ];

    expect(calculator.countGroups(tables), 2);
  });

  test('custom tables are excluded and cannot bridge groups', () {
    final tables = [
      _table('left', topRow: 0, leftColumn: 0),
      _table(
        'custom-bridge',
        topRow: 0,
        leftColumn: 3,
        orientation: TableOrientation.vertical,
        kind: TableKind.custom,
      ),
      _table('right', topRow: 0, leftColumn: 5),
    ];

    expect(calculator.countGroups(tables), 2);
    expect(
      calculator.countGroups([
        _table('custom-only', topRow: 0, leftColumn: 0, kind: TableKind.custom),
      ]),
      0,
    );
  });

  test('counts one production table as one group', () {
    expect(
      calculator.countGroups([_table('single', topRow: 4, leftColumn: 4)]),
      1,
    );
  });
}

LayoutTableModel _table(
  String id, {
  required int topRow,
  required int leftColumn,
  TableOrientation orientation = TableOrientation.horizontal,
  TableKind kind = TableKind.normal,
}) {
  return LayoutTableModel(
    tableId: id,
    zoneId: null,
    pairId: null,
    topRow: topRow,
    leftColumn: leftColumn,
    tableKind: kind,
    orientation: orientation,
    customName: kind == TableKind.custom ? 'Custom' : null,
  );
}
