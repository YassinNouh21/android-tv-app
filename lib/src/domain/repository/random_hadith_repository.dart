import '../model/random_hadith_model.dart';

abstract class RandomHadithRepository {
  Future<RandomHadithModel> getRandomHadith({required String language});
  Future<void> fetchAndCacheHadith(String language);
  Future<void> ensureHadithsAreCached(String language);
}
