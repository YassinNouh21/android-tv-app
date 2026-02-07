import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mawaqit_tv_l10n/mawaqit_tv_l10n.dart';
import 'package:mawaqit/const/resource.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/pages/home/widgets/AboveSalahBar.dart';
import 'package:mawaqit/src/widgets/display_text_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:provider/provider.dart';

import '../../../const/constants.dart';
import '../widgets/salah_items/responsive_mini_salah_bar_turkish_widget.dart';

class AzkarLists {
  static List<String> getAfterAsrList(MawaqitTvLocalizations tr) => [
        tr.azkarList7,
        tr.azkarList10,
        tr.azkarList11,
        tr.azkarList12,
        tr.azkarList13,
        tr.azkarList14,
      ];

  static List<String> getAfterFajrList(MawaqitTvLocalizations tr) => [
        tr.azkarList7,
        tr.azkarList8,
        tr.azkarList9,
        tr.azkarList10,
        tr.azkarList11,
        tr.azkarList12,
        tr.azkarList13,
      ];

  static List<String> getRegularList(MawaqitTvLocalizations tr) => [
        tr.azkarList0, // أَسْـتَغْفِرُ الله 3x + اللّهُـمَّ أَنْـتَ السَّلامُ
        tr.azkarList6, // لا إِلَٰهَ إلاّ اللّهُ وحدَهُ لا شريكَ لهُ + اللّهُـمَّ لا مانِعَ لِما أَعْطَـيْت
        tr.azkarList1, // سُـبْحانَ اللهِ 33x، والحَمْـدُ لله 33x، واللهُ أكْـبَر 33x + لا إِلَٰهَ إلاّ اللّهُ
        tr.azkarList5, // آية الكرسي - ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ ٱلۡحَيُّ ٱلۡقَيُّومُۚ
        tr.azkarList4, // سورة الإخلاص - قُلۡ هُوَ ٱللَّهُ أَحَدٌ
        tr.azkarList3, // سورة الفلق - قُلۡ أَعُوذُ بِرَبِّ ٱلۡفَلَقِ
        tr.azkarList2, // سورة الناس - قُلۡ أَعُوذُ بِرَبِّ ٱلنَّاسِ
      ];
}

class AfterSalahAzkar extends StatefulWidget {
  AfterSalahAzkar({
    Key? key,
    this.onDone,
    this.azkarTitle = AzkarConstant.kAzkarAfterPrayer,
    this.isAfterAsrOrFajr = false,
    this.isAfterAsr = false,
  }) : super(key: key);

  final VoidCallback? onDone;
  final String azkarTitle;
  final bool isAfterAsrOrFajr;
  final bool isAfterAsr;
  @override
  State<AfterSalahAzkar> createState() => _AfterSalahAzkarState();
}

class _AfterSalahAzkarState extends State<AfterSalahAzkar> {
  int activeHadith = 0;
  Timer? _timer;

  final arabicLocal = MawaqitTvLocalizationsAr();

  /// Get the number of items in the current azkar list
  int get _listLength {
    if (!widget.isAfterAsrOrFajr) return 7; // Regular list
    return widget.isAfterAsr ? 6 : 7; // Asr=6 items, Fajr=7 items
  }

  String getItem(MawaqitTvLocalizations tr, int index) {
    if (!widget.isAfterAsrOrFajr) {
      return AzkarLists.getRegularList(tr)[index % 7];
    }

    final list = widget.isAfterAsr ? AzkarLists.getAfterAsrList(tr) : AzkarLists.getAfterFajrList(tr);

    return list[index % list.length];
  }

  String arabicItem(int index) => getItem(arabicLocal, index);

  String translatedItem(int index) => getItem(S.of(context), index);

  int _getDuration() {
    // Index 0 and index 3 get 30 seconds, others get 20 seconds
    final index = activeHadith % _listLength;
    return (index == 0 || index == 3) ? 30 : 20;
  }

  void _scheduleNext() {
    _timer = Timer(Duration(seconds: _getDuration()), () {
      if (!mounted) return;

      if (activeHadith >= _listLength - 1) {
        widget.onDone?.call();
        return;
      }

      setState(() => activeHadith++);
      _scheduleNext();
    });
  }

  @override
  void initState() {
    super.initState();
    final mosqueManager = context.read<MosqueManager>();

    if (mosqueManager.mosqueConfig?.duaAfterPrayerEnabled == false) {
      Future.delayed(Duration(milliseconds: 80), widget.onDone);
    } else {
      _scheduleNext();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translatedHadith = translatedItem(activeHadith);
    final arabicHadith = arabicItem(activeHadith);
    final mosqueProvider = context.read<MosqueManager>();

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(R.ASSETS_BACKGROUNDS_ISLAMIC_CONTENT_BACKGROUND_WEBP),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 10),
          AboveSalahBar(),
          Expanded(
            child: DisplayTextWidget(
              title: widget.azkarTitle,
              arabicText: arabicHadith,
              translatedText: widget.isAfterAsrOrFajr ? null : translatedHadith,
            ),
          ),
          mosqueProvider.times!.isTurki ? ResponsiveMiniSalahBarTurkishWidget() : ResponsiveMiniSalahBarWidget(),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
