import 'package:mawaqit/src/helpers/StringUtils.dart';
import 'package:mawaqit_tv_l10n/mawaqit_tv_l10n.dart';

// Month names by region
const _arabicMonthsByRegion = {
  // Algeria and Tunisia (French-based)
  'maghreb': [
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
  ],

  // Morocco (Berber calendar-based)
  'morocco': ['يناير', 'فبراير', 'مارس', 'إبريل', 'ماي', 'يونيو', 'يوليوز', 'غشت', 'شتنبر', 'أكتوبر', 'نونبر', 'دجنبر'],

  // Egypt, Sudan, Gulf (Latin-based)
  'egypt_gulf': [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ],

  // Levant: Iraq, Syria, Jordan, Lebanon, Palestine (Babylonian/Assyrian)
  'levant': [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول'
  ],
};

// Locale to region mapping
const _localeToRegion = {
  'AR_TN': 'maghreb',
  'AR_DZ': 'maghreb',
  'AR_MA': 'morocco',
  'AR_EG': 'egypt_gulf',
  'AR_SD': 'egypt_gulf',
  'AR_SA': 'egypt_gulf',
  'AR_AE': 'egypt_gulf',
  'AR_KW': 'egypt_gulf',
  'AR_BH': 'egypt_gulf',
  'AR_QA': 'egypt_gulf',
  'AR_OM': 'egypt_gulf',
  'AR_YE': 'egypt_gulf',
  'AR_IQ': 'levant',
  'AR_SY': 'levant',
  'AR_JO': 'levant',
  'AR_LB': 'levant',
  'AR_PS': 'levant',
};

extension MawaqitDateUtils on DateTime {
  String formatIntoMawaqitFormat({String local = 'en'}) {
    final isArabic = local.toLowerCase() == 'ar' || local.toUpperCase().startsWith('AR_');
    final isFrench = local.toLowerCase() == 'fr' || local.toUpperCase().startsWith('FR_');
    final isKurdish = local.toLowerCase() == 'ku' || local.toUpperCase().startsWith('KU_');

    var formatter = isKurdish
        ? MawaqitDateFormat('EEEE، dd MMMM، yyyy', local)
        : (isArabic || isFrench)
            ? MawaqitDateFormat('EEEE, dd MMMM, yyyy', local)
            : MawaqitDateFormat('EEEE, MMMM dd, yyyy', local);

    // Apply region-specific month names pour les locales arabes
    final region = _localeToRegion[local.toUpperCase()];
    if (region != null && _arabicMonthsByRegion[region] != null) {
      formatter.dateSymbols.MONTHS = _arabicMonthsByRegion[region]!;
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
