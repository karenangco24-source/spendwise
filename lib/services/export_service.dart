import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'expense_service.dart';

// ONLY for web download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ExportService {
  static Future<String> exportCurrentMonth() async {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    final fmt = DateFormat('MMM dd, yyyy');

    final all = ExpenseService.getAllExpenses();

    final monthly = all.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    ).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final buf = StringBuffer();

    buf.writeln('========================================');
    buf.writeln('        SPENDWISE EXPENSE REPORT');
    buf.writeln('        $monthLabel');
    buf.writeln('========================================');
    buf.writeln();

    double total = 0;

    for (final e in monthly) {
      buf.writeln(
        '${fmt.format(e.date).padRight(16)} '
        '${e.categoryName.padRight(14)} '
        '₱${e.amount.toStringAsFixed(2).padLeft(10)} '
        '  ${e.title}',
      );
      total += e.amount;
    }

    buf.writeln();
    buf.writeln('----------------------------------------');
    buf.writeln('${' ' * 32}TOTAL  ₱${total.toStringAsFixed(2)}');
    buf.writeln('========================================');
    buf.writeln(
      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
    );

    final fileName =
        'spendwise_${now.year}_${now.month.toString().padLeft(2, '0')}.txt';

    final content = buf.toString();

    // ================= WEB (Chrome) =================
    if (kIsWeb) {
      final bytes = utf8.encode(content);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();

      html.Url.revokeObjectUrl(url);

      return "Downloaded: $fileName";
    }

    // ================= MOBILE (Android/iOS) =================
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');

    await file.writeAsString(content);

    return file.path;
  }
}