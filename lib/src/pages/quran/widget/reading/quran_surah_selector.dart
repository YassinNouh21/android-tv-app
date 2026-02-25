import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/state_management/quran/reading/quran_reading_notifer.dart';
import 'package:sizer/sizer.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class SurahSelectorWidget extends ConsumerWidget {
  final bool isPortrait;
  final FocusNode focusNode;
  final bool isThereCurrentDialogShowing;

  const SurahSelectorWidget({
    super.key,
    required this.isPortrait,
    required this.focusNode,
    required this.isThereCurrentDialogShowing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quranReadingState = ref.watch(quranReadingNotifierProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final topPosition = screenHeight * 0.015; // 1.5% of screen height

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: Center(
        child: quranReadingState.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => const SizedBox.shrink(),
          data: (state) => Material(
            color: Colors.transparent,
            child: InkWell(
              focusNode: focusNode,
              onTap: () {
                if (!isThereCurrentDialogShowing) {
                  ref.read(quranReadingNotifierProvider.notifier).getAllSuwarPage();
                  _showSurahSelector(context, ref);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Builder(
                builder: (context) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6), // Increased opacity for better visibility
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      state.currentSurahName,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSurahSelector(BuildContext context, WidgetRef ref) {
    final AutoScrollController controller = AutoScrollController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final size = MediaQuery.of(context).size;
        final needsRotation = isPortrait && size.width > size.height;

        return RotatedBox(
          quarterTurns: needsRotation ? -1 : 0,
          child: AlertDialog(
            title: Text(
              S.of(context).surahSelector,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: Container(
              width: double.maxFinite,
              height: size.height * 0.8,
            child: Consumer(
              builder: (context, ref, _) {
                final suwarState = ref.watch(quranReadingNotifierProvider);
                return suwarState.when(
                  loading: () => Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (quranState) {
                    final suwar = quranState.suwar;
                    final currentSurahIndex =
                        suwar.indexWhere((element) => element.name == quranState.currentSurahName);

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.scrollToIndex(currentSurahIndex, preferPosition: AutoScrollPosition.begin);
                    });

                    // Determine if we're in portrait or landscape mode
                    // Check both device orientation and software rotation (isPortrait)
                    final deviceOrientation = MediaQuery.of(context).orientation;
                    final isActuallyPortrait = (deviceOrientation == Orientation.portrait && !isPortrait) ||
                        (deviceOrientation == Orientation.landscape && isPortrait);

                    return GridView.builder(
                      controller: controller,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 2.5 / 1,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: suwar.length,
                      itemBuilder: (BuildContext context, int index) {
                        final surah = suwar[index];

                        // Calculate the correct page based on orientation
                        final int page;
                        if (isActuallyPortrait) {
                          // Portrait: Show one page at a time, use exact start page
                          page = surah.startPage - 1;
                        } else {
                          // Landscape: Show two pages at a time, adjust for even pages
                          page = surah.startPage % 2 == 0 ? surah.startPage - 1 : surah.startPage;
                        }

                        return AutoScrollTag(
                          key: ValueKey(index),
                          controller: controller,
                          index: index,
                          child: InkWell(
                            autofocus: index == currentSurahIndex,
                            onTap: () {
                              ref.read(quranReadingNotifierProvider.notifier).updatePage(
                                    page,
                                    isPortairt: isActuallyPortrait,
                                  );
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              height: 40.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6.0),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (surah.arabicName != surah.name)
                                    Text(
                                      surah.arabicName,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  if (surah.arabicName != surah.name) SizedBox(height: 1),
                                  Text(
                                    "${surah.id}- ${surah.name}",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 8.sp,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
        );
      },
    );
  }
}
