import 'package:flutter_svg/svg.dart';
import 'package:mawaqit/src/domain/model/quran/moshaf_type_model.dart';

abstract class QuranReadingRepository {
  Future<int> getLastReadPage({MoshafType? moshafType});
  Future<void> saveLastReadPage(int page, {MoshafType? moshafType});
  Future<List<SvgPicture>> loadAllSvgs(MoshafType moshafType);
}
