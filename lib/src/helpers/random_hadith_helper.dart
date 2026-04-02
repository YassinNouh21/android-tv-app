import 'package:mawaqit/src/const/constants.dart';

class RandomHadithHelper {
  /// Converts language format from underscore to dash (e.g., 'fr_ar' -> 'fr-ar')
  static String changeLanguageFormat(String language) {
    return language.replaceAll(
      LanguageConstants.separatorUnderscore,
      LanguageConstants.separatorDash,
    );
  }

  /// Checks if the language is bilingual (e.g., 'fr-ar' or 'fr_ar')
  static bool isTwoLanguage(String language) {
    return language.contains(LanguageConstants.separatorDash) ||
        language.contains(LanguageConstants.separatorUnderscore);
  }

  /// Splits bilingual language into individual languages and converts to lowercase
  static List<String> getLanguage(String language) {
    return language.split(RegExp(LanguageConstants.separatorPattern)).map((lang) => lang.toLowerCase()).toList();
  }
}
