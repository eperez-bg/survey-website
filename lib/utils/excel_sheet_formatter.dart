// excel_sheet_formatter.dart
//
// Responsibility:
// Applies presentation-only formatting to a completed Excel worksheet.
// It does not populate survey values, calculate metrics, encode workbooks, or
// trigger downloads.

import 'package:excel_community/excel_community.dart';

class ExcelSheetFormatter {
  const ExcelSheetFormatter();

  static const double headerRowHeightPixels = 28;
  static const double bodyRowHeightPixels = 17;
  static const double _pointsPerPixel = 72 / 96;

  static const double headerRowHeightPoints =
      headerRowHeightPixels * _pointsPerPixel;
  static const double bodyRowHeightPoints =
      bodyRowHeightPixels * _pointsPerPixel;

  static const double _headerColumnPadding = 2;
  static const String _headerFillHex = '#FFF2CC';

  /// Formats a worksheet after all headings and data rows have been appended.
  void formatPopulatedSheet(Sheet sheet) {
    if (sheet.maxRows == 0 || sheet.maxColumns == 0) return;

    final border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.black,
    );
    final headerFill = ExcelColor.fromHexString(_headerFillHex);

    _sizeColumnsFromHeaders(sheet);

    for (var rowIndex = 0; rowIndex < sheet.maxRows; rowIndex += 1) {
      sheet.setRowHeight(
        rowIndex,
        rowIndex == 0 ? headerRowHeightPoints : bodyRowHeightPoints,
      );

      for (
        var columnIndex = 0;
        columnIndex < sheet.maxColumns;
        columnIndex += 1
      ) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: columnIndex,
            rowIndex: rowIndex,
          ),
        );
        if (!_hasContent(cell.value)) continue;

        final currentStyle = cell.cellStyle ?? CellStyle();
        cell.cellStyle = currentStyle.copyWith(
          boldVal: rowIndex == 0 ? true : null,
          backgroundColorHexVal: rowIndex == 0 ? headerFill : null,
          verticalAlignVal: rowIndex == 0 ? VerticalAlign.Center : null,
          leftBorderVal: border,
          rightBorderVal: border,
          topBorderVal: border,
          bottomBorderVal: border,
        );
      }
    }
  }

  void _sizeColumnsFromHeaders(Sheet sheet) {
    for (
      var columnIndex = 0;
      columnIndex < sheet.maxColumns;
      columnIndex += 1
    ) {
      final headerValue = sheet
          .cell(
            CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: 0),
          )
          .value;
      if (!_hasContent(headerValue)) continue;

      final headerLength = headerValue.toString().runes.length.toDouble();
      sheet.setColumnWidth(columnIndex, headerLength + _headerColumnPadding);
    }
  }

  bool _hasContent(CellValue? value) {
    return value != null && value.toString().trim().isNotEmpty;
  }
}
