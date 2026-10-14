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
  ///
  /// [headerRowCount] allows the export to use stacked headings while keeping
  /// this utility reusable for ordinary one-row sheets.
  void formatPopulatedSheet(Sheet sheet, {int headerRowCount = 1}) {
    if (sheet.maxRows == 0 || sheet.maxColumns == 0) return;

    final formattedHeaderRows = headerRowCount
        .clamp(0, sheet.maxRows)
        .toInt();

    final border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.black,
    );
    final headerFill = ExcelColor.fromHexString(_headerFillHex);

    _sizeColumnsFromHeaders(sheet, formattedHeaderRows);

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

        final isHeader = rowIndex < formattedHeaderRows;
        final currentStyle = cell.cellStyle ?? CellStyle();
        cell.cellStyle = currentStyle.copyWith(
          boldVal: isHeader ? true : null,
          backgroundColorHexVal: isHeader ? headerFill : null,
          verticalAlignVal: isHeader ? VerticalAlign.Center : null,
          leftBorderVal: border,
          rightBorderVal: border,
          topBorderVal: border,
          bottomBorderVal: border,
        );
      }
    }
  }

  void _sizeColumnsFromHeaders(Sheet sheet, int headerRowCount) {
    for (
      var columnIndex = 0;
      columnIndex < sheet.maxColumns;
      columnIndex += 1
    ) {
      var longestHeaderLength = 0;
      for (var rowIndex = 0; rowIndex < headerRowCount; rowIndex += 1) {
        final headerValue = sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: columnIndex,
                rowIndex: rowIndex,
              ),
            )
            .value;
        if (!_hasContent(headerValue)) continue;
        final length = headerValue.toString().runes.length;
        if (length > longestHeaderLength) {
          longestHeaderLength = length;
        }
      }
      if (longestHeaderLength == 0) continue;
      sheet.setColumnWidth(
        columnIndex,
        longestHeaderLength.toDouble() + _headerColumnPadding,
      );
    }
  }

  bool _hasContent(CellValue? value) {
    return value != null && value.toString().trim().isNotEmpty;
  }
}
