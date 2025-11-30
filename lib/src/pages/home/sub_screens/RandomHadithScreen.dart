import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/const/resource.dart';
import 'package:mawaqit/i18n/AppLanguage.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/helpers/StringUtils.dart';
import 'package:mawaqit/src/pages/home/widgets/AboveSalahBar.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_turkish_widget.dart';
import 'package:mawaqit/src/pages/home/widgets/salah_items/responsive_mini_salah_bar_widget.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/state_management/random_hadith/random_hadith_notifier.dart';
import 'package:mawaqit/src/widgets/display_text_widget.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';

class RandomHadithScreen extends ConsumerStatefulWidget {
  const RandomHadithScreen({Key? key, this.onDone}) : super(key: key);

  final VoidCallback? onDone;

  @override
  ConsumerState<RandomHadithScreen> createState() => _RandomHadithScreenState();
}

class _RandomHadithScreenState extends ConsumerState<RandomHadithScreen> {
  String? hadith;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      log('random_hadith: RandomHadithScreen initState -> ${context.read<AppLanguage>().hadithLanguage}');

      final mosqueManager = context.read<MosqueManager>();
      // Use the proper method that checks both local settings and API configuration
      final hadithLanguage = await context.read<AppLanguage>().getHadithLanguage(mosqueManager);

      if (!mounted) return;

      log('random_hadith: RandomHadithScreen resolved hadithLanguage: $hadithLanguage');
      ref.read(randomHadithNotifierProvider.notifier).getRandomHadith(language: hadithLanguage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mosqueManager = context.watch<MosqueManager>();
    final hadithState = ref.watch(randomHadithNotifierProvider);
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(R.ASSETS_BACKGROUNDS_ISLAMIC_CONTENT_BACKGROUND_WEBP),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: AboveSalahBar(),
          ),
          Expanded(
            child: hadithState.when(
              data: (hadith) {
                // Handle empty hadith - show fallback UI and skip to next screen
                if (hadith.hadith.isEmpty) {
                  // Schedule onDone callback after build completes to skip this screen
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onDone?.call();
                  });

                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: Colors.grey,
                            size: 5.h,
                          ),
                          SizedBox(height: 1.5.h),
                          Text(
                            S.of(context).backendError,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14.sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final languageCode = hadith.language.isEmpty ? 'ar' : hadith.language;
                return DisplayTextWidget.hadith(
                  translatedText: hadith.hadith,
                  textDirection: StringManager.getTextDirectionOfLocal(
                    Locale(languageCode),
                  ),
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) {
                widget.onDone?.call();
                return Center(
                  child: Text('Error: $error'),
                );
              },
            ),
          ),
          (mosqueManager.times?.isTurki ?? false)
              ? ResponsiveMiniSalahBarTurkishWidget()
              : ResponsiveMiniSalahBarWidget(),
          SizedBox(height: 10),
        ],
      ),
    );
  }
}
