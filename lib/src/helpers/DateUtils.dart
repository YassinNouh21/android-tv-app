import 'package:mawaqit/src/helpers/StringUtils.dart';
import 'package:mawaqit_tv_l10n/mawaqit_tv_l10n.dart';

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

extension MawaqitDateUtils on DateTime {
  String formatIntoMawaqitFormat({String local = 'en'}) {
    // Use MawaqitDateFormat which handles unsupported locales automatically
    final mappedLocale = mapToSupportedIntlLocale(local);

    var formatter = (mappedLocale == 'ar' || mappedLocale == 'fr')
        ? MawaqitDateFormat('EEEE, dd MMMM, yyyy', local)
        : MawaqitDateFormat('EEEE, MMMM dd, yyyy', local);

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
    var formatter = MawaqitDateFormat('EEEE, dd MMMM, yyyy');
    formatter.useNativeDigits = false;

    return formatter.format(this);
  }
}
