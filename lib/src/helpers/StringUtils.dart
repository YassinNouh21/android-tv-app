import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mawaqit/i18n/AppLanguage.dart';
import 'package:provider/provider.dart';

import '../../i18n/l10n.dart';

extension StringUtils on String {
  /// convert string to UpperCamelCaseFormat
  String get toCamelCase {
    final separated = trim().toLowerCase().split(' ');

    var value = separated.first;
    for (var i = 1; i < separated.length; i++) {
      final val = separated[i];

      value += toBeginningOfSentenceCase(val) ?? '';
    }

    return value;
  }
}

String? toCamelCase(String? value) {
  return value?.toCamelCase;
}

class StringManager {
  // final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  static RegExp arabicLetters = RegExp(r'[\u0600-\u06ff]');
  static RegExp urduLetters = RegExp(r'[\u0600-\u06ff]+');
  static const fontFamilyKufi = "kufi";
  static const fontFamilyArial = "arial";
  static const fontFamilyHelvetica = "helvetica";
  static const fontFamilyKJino = "KJino";
  static const fontFamilyJameelNoori = "JameelNooriNastaleeq";

  static const rtlLanguages = const ['ar', 'he', 'fa', 'ur', 'arc', 'az', 'dv', 'ckb'];

  static TextDirection getTextDirectionOfLocal(Locale locale) {
    return rtlLanguages.contains(locale.languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }

///////////// Salah count down text in Time widget

  static String _formatTime(BuildContext context, Duration t) {
    return t.inMinutes > 0
        ? "${t.inHours.toString().padLeft(2, '0')}:${(t.inMinutes % 60).toString().padLeft(2, '0')}"
        : "${(t.inSeconds % 60).toString().padLeft(2, '0')} ${S.of(context).sec}";
  }

  /// Countdown for obligatory prayers (Fajr, Dhuhr, Asr, Maghrib, Isha, Jumua).
  static String getPrayerCountdown(BuildContext context, Duration salahTime, String salahName) {
    return S.of(context).countdownPrayer(salahName, _formatTime(context, salahTime));
  }

  /// Countdown for non-prayer events (Shuruq, Duha).
  static String getEventCountdown(BuildContext context, Duration eventTime, String eventName) {
    return S.of(context).countdownNonPrayer(eventName, _formatTime(context, eventTime));
  }

//////////// get font family
  @deprecated
  static String? getFontFamilyByString(String value) {
    if (value.isArabic() || value.isUrdu()) {
      return fontFamilyKufi;
    }
    return null;
  }

  @Deprecated('user [StringManager.getFontFamilyByString] or anyString.isArabic')
  static String? getFontFamily(BuildContext context) {
    String langCode = "${context.read<AppLanguage>().appLocal}";
    if (langCode == "ar" || langCode == "ur") {
      return fontFamilyKufi;
    }
    return null;
  }

  /// return list
  @deprecated
  static List convertStringToList(String text) {
    List<String> list = List.from(text.split(RegExp(r"\s+")));

    List<int> arabicIndexes = [];
    arabicIndexes =
        list.asMap().entries.where((entry) => arabicLetters.hasMatch(entry.value)).map((entry) => entry.key).toList();
    if (arabicIndexes.isEmpty) return list;
    List<String> sublist = list.sublist(arabicIndexes.first, arabicIndexes.last + 1);
// Reverse the sublist
    sublist = sublist.reversed.toList();
// Replace the original sublist with the reversed sublist
    list.replaceRange(arabicIndexes.first, arabicIndexes.last + 1, sublist);

    return list;
  }
}

extension StringConversion on String {
  bool isArabic() {
    return RegExp("[\u0600-\u06FF]").hasMatch(this);
  }

  bool isUrdu() {
    return RegExp(r'[\u0600-\u06ff]+').hasMatch(this);
  }

  String capitalize() {
    if (this.isEmpty) return this;
    if (this.length == 1) return this.toUpperCase();

    return "${this[0].toUpperCase()}${this.substring(1)}";
  }

  String capitalizeFirstOfEach() {
    return this.split(" ").map((str) => str.capitalize()).join(" ");
  }
}
