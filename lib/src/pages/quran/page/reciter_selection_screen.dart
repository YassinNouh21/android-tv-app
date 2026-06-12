import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_styled_toast/flutter_styled_toast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mawaqit/const/resource.dart';
import 'package:mawaqit/src/helpers/connectivity_provider.dart';
import 'package:mawaqit/src/models/address_model.dart';
import 'package:mawaqit/src/pages/quran/page/schedule_screen.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/services/theme_manager.dart';
import 'package:provider/provider.dart' as provider;
import 'package:mawaqit/src/domain/model/quran/surah_model.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_notifier.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_state.dart';
import 'package:mawaqit/src/state_management/quran/recite/quran_audio_player_notifier.dart';
import 'package:mawaqit/src/state_management/quran/recite/recite_notifier.dart';
import 'package:mawaqit/src/state_management/quran/recite/recite_state.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_notifier.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/audio_control_state.dart';
import 'package:mawaqit/src/state_management/quran/schedule_listening/schedule_listening_notifier.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sizer/sizer.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/pages/quran/widget/reciter_list_view.dart';
import 'package:mawaqit/src/pages/quran/widget/reciter_error_widget.dart';
import '../reading/quran_reading_screen.dart';
import 'package:mawaqit/src/routes/routes_constant.dart';

class AudioControlWidget extends ConsumerWidget {
  final double buttonSize;
  final double iconSize;
  final FocusNode focusNode;

  const AudioControlWidget({
    Key? key,
    required this.buttonSize,
    required this.iconSize,
    required this.focusNode,
  }) : super(key: key);

  bool _isWithinScheduledTime(TimeOfDay startTime, TimeOfDay endTime) {
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    }
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityProvider);

    return ref.watch(audioControlProvider).when(
          data: (state) {
            final scheduleState = ref.watch(scheduleProvider);

            return scheduleState.when(
              data: (schedule) {
                final isWithinTime = _isWithinScheduledTime(schedule.startTime, schedule.endTime);
                final hasInternetConnection =
                    connectivityStatus.hasValue && connectivityStatus.value == ConnectivityStatus.connected;

                final shouldShow = schedule.isScheduleEnabled && isWithinTime && hasInternetConnection;

                if (!shouldShow) return const SizedBox.shrink();

                return SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: FloatingActionButton(
                    focusNode: focusNode,
                    focusColor: Theme.of(context).primaryColor,
                    backgroundColor: state.status == AudioStatus.playing
                        ? Theme.of(context).primaryColor
                        : Colors.black.withOpacity(.5),
                    child: Icon(
                      color: Colors.white,
                      state.status == AudioStatus.playing ? Icons.pause : Icons.play_arrow,
                      size: iconSize,
                    ),
                    onPressed: () {
                      ref.read(audioControlProvider.notifier).togglePlayback();
                    },
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => const SizedBox.shrink(),
        );
  }
}

class ReciterSelectionScreen extends ConsumerStatefulWidget {
  final String surahName;
  static double horizontalPadding = 3.w;

  const ReciterSelectionScreen({super.key, required this.surahName});

  const ReciterSelectionScreen.withoutSurahName({super.key}) : surahName = '';

  @override
  createState() => _ReciterSelectionScreenState();
}

class _ReciterSelectionScreenState extends ConsumerState<ReciterSelectionScreen> with SingleTickerProviderStateMixin {
  bool isKeyboardVisible = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _reciterScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  late FocusScopeNode favoritesListFocusNode;
  late FocusScopeNode allRecitersListFocusNode;
  late FocusScopeNode changeReadingModeFocusNode;
  late FocusScopeNode searchListFocusNode;
  late FocusNode searchFocusScopeNode;
  late FocusNode changeIntoReadingMode;
  late FocusNode playPauseSchedule;
  late FocusNode errorRetryFocusNode;

  late StreamSubscription<bool> keyboardSubscription;

  bool _isSearching = false;
  bool _foundReciters = false;

  Map<String, dynamic>? _savedSession;
  bool _isResuming = false;
  late FocusNode resumeBannerFocusNode;

  @override
  void initState() {
    super.initState();
    _initializeFocusNodes();
    _setupKeyboardListener();
  }

  @override
  void dispose() {
    _disposeFocusNodes();
    keyboardSubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeFocusNodes() {
    searchFocusScopeNode = FocusNode(debugLabel: 'search_focus_node');
    favoritesListFocusNode = FocusScopeNode(debugLabel: 'favorites_list_focus_scope_node');
    allRecitersListFocusNode = FocusScopeNode(debugLabel: 'all_reciters_list_focus_scope_node');
    changeReadingModeFocusNode = FocusScopeNode(debugLabel: 'change_reading_mode_focus_scope_node');

    changeIntoReadingMode = FocusNode(debugLabel: 'change_into_reading_mode_focus_node');
    playPauseSchedule = FocusNode(debugLabel: 'pla_pause_schedule');
    searchListFocusNode = FocusScopeNode(debugLabel: 'search_list_focus_scope_node');
    errorRetryFocusNode = FocusNode(debugLabel: 'error_retry_focus_node');
    resumeBannerFocusNode = FocusNode(debugLabel: 'resume_banner_focus_node');

    _refreshSavedSession();

    // Setup search field key handler for navigation
    searchFocusScopeNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final state = ref.read(reciteNotifierProvider);
        // If there's an error, navigate to the retry button
        if (state.hasError) {
          errorRetryFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        if (_savedSession != null) {
          resumeBannerFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(reciteNotifierProvider.notifier);
      }
      _setInitialFocus();
    });
  }

  Future<void> _refreshSavedSession() async {
    final session = await QuranAudioPlayer.getLastPlaybackSession();
    if (mounted) setState(() => _savedSession = session);
  }

  void _disposeFocusNodes() {
    searchFocusScopeNode.dispose();
    favoritesListFocusNode.dispose();
    allRecitersListFocusNode.dispose();
    changeReadingModeFocusNode.dispose();
    searchListFocusNode.dispose();
    errorRetryFocusNode.dispose();
    resumeBannerFocusNode.dispose();
  }

  void _setupKeyboardListener() {
    var keyboardVisibilityController = KeyboardVisibilityController();
    keyboardSubscription = keyboardVisibilityController.onChange.listen((bool visible) {
      setState(() {
        isKeyboardVisible = visible;
      });
    });
  }

  void _setInitialFocus() {
    if (_hasFavorites()) {
      favoritesListFocusNode.requestFocus();
    } else {
      allRecitersListFocusNode.requestFocus();
    }
  }

  bool _hasFavorites() {
    return ref.read(reciteNotifierProvider).maybeWhen(
          data: (reciterState) => reciterState.favoriteReciters.isNotEmpty,
          orElse: () => false,
        );
  }

  void _navigateToReading() {
    final userPrefs = provider.Provider.of<UserPreferencesManager>(context, listen: false);
    ref.read(quranNotifierProvider.notifier).selectModel(QuranMode.reading);
    if (userPrefs.appMode == AppMode.quran) {
      // In Quran mode, pop back to the reading screen if possible
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        // Fallback: came here via pushReplacement, restart to get back to quran mode root
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } else {
      Navigator.pushReplacementNamed(context, Routes.quranReading);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonSize = MediaQuery.of(context).size.width * 0.07;
    final iconSize = buttonSize * 0.5;
    final spacerWidth = buttonSize * 0.25;

    _setupFocusNodeCallbacks();

    return WillPopScope(
      onWillPop: () async {
        final userPrefs = provider.Provider.of<UserPreferencesManager>(context, listen: false);
        if (userPrefs.appMode == AppMode.quran) {
          // In Quran mode, just pop back to quran reading
          ref.read(quranNotifierProvider.notifier).selectModel(QuranMode.reading);
          return true;
        }
        if (!Navigator.canPop(context)) {
          _navigateToReading();
          return false;
        }
        // Reset quran mode and allow normal pop
        ref.read(quranNotifierProvider.notifier).selectModel(QuranMode.none);
        return true;
      },
      child: Scaffold(
        key: _scaffoldKey,
        resizeToAvoidBottomInset: true,
        floatingActionButton: _buildFloatingColumn(spacerWidth, buttonSize, iconSize, context),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  void _setupFocusNodeCallbacks() {
    favoritesListFocusNode.onKey = _handleFavoritesListKeyEvent;
    allRecitersListFocusNode.onKey = _handleAllRecitersListKeyEvent;
    changeReadingModeFocusNode.onKey = _handleChangeReadingModeKeyEvent;
    changeIntoReadingMode.onKey = _handleChangeIntoReadingModeKeyEvent;
    playPauseSchedule.onKey = _handlePlayPauseScheduleKeyEvent;
    searchListFocusNode.onKey = _handleSearchListKeyEvent;
    resumeBannerFocusNode.onKey = _handleResumeBannerKeyEvent;
  }

  KeyEventResult _handleResumeBannerKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        searchFocusScopeNode.requestFocus();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_hasFavorites()) {
          favoritesListFocusNode.requestFocus();
        } else {
          allRecitersListFocusNode.requestFocus();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter) {
        if (_savedSession != null && !_isResuming) {
          try {
            final surahJson = _savedSession!['surahJson'] as String;
            final surah = SurahModel.fromJson(jsonDecode(surahJson) as Map<String, dynamic>);
            _onResumeTap(_savedSession!, surah);
          } catch (_) {}
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleFavoritesListKeyEvent(FocusNode node, RawKeyEvent event) {
    if (!mounted) return KeyEventResult.ignored; // Check if the widget is still mounted
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        allRecitersListFocusNode.requestFocus();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_savedSession != null) {
          resumeBannerFocusNode.requestFocus();
        } else {
          searchFocusScopeNode.requestFocus();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleAllRecitersListKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_hasFavorites()) {
          favoritesListFocusNode.requestFocus();
        } else if (_savedSession != null) {
          resumeBannerFocusNode.requestFocus();
        } else {
          searchFocusScopeNode.requestFocus();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        changeReadingModeFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleChangeReadingModeKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Check if there's an error state first
        final state = ref.read(reciteNotifierProvider);
        if (state.hasError) {
          errorRetryFocusNode.requestFocus();
          return KeyEventResult.handled;
        }

        if (_foundReciters && !ref.read(reciteNotifierProvider.notifier).isQueryEmpty) {
          searchListFocusNode.requestFocus();
        } else {
          if (_hasFavorites()) {
            favoritesListFocusNode.requestFocus();
          } else {
            allRecitersListFocusNode.requestFocus();
          }
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Check if there's an error state first
        final state = ref.read(reciteNotifierProvider);
        if (state.hasError) {
          errorRetryFocusNode.requestFocus();
          return KeyEventResult.handled;
        }

        if (!_foundReciters && !changeIntoReadingMode.hasFocus) {
          searchFocusScopeNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleChangeIntoReadingModeKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        // Check if there's an error state
        final state = ref.read(reciteNotifierProvider);
        if (state.hasError) {
          errorRetryFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        // Otherwise go to search or reciters list
        searchFocusScopeNode.requestFocus();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        // Try to focus on the play/pause schedule button if it exists
        if (playPauseSchedule.canRequestFocus) {
          playPauseSchedule.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handlePlayPauseScheduleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        changeIntoReadingMode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSearchListKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        searchFocusScopeNode.requestFocus();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        changeReadingModeFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  AppBar _buildAppBar() {
    final fontScale = provider.Provider.of<UserPreferencesManager>(context).appFontSizeScale;
    return AppBar(
      toolbarHeight: 5.h,
      backgroundColor: Color(0xFF28262F),
      title: SizedBox(
        height: 4.h,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              S.of(context).chooseReciter,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp * fontScale,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: Colors.white,
        ),
        onPressed: () {
          final userPrefs = provider.Provider.of<UserPreferencesManager>(context, listen: false);
          if (userPrefs.appMode == AppMode.quran) {
            // In Quran mode, just pop back to quran reading
            ref.read(quranNotifierProvider.notifier).selectModel(QuranMode.reading);
            Navigator.pop(context);
          } else if (!Navigator.canPop(context)) {
            _navigateToReading();
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(R.ASSETS_BACKGROUNDS_QURAN_BACKGROUND_PNG),
          fit: BoxFit.cover,
        ),
        gradient: ThemeNotifier.quranBackground(),
      ),
      child: Column(
        children: [
          SizedBox(height: 0.5.h),
          Expanded(
            flex: 2,
            child: _buildSearchField(),
          ),
          isKeyboardVisible
              ? const SizedBox.shrink()
              : Expanded(
                  flex: 10,
                  child: ref.watch(reciteNotifierProvider).when(
                        data: (reciterState) => _buildReciterList(reciterState),
                        loading: () => Column(
                          children: [
                            SizedBox(height: 1.h),
                            _buildAllRecitersHeader(),
                            SizedBox(height: 1.h),
                            _buildReciterListShimmer(true),
                            SizedBox(height: 20),
                            _buildReciterListShimmer(true),
                          ],
                        ),
                        error: (error, stackTrace) => ReciterErrorWidget(
                          error: error,
                          focusNode: errorRetryFocusNode,
                          onNavigateUp: () => searchFocusScopeNode.requestFocus(),
                          onNavigateDown: () => changeReadingModeFocusNode.requestFocus(),
                        ),
                      ),
                ),
        ],
      ),
    );
  }

  Widget _buildReciterList(ReciteState reciterState) {
    final hasFavorites = reciterState.favoriteReciters.isNotEmpty;

    if (_isSearching) {
      return _buildSearchResults(reciterState);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedSession != null) _buildResumeBanner(),
        if (hasFavorites) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildFavoriteSection(reciterState),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildAllRecitersSection(reciterState),
            ),
          ),
        ] else ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildAllRecitersSection(reciterState),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildFavoriteSection(reciterState),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchResults(ReciteState reciterState) {
    if (reciterState.filteredReciters.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding),
            child: Text(
              S.of(context).noReciterSearchResult,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 2.h),
        FocusScope(
          node: searchListFocusNode,
          child: ReciterListView(
            reciters: reciterState.filteredReciters,
            isAtBottom: false,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFavoriteSection(ReciteState reciterState) {
    return [
      SizedBox(height: 0.5.h),
      _buildFavoritesHeader(),
      SizedBox(height: 0.5.h),
      if (reciterState.favoriteReciters.isEmpty)
        Expanded(
          child: _buildEmptyFavorites(),
        )
      else
        Expanded(
          child: FocusScope(
            node: favoritesListFocusNode,
            autofocus: _hasFavorites(),
            child: ReciterListView(
              reciters: reciterState.favoriteReciters,
              isAtBottom: !_hasFavorites(),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildAllRecitersSection(ReciteState reciterState) {
    return [
      SizedBox(height: 0.8.h),
      Expanded(
        flex: 1,
        child: _buildAllRecitersHeader(),
      ),
      SizedBox(height: 0.8.h),
      Expanded(
        flex: 5,
        child: FocusScope(
          node: allRecitersListFocusNode,
          autofocus: _hasFavorites(),
          child: ReciterListView(
            reciters: reciterState.reciters,
            isAtBottom: _hasFavorites(),
          ),
        ),
      ),
    ];
  }

  void showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Widget _buildFloatingColumn(double spacerWidth, double buttonSize, double iconSize, BuildContext context) {
    return FocusScope(
      node: changeReadingModeFocusNode,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ref.watch(reciteNotifierProvider).whenOrNull(
                    data: (reciter) => Padding(
                      padding: EdgeInsets.only(bottom: spacerWidth),
                      child: SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: FloatingActionButton(
                          autofocus: changeReadingModeFocusNode.hasFocus,
                          // it is used here because at change_reading_mode it will break due to up keybind when no result in the search
                          heroTag: 'schedule',
                          focusColor: Theme.of(context).focusColor,
                          backgroundColor: Colors.black.withOpacity(.5),
                          child: Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: iconSize,
                          ),
                          onPressed: () async {
                            // Check internet connection before showing dialog
                            await ref.read(connectivityProvider.notifier).checkInternetConnection();

                            // Get the latest connectivity status after checking
                            final updatedConnectivity = ref.read(connectivityProvider);
                            final isConnected = updatedConnectivity.hasValue &&
                                updatedConnectivity.value == ConnectivityStatus.connected;

                            if (isConnected) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) => ScheduleScreen(reciterList: reciter.reciters),
                              );
                            } else {
                              showToast(S.of(context).scheduleInOnlineMode);
                            }
                          },
                        ),
                      ),
                    ),
                  ) ??
              const SizedBox.shrink(),
          Padding(
            padding: EdgeInsets.only(bottom: spacerWidth),
            child: SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: FloatingActionButton(
                heroTag: 'change_reading_mode',
                focusNode: changeIntoReadingMode,
                focusColor: Theme.of(context).primaryColor,
                backgroundColor: Colors.black.withOpacity(.5),
                child: Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: iconSize,
                ),
                onPressed: () async {
                  _navigateToReading();
                },
              ),
            ),
          ),
          AudioControlWidget(
            buttonSize: buttonSize,
            iconSize: iconSize,
            focusNode: playPauseSchedule,
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesHeader() {
    final fontScale = provider.Provider.of<UserPreferencesManager>(context).appFontSizeScale;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite,
              color: Theme.of(context).primaryColor,
              size: 12.sp * fontScale,
            ),
            SizedBox(width: 12),
            AutoSizeText(
              S.of(context).favorites,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontSize: 12.sp * fontScale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllRecitersHeader() {
    final fontScale = provider.Provider.of<UserPreferencesManager>(context).appFontSizeScale;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Row(
          children: [
            SizedBox(width: 8),
            AutoSizeText(
              S.of(context).allReciters,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp * fontScale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFavorites() {
    final fontScale = provider.Provider.of<UserPreferencesManager>(context).appFontSizeScale;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding, vertical: 4),
      padding: EdgeInsets.all(4.sp),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            color: Colors.white54,
            size: 22.sp,
          ),
          SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: Text(
                S.of(context).noFavoriteReciters,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp * fontScale,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding, vertical: 10),
      child: TextField(
        maxLines: 1,
        focusNode: searchFocusScopeNode,
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _isSearching = value.isNotEmpty;
          });
          ref.read(reciteNotifierProvider.notifier).setSearchQuery(value);
        },
        onSubmitted: (value) {
          if (value.isEmpty) {
            setState(() {
              _isSearching = false;
              _foundReciters = false;
            });
            _setInitialFocus();
            return;
          }

          final state = ref.read(reciteNotifierProvider);
          state.maybeWhen(
            data: (reciterState) {
              setState(() {
                _foundReciters = reciterState.filteredReciters.isNotEmpty;
              });

              if (_foundReciters) {
                searchListFocusNode.requestFocus();
              } else {
                // No results found - focus should stay on change reading mode button
                changeReadingModeFocusNode.requestFocus();
              }
            },
            orElse: () {
              setState(() {
                _foundReciters = false;
              });
              changeReadingModeFocusNode.requestFocus();
            },
          );
        },
        style: TextStyle(color: Colors.white, fontSize: 10.sp),
        decoration: InputDecoration(
          hintText: S.of(context).searchForReciter,
          hintStyle: TextStyle(color: Colors.white70),
          prefixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            child: Icon(
              Icons.search,
              color: Colors.white70,
              size: 12.sp,
            ),
          ),
          filled: true,
          fillColor: Colors.white24,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 3.0),
            borderRadius: BorderRadius.circular(10.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.0),
            borderRadius: BorderRadius.circular(10.0),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildResumeBanner() {
    final session = _savedSession!;
    final positionMs = session['positionMs'] as int;
    final surahJson = session['surahJson'] as String;
    late final SurahModel surah;
    try {
      surah = SurahModel.fromJson(jsonDecode(surahJson) as Map<String, dynamic>);
    } catch (_) {
      return const SizedBox.shrink();
    }
    final minutes = (positionMs ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((positionMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final positionLabel = '$minutes:$seconds';

    final reciterId = session['reciterId'] as String;
    final reciterState = ref.read(reciteNotifierProvider).valueOrNull;
    final allReciters = [...?reciterState?.reciters, ...?reciterState?.favoriteReciters];
    final reciterName = allReciters.firstWhereOrNull((r) => r.id.toString() == reciterId)?.name ?? '';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding, vertical: 0.5.h),
      child: Focus(
        focusNode: resumeBannerFocusNode,
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return InkWell(
              focusColor: Colors.transparent,
              onTap: _isResuming ? null : () => _onResumeTap(session, surah),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: isFocused ? Theme.of(context).primaryColor : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isFocused ? Theme.of(context).primaryColor : Colors.white24,
                    width: isFocused ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    _isResuming
                        ? SizedBox(
                            width: 18.sp,
                            height: 18.sp,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(Icons.play_circle_filled, color: Colors.white, size: 18.sp),
                    SizedBox(width: 1.5.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            S.of(context).continueListening,
                            style: TextStyle(color: Colors.white70, fontSize: 9.sp),
                          ),
                          Text(
                            '${surah.name}  •  $reciterName  •  $positionLabel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 10.sp),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _onResumeTap(Map<String, dynamic> session, SurahModel surah) async {
    final reciterState = ref.read(reciteNotifierProvider).valueOrNull;
    if (reciterState == null) return;

    final reciterId = session['reciterId'] as String;
    final moshafId = session['moshafId'] as String;

    final allReciters = [...reciterState.reciters, ...reciterState.favoriteReciters];
    final reciter = allReciters.firstWhereOrNull((r) => r.id.toString() == reciterId);
    if (reciter == null) return;

    final moshaf = reciter.moshaf.firstWhereOrNull((m) => m.id.toString() == moshafId);
    if (moshaf == null) return;

    setState(() => _isResuming = true);
    try {
      await ref.read(quranNotifierProvider.notifier).getSuwarByReciter(selectedMoshaf: moshaf);
      final suwar = ref.read(quranNotifierProvider).valueOrNull?.suwar;
      if (suwar == null || suwar.isEmpty) return;

      ref.read(quranPlayerNotifierProvider.notifier).initialize(
            moshaf: moshaf,
            surah: surah,
            suwar: suwar,
            reciterId: reciterId,
          );

      if (mounted) {
        await Navigator.pushNamed(
          context,
          Routes.quranPlayer,
          arguments: {
            'reciterId': reciterId,
            'selectedMoshaf': moshaf,
            'surah': surah,
          },
        );
        // Refresh saved session after returning from player
        await _refreshSavedSession();
      }
    } finally {
      if (mounted) setState(() => _isResuming = false);
    }
  }

  Widget _buildReciterListShimmer(bool isDarkMode) {
    return Container(
      height: 16.h,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: ReciterSelectionScreen.horizontalPadding),
        scrollDirection: Axis.horizontal,
        itemCount: 20,
        itemBuilder: (context, index) {
          return Container(
            width: 25.w,
            margin: EdgeInsets.only(right: 16),
            child: Shimmer.fromColors(
              baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
