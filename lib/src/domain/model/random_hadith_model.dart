/// Model representing a random hadith with its language.
///
/// For bilingual language settings (e.g., 'fr-ar'), the [language] field
/// contains the actual language of the hadith text (either 'fr' or 'ar'),
/// not the combined language code.
class RandomHadithModel {
  final String hadith;
  final String language;

  const RandomHadithModel({
    required this.hadith,
    required this.language,
  });
}
