import 'package:intl/intl.dart';
import 'package:mawaqit/src/helpers/StringUtils.dart';

const _maghrebMonthNames = [
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جوان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر'
];

const _maghrebMonthsLocales = [
  'AR_TN',
  'AR_DZ',
];

/// Maps unsupported locale codes to supported fallback locales for intl package
/// The intl package doesn't support all locales that MawaqitTvLocalizations supports
String _mapToSupportedIntlLocale(String locale) {
  final languageCode = locale.split('_').first.toLowerCase();

  // Map unsupported locales to their closest supported equivalent
  const unsupportedLocaleMap = {
    'cnr': 'sr', // Montenegrin -> Serbian (closest supported Slavic language)
    'ckb': 'ar', // Kurdish (Sorani) -> Arabic (same script direction)
    'ff': 'en',  // Fulah -> English
    'ba': 'ru',  // Bashkir -> Russian (closest supported)
  };

  if (unsupportedLocaleMap.containsKey(languageCode)) {
    return unsupportedLocaleMap[languageCode]!;
  }

  return locale;
}

extension MawaqitDateUtils on DateTime {
  String formatIntoMawaqitFormat({String local = 'en'}) {
    // Map unsupported locales to supported ones for DateFormat
    final mappedLocale = _mapToSupportedIntlLocale(local);

    var formatter = mappedLocale == 'ar' || mappedLocale == 'fr'
        ? DateFormat('EEEE, dd MMMM, yyyy', mappedLocale)
        : DateFormat('EEEE, MMMM dd, yyyy', mappedLocale);

    if (_maghrebMonthsLocales.contains(local.toUpperCase())) {
      formatter.dateSymbols.MONTHS = _maghrebMonthNames;
    }

    formatter.useNativeDigits = false;
    return formatter.format(this).capitalizeFirstOfEach();
  }

  ///
  String convertToHijri({
    bool force30Days = false,
    int daysAdjustment = 0,
  }) {
    var formatter = DateFormat('EEEE, dd MMMM, yyyy');
    formatter.useNativeDigits = false;

    return formatter.format(this);
  }
}
