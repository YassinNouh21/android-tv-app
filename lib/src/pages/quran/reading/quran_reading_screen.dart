import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/pages/quran/reading/widget/quran_floating_action_buttons.dart';
import 'package:mawaqit/src/pages/quran/widget/reading/quran_reading_widgets.dart';
import 'package:mawaqit/src/pages/quran/widget/reading/quran_surah_selector.dart';

import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/state_management/quran/download_quran/download_quran_notifier.dart';
import 'package:mawaqit/src/state_management/quran/download_quran/download_quran_state.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_notifier.dart';
import 'package:mawaqit/src/state_management/quran/quran/quran_state.dart';
import 'package:mawaqit/src/state_management/quran/reading/auto_reading/auto_reading_notifier.dart';
import 'package:mawaqit/src/state_management/quran/reading/auto_reading/auto_reading_state.dart';
import 'package:mawaqit/src/state_management/quran/reading/quran_reading_notifer.dart';

import 'package:mawaqit/src/pages/quran/widget/download_quran_popup.dart';
import 'package:mawaqit/src/state_management/quran/reading/quran_reading_state.dart';
import 'package:mawaqit/src/state_management/jx11/jx11_event_notifier.dart';
import 'package:provider/provider.dart' as provider;

import 'package:mawaqit/src/pages/quran/widget/reading/quran_reading_page_selector.dart';
import 'package:mawaqit/src/routes/routes_constant.dart';
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';

abstract class QuranViewStrategy {
  Widget buildView(QuranReadingState state, WidgetRef ref, BuildContext context);

  List<Widget> buildControls(
    BuildContext context,
    QuranReadingState state,
    UserPreferencesManager userPrefs,
    bool isPortrait,
    FocusNodes focusNodes,
    Function(ScrollDirection, bool) onScroll,
    Function(BuildContext, int, int, bool) showPageSelector,
  );
}

// Helper class to organize focus nodes
class FocusNodes {
  final FocusNode backButtonNode;
  final FocusNode leftSkipNode;
  final FocusNode rightSkipNode;
  final FocusNode pageSelectorNode;
  final FocusNode switchQuranNode;
  final FocusNode surahSelectorNode;
  final FocusNode switchToPlayQuranFocusNode;
  final FocusNode switchScreenViewFocusNode;
  final FocusNode switchQuranModeNode;

  FocusNodes({
    required this.backButtonNode,
    required this.leftSkipNode,
    required this.rightSkipNode,
    required this.pageSelectorNode,
    required this.switchQuranNode,
    required this.surahSelectorNode,
    required this.switchToPlayQuranFocusNode,
    required this.switchScreenViewFocusNode,
    required this.switchQuranModeNode,
  });

  void setupFocusTraversal({required bool isPortrait, required bool settingsOrientation}) {
    if (isPortrait || settingsOrientation != true) {
      setupPortraitFocusTraversal(settingsOrientation, isPortrait);
    } else {
      setupLandscapeFocusTraversal();
    }
  }

  void setupPortraitFocusTraversal(bool settingsOrientation, bool isPortrait) {
    // Setup focus traversal for back button
    backButtonNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown && settingsOrientation == true) {
        pageSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowRight &&
          settingsOrientation == true &&
          !isPortrait) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowRight &&
          settingsOrientation != true) {
        surahSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown &&
          settingsOrientation != true &&
          !isPortrait) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Setup focus traversal for page selector node
    pageSelectorNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp && settingsOrientation == true) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
        switchQuranModeNode.requestFocus();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };

    // Setup focus traversal for switch quran node
    switchQuranNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft && settingsOrientation == true) {
        backButtonNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown && settingsOrientation == true) {
        switchToPlayQuranFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowRight &&
          settingsOrientation != true) {
        pageSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp && settingsOrientation != true) {
        backButtonNode.requestFocus();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };

    // Setup focus traversal for surah selector node
    switchToPlayQuranFocusNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp && settingsOrientation == true) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown && settingsOrientation != true) {
        switchScreenViewFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp && settingsOrientation != true) {
        surahSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    // Setup focus traversal for surah selector node
    switchScreenViewFocusNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        switchToPlayQuranFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        switchQuranModeNode.requestFocus();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
    // Setup focus traversal for surah selector node
    switchQuranModeNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        switchScreenViewFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        pageSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
  }

  void setupLandscapeFocusTraversal() {
    // Setup focus traversal for back button
    backButtonNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        leftSkipNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
        surahSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Setup focus traversal for left skip node
    leftSkipNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        backButtonNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowRight) {
        rightSkipNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        pageSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Setup focus traversal for right skip node
    rightSkipNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        leftSkipNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Setup focus traversal for page selector node
    pageSelectorNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        leftSkipNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Setup focus traversal for switch quran node
    switchQuranNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        rightSkipNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
        surahSelectorNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    // Setup focus traversal for surah selector node
    surahSelectorNode.onKey = (node, event) {
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        switchQuranNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        backButtonNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  void resetToDefaultFocus() {
    backButtonNode.requestFocus();
  }

  void dispose() {
    backButtonNode.dispose();
    leftSkipNode.dispose();
    rightSkipNode.dispose();
    pageSelectorNode.dispose();
    switchQuranNode.dispose();
    surahSelectorNode.dispose();
  }
}

class AutoScrollReadingView extends ConsumerStatefulWidget {
  final AutoScrollState autoScrollState;
  final int initialPage;
  final bool isPortrait;

  AutoScrollReadingView({
    required this.autoScrollState,
    this.initialPage = 1,
    this.isPortrait = false,
  });

  @override
  _AutoScrollReadingViewState createState() => _AutoScrollReadingViewState();
}

class _AutoScrollReadingViewState extends ConsumerState<AutoScrollReadingView> {
  late ScrollController scrollController;
  bool _isInitialized = false;
  bool _isLoading = true;
  double? _cachedItemHeight;
  Map<int, bool> _loadedPages = {};

  /// Single source of truth for item height — used for rendering, placeholders,
  /// scroll position, and cache extent. Same pattern as develop, with portrait ratio.
  double _itemHeight(Size size, double scalingFactor) {
    if (widget.isPortrait) {
      final shortSide = size.width < size.height ? size.width : size.height;
      final ratio = 1.3 + (scalingFactor - 1.0) * 0.15;
      return shortSide * ratio;
    }
    return size.height * scalingFactor;
  }

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    _initializeScrollView();
  }

  Future<void> _waitForPostFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  Future<void> _initializeScrollView() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _isInitialized = false;
      });

      await Future.microtask(() async {
        final readingState = ref.read(quranReadingNotifierProvider);

        await readingState.whenOrNull(
          data: (data) async {
            final startIndex = math.max(0, widget.initialPage - 1);
            final endIndex = math.min(data.totalPages, widget.initialPage + 1);

            for (var i = startIndex; i < endIndex; i++) {
              _loadedPages[i] = true;
            }
          },
        );
      });

      // Wait for the frame to render before jumping to the initial page
      await _waitForPostFrame();
      if (!mounted) return;

      await _jumpToInitialPage();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }

      // Set scroll controller AFTER the rebuild so the auto-scroll animation
      // doesn't fight with the initial jump position.
      await _waitForPostFrame();
      if (!mounted) return;
      ref.read(autoScrollNotifierProvider.notifier).setScrollController(scrollController);
    } catch (e, stackTrace) {
      debugPrint('[QuranReading] Initialization error: $e\n$stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _jumpToInitialPage() async {
    if (widget.initialPage <= 1) return;

    try {
      if (!mounted) return;

      final size = MediaQuery.of(context).size;
      final scalingFactor = widget.autoScrollState.fontSize;
      final itemHeight = _itemHeight(size, scalingFactor);
      _cachedItemHeight = itemHeight;

      final scrollPosition = widget.initialPage * itemHeight;
      scrollController.jumpTo(scrollPosition);
    } catch (e, stackTrace) {
      debugPrint('[QuranReading] Error jumping to initial page: $e\n$stackTrace');
    }
  }

  Widget _buildPage(int index, SvgPicture svgPicture, double scalingFactor) {
    final size = MediaQuery.of(context).size;
    final itemHeight = _itemHeight(size, scalingFactor);

    if (!_loadedPages.containsKey(index)) {
      Future.microtask(() {
        if (mounted) {
          setState(() => _loadedPages[index] = true);
        }
      });

      return SizedBox(
        width: size.width * scalingFactor,
        height: itemHeight,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: size.width * scalingFactor,
        height: itemHeight,
        child: SvgPictureWidget(
          key: ValueKey('page_$index'),
          svgPicture: svgPicture,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              S.of(context).initializingAutoReading,
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap() {
    final autoScrollNotifier = ref.read(autoScrollNotifierProvider.notifier);
    if (widget.autoScrollState.isPlaying) {
      autoScrollNotifier.pauseAutoScroll();
    } else {
      autoScrollNotifier.resumeAutoScroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scalingFactor = widget.autoScrollState.fontSize;
    final readingState = ref.watch(quranReadingNotifierProvider);
    final total = readingState.whenOrNull(data: (data) => data.totalPages) ?? 0;
    final pages = readingState.whenOrNull(data: (data) => data.svgs) ?? [];
    final itemHeight = _itemHeight(MediaQuery.of(context).size, scalingFactor);

    return Stack(
      children: [
        Container(color: Theme.of(context).scaffoldBackgroundColor),
        if (pages.isNotEmpty)
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            controller: scrollController,
            itemCount: total,
            itemExtent: itemHeight,
            cacheExtent: itemHeight * 2,
            itemBuilder: (context, index) {
              if (!_isInitialized) {
                return SizedBox(
                  height: _cachedItemHeight ?? itemHeight,
                );
              }

              return _buildPage(index, pages[index], scalingFactor);
            },
          ),
        if (_isLoading || widget.autoScrollState.isLoading) _buildLoadingIndicator(),
      ],
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    _loadedPages.clear();
    super.dispose();
  }
}

class AutoScrollViewStrategy implements QuranViewStrategy {
  final AutoScrollState autoScrollState;
  final int initialPage;
  final bool isPortrait;

  AutoScrollViewStrategy(this.autoScrollState, {this.initialPage = 1, this.isPortrait = false});

  @override
  Widget buildView(QuranReadingState state, WidgetRef ref, BuildContext context) {
    return AutoScrollReadingView(
      autoScrollState: autoScrollState,
      initialPage: initialPage,
      isPortrait: isPortrait,
    );
  }

  @override
  List<Widget> buildControls(
    BuildContext context,
    QuranReadingState state,
    UserPreferencesManager userPrefs,
    bool isPortrait,
    FocusNodes focusNodes,
    Function(ScrollDirection, bool) onScroll,
    Function(BuildContext, int, int, bool) showPageSelector,
  ) {
    return [];
  }
}

class NormalViewStrategy implements QuranViewStrategy {
  final bool isPortrait;

  NormalViewStrategy(this.isPortrait);

  @override
  Widget buildView(QuranReadingState state, WidgetRef ref, BuildContext context) {
    bool shouldShowVertical = isPortrait;

    final autoScrollState = ref.watch(autoScrollNotifierProvider);

    if (state.pageController.hasClients && !autoScrollState.isSinglePageView) {
      final targetPage = shouldShowVertical ? state.currentPage : (state.currentPage / 2).floor();
      final currentPage = state.pageController.page?.round();
      if (currentPage != null && currentPage != targetPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (state.pageController.hasClients) {
            state.pageController.jumpToPage(targetPage);
          }
        });
      }
    }

    return shouldShowVertical
        ? VerticalPageViewWidget(
            quranReadingState: state,
            key: const ValueKey('vertical'),
          )
        : HorizontalPageViewWidget(
            quranReadingState: state,
            key: const ValueKey('horizontal'),
          );
  }

  @override
  List<Widget> buildControls(
    BuildContext context,
    QuranReadingState state,
    UserPreferencesManager userPrefs,
    bool isPortrait,
    FocusNodes focusNodes,
    Function(ScrollDirection, bool) onScroll,
    Function(BuildContext, int, int, bool) showPageSelector,
  ) {
    if ((MediaQuery.of(context).orientation == Orientation.portrait && isPortrait) ||
        (MediaQuery.of(context).orientation == Orientation.portrait && !isPortrait)) {
      return [
        SurahSelectorWidget(
          isPortrait: isPortrait,
          focusNode: focusNodes.surahSelectorNode,
          isThereCurrentDialogShowing: false,
        ),
        PageNumberIndicatorWidget(
          quranReadingState: state,
          focusNode: focusNodes.pageSelectorNode,
          isPortrait: isPortrait,
          showPageSelector: showPageSelector,
        ),
        MoshafSelectorPositionedWidget(
          isPortrait: isPortrait,
          focusNode: focusNodes.switchQuranNode,
          isThereCurrentDialogShowing: false,
        ),
        BackButtonWidget(
          isPortrait: isPortrait,
          userPrefs: userPrefs,
          focusNode: focusNodes.backButtonNode,
        ),
      ];
    }

    return [
      _buildNavigationButtons(
        context,
        focusNodes,
        onScroll,
        isPortrait,
      ),
      SurahSelectorWidget(
        isPortrait: isPortrait,
        focusNode: focusNodes.surahSelectorNode,
        isThereCurrentDialogShowing: false,
      ),
      PageNumberIndicatorWidget(
        quranReadingState: state,
        focusNode: focusNodes.pageSelectorNode,
        isPortrait: isPortrait,
        showPageSelector: showPageSelector,
      ),
      MoshafSelectorPositionedWidget(
        isPortrait: isPortrait,
        focusNode: focusNodes.switchQuranNode,
        isThereCurrentDialogShowing: false,
      ),
      BackButtonWidget(
        isPortrait: isPortrait,
        userPrefs: userPrefs,
        focusNode: focusNodes.backButtonNode,
      ),
    ];
  }

  Widget _buildNavigationButtons(
    BuildContext context,
    FocusNodes focusNodes,
    Function(ScrollDirection, bool) onScroll,
    bool isPortrait,
  ) {
    return Stack(
      children: [
        LeftSwitchButtonWidget(
          focusNode: focusNodes.leftSkipNode,
          onPressed: () => onScroll(ScrollDirection.reverse, isPortrait),
        ),
        RightSwitchButtonWidget(
          focusNode: focusNodes.rightSkipNode,
          onPressed: () => onScroll(ScrollDirection.forward, isPortrait),
        ),
      ],
    );
  }
}

class _Jx11State {
  final FocusNodes focusNodes;
  final bool isPortrait;
  final bool isPhysicallyPortrait;
  const _Jx11State(this.focusNodes, this.isPortrait, this.isPhysicallyPortrait);
}

class QuranReadingScreen extends ConsumerStatefulWidget {
  const QuranReadingScreen({super.key});

  @override
  ConsumerState createState() => _QuranReadingScreenState();
}

class _QuranReadingScreenState extends ConsumerState<QuranReadingScreen> {
  late FocusNode _rightSkipButtonFocusNode;
  late FocusNode _leftSkipButtonFocusNode;
  late FocusNode _backButtonFocusNode;
  late FocusNode _switchQuranFocusNode;
  late FocusNode _switchQuranModeNode;
  late FocusNode _surahSelectorNode;
  late FocusNode _switchScreenViewFocusNode;
  late FocusNode _switchToPlayQuranFocusNode;
  late FocusNode _portraitModeBackButtonFocusNode;
  late FocusNode _portraitModeSwitchQuranFocusNode;
  late FocusNode _portraitModePageSelectorFocusNode;
  final ScrollController _gridScrollController = ScrollController();

  Orientation? _lastOrientation;
  bool? _lastEffectiveIsPortrait;

  // JX-11 ring support — atomic state updated during build
  _Jx11State? _jx11;
  bool _initialFocusRequested = false;

  @override
  void initState() {
    super.initState();
    _initializeFocusNodes();
    setJx11Enabled(true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(downloadQuranNotifierProvider);

      // Just track the orientation, don't sync it with isRotated
      _lastOrientation = MediaQuery.of(context).orientation;
    });
  }

  void _handleJx11Event(Jx11Event event) {
    final jx11 = _jx11;
    if (jx11 == null) return;
    final focusNodes = jx11.focusNodes;

    final isDialogOpen = _isThereCurrentDialogShowing(context);
    final isAutoScrolling = ref.read(autoScrollNotifierProvider).isSinglePageView;

    // In dialogs or auto-scroll mode → pure focus traversal (no page navigation)
    if (isDialogOpen || isAutoScrolling) {
      jx11TraverseFocus(event);
      return;
    }

    // Normal reading mode
    _handleJx11ReadingMode(event, focusNodes);
  }

  void _handleJx11ReadingMode(Jx11Event event, FocusNodes focusNodes) {
    final jx11 = _jx11;
    if (jx11 == null) return;
    final isPortrait = jx11.isPortrait;
    final physicallyRotated = jx11.isPhysicallyPortrait;
    final readingNotifier = ref.read(quranReadingNotifierProvider.notifier);

    // Activate logic is the same in all modes
    if (event == Jx11Event.playPause || event == Jx11Event.middleButton || event == Jx11Event.tap) {
      _isAnyButtonFocused(focusNodes) ? jx11ActivateFocused() : focusNodes.backButtonNode.requestFocus();
      return;
    }

    if (physicallyRotated) {
      // Device is physically rotated: left/right buttons → pages, roller → cycle buttons
      switch (event) {
        case Jx11Event.swipeLeft:
        case Jx11Event.volumeDown:
          readingNotifier.previousPage(isPortrait: isPortrait);
        case Jx11Event.swipeRight:
        case Jx11Event.volumeUp:
          readingNotifier.nextPage(isPortrait: isPortrait);
        case Jx11Event.rollerUp:
        case Jx11Event.rollerDown:
          _jx11CycleButton(focusNodes, forward: event.isNext);
        default:
          break;
      }
    } else {
      // Device is in landscape (including software portrait): roller → pages, left/right → cycle buttons
      switch (event) {
        case Jx11Event.rollerUp:
        case Jx11Event.volumeDown:
          readingNotifier.previousPage(isPortrait: isPortrait);
        case Jx11Event.rollerDown:
        case Jx11Event.volumeUp:
          readingNotifier.nextPage(isPortrait: isPortrait);
        case Jx11Event.swipeLeft:
        case Jx11Event.swipeRight:
          _jx11CycleButton(focusNodes, forward: event.isNext);
        default:
          break;
      }
    }
  }

  /// Cycle through buttons in visual order matching the on-screen layout.
  void _jx11CycleButton(FocusNodes fn, {required bool forward}) {
    final isPortrait = _jx11?.isPortrait ?? false;

    // Ordered list matching the visual layout (top-left → top-right → bottom → FABs)
    final order = isPortrait
        ? [
            fn.backButtonNode,
            fn.surahSelectorNode,
            fn.switchQuranNode, // moshaf selector (top-right)
            fn.pageSelectorNode, // bottom-center
            fn.switchToPlayQuranFocusNode, // FAB: play/pause
            fn.switchScreenViewFocusNode, // FAB: orientation
            fn.switchQuranModeNode, // FAB: mode
          ]
        : [
            fn.backButtonNode,
            fn.surahSelectorNode,
            fn.leftSkipNode,
            fn.rightSkipNode,
            fn.switchQuranNode, // moshaf selector (bottom-left)
            fn.pageSelectorNode, // bottom-center
            fn.switchToPlayQuranFocusNode,
            fn.switchScreenViewFocusNode,
            fn.switchQuranModeNode,
          ];

    final currentIndex = order.indexWhere((node) => node.hasFocus);

    if (currentIndex == -1) {
      // No button focused yet — start from the first one
      order.first.requestFocus();
      return;
    }

    final nextIndex = forward
        ? (currentIndex + 1) % order.length
        : (currentIndex - 1 + order.length) % order.length;
    order[nextIndex].requestFocus();
  }

  void _initializeFocusNodes() {
    _rightSkipButtonFocusNode = FocusNode(debugLabel: 'right_skip_node');
    _leftSkipButtonFocusNode = FocusNode(debugLabel: 'left_skip_node');
    _backButtonFocusNode = FocusNode(debugLabel: 'back_button_node');
    _switchQuranFocusNode = FocusNode(debugLabel: 'switch_quran_node');
    _switchQuranModeNode = FocusNode(debugLabel: 'switch_quran_mode_node');
    _switchScreenViewFocusNode = FocusNode(debugLabel: 'switch_screen_view_node');
    _portraitModeBackButtonFocusNode = FocusNode(debugLabel: 'portrait_mode_back_button_node');
    _portraitModeSwitchQuranFocusNode = FocusNode(debugLabel: 'portrait_mode_switch_quran_node');
    _portraitModePageSelectorFocusNode = FocusNode(debugLabel: 'portrait_mode_page_selector_node');
    _switchToPlayQuranFocusNode = FocusNode(debugLabel: 'switch_to_play_quran_node');
    _surahSelectorNode = FocusNode(debugLabel: 'surah_selector_node');
  }

  @override
  void dispose() {
    _jx11 = null;
    setJx11Enabled(false);
    _disposeFocusNodes();
    _gridScrollController.dispose();
    super.dispose();
  }

  void _disposeFocusNodes() {
    _leftSkipButtonFocusNode.dispose();
    _rightSkipButtonFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _switchQuranFocusNode.dispose();
    _switchQuranModeNode.dispose();
    _switchScreenViewFocusNode.dispose();
    _portraitModeBackButtonFocusNode.dispose();
    _portraitModeSwitchQuranFocusNode.dispose();
    _portraitModePageSelectorFocusNode.dispose();
    _switchToPlayQuranFocusNode.dispose();
    _surahSelectorNode.dispose();
  }

  void _navigateToListeningMode() {
    ref.read(quranNotifierProvider.notifier).selectModel(QuranMode.listening);
    Navigator.pushReplacementNamed(context, Routes.quranReciter);
  }

  @override
  Widget build(BuildContext context) {
    final quranReadingState = ref.watch(quranReadingNotifierProvider);
    final userPrefs = context.watch<UserPreferencesManager>();
    final autoReadingState = ref.watch(autoScrollNotifierProvider);
    final downloadState = ref.watch(downloadQuranNotifierProvider);

    // Track orientation changes but DON'T sync with isRotated
    // isRotated is ONLY controlled by the button, not physical rotation
    final currentOrientation = MediaQuery.of(context).orientation;
    _lastOrientation = currentOrientation;

    // JX-11 Bluetooth ring events
    ref.listen(jx11EventProvider, (_, next) {
      next.whenData((event) => _handleJx11Event(event));
    });

    ref.listen(downloadQuranNotifierProvider, (previous, next) async {
      if (!next.hasValue || next.value is Success) {
        ref.invalidate(quranReadingNotifierProvider);
      }

      if (next.hasValue &&
          (next.value is NoUpdate ||
              next.value is CheckingDownloadedQuran ||
              next.value is CheckingUpdate ||
              next.value is CancelDownload)) {
        return;
      }

      if (previous!.hasValue && previous.value != next.value) {
        // Perform an action based on the new status
      }

      if (!_isThereCurrentDialogShowing(context)) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => DownloadQuranDialog(),
        );
      }
    });

    return downloadState.when(
      data: (data) {
        if (data is NeededDownloadedQuran || data is Downloading || data is Extracting) {
          return Scaffold(
            body: Container(
              color: Colors.white,
            ),
          );
        }
        return WillPopScope(
          onWillPop: () async {
            userPrefs.orientationLandscape = true;
            return true;
          },
          child: quranReadingState.when(
            data: (state) {
              final size = MediaQuery.of(context).size;
              final physicallyPortrait = size.height > size.width;
              final effectiveIsPortrait = state.isRotated || physicallyPortrait;
              final needsSoftwareRotation = state.isRotated && !physicallyPortrait;

              // When orientation mode changes, replace the PageController so the
              // new PageView starts at the correct page from the very first frame.
              if (_lastEffectiveIsPortrait != null && effectiveIsPortrait != _lastEffectiveIsPortrait) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(quranReadingNotifierProvider.notifier).replaceControllerForMode(effectiveIsPortrait);
                });
              }
              _lastEffectiveIsPortrait = effectiveIsPortrait;

              return RotatedBox(
                quarterTurns: needsSoftwareRotation ? -1 : 0,
                child: SizedBox(
                  width: needsSoftwareRotation ? size.height : size.width,
                  height: needsSoftwareRotation ? size.width : size.height,
                  child: Scaffold(
                    backgroundColor: Colors.white,
                    floatingActionButtonLocation: _getFloatingActionButtonLocation(context),
                    floatingActionButton: QuranFloatingActionControls(
                      switchScreenViewFocusNode: _switchScreenViewFocusNode,
                      switchQuranModeNode: _switchQuranModeNode,
                      switchToPlayQuranFocusNode: _switchToPlayQuranFocusNode,
                    ),
                    body: _buildBody(quranReadingState, effectiveIsPortrait, userPrefs, autoReadingState),
                  ),
                ),
              );
            },
            loading: () => Scaffold(body: SizedBox()),
            error: (error, stack) => Scaffold(body: const Icon(Icons.error)),
          ),
        );
      },
      loading: () => Scaffold(body: _buildLoadingIndicator()),
      error: (error, stack) => Scaffold(body: _buildErrorIndicator(error)),
    );
  }

  Widget _buildBody(
    AsyncValue<QuranReadingState> quranReadingState,
    bool isPortrait,
    UserPreferencesManager userPrefs,
    AutoScrollState autoScrollState,
  ) {
    return quranReadingState.when(
      loading: () => _buildLoadingIndicator(),
      error: (error, s) => _buildErrorIndicator(error),
      data: (state) {
        final viewStrategy = autoScrollState.isSinglePageView
            ? AutoScrollViewStrategy(
                autoScrollState,
                initialPage: state.currentPage,
                isPortrait: isPortrait,
              )
            : NormalViewStrategy(isPortrait);

        final focusNodes = FocusNodes(
            backButtonNode: _backButtonFocusNode,
            leftSkipNode: _leftSkipButtonFocusNode,
            rightSkipNode: _rightSkipButtonFocusNode,
            pageSelectorNode: _portraitModePageSelectorFocusNode,
            switchQuranNode: _switchQuranFocusNode,
            surahSelectorNode: _surahSelectorNode,
            switchToPlayQuranFocusNode: _switchToPlayQuranFocusNode,
            switchScreenViewFocusNode: _switchScreenViewFocusNode,
            switchQuranModeNode: _switchQuranModeNode);
        focusNodes.setupFocusTraversal(isPortrait: isPortrait, settingsOrientation: userPrefs.orientationLandscape);

        // Store active state for JX-11 MethodChannel handler (atomic assignment)
        final size = MediaQuery.of(context).size;
        _jx11 = _Jx11State(focusNodes, isPortrait, size.height > size.width);

        // Request focus on back button only on first build
        if (!_initialFocusRequested) {
          _initialFocusRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isAnyButtonFocused(focusNodes)) {
              focusNodes.backButtonNode.requestFocus();
            }
          });
        }

        return GestureDetector(
            onHorizontalDragEnd: (details) => _handleSwipe(details, isPortrait),
            onVerticalDragEnd: (details) => _handleSwipe(details, isPortrait),
            child: Stack(
              children: [
                viewStrategy.buildView(state, ref, context),
                ...viewStrategy.buildControls(
                  context,
                  state,
                  userPrefs,
                  isPortrait,
                  focusNodes,
                  _scrollPageList,
                  _showPageSelector,
                ),
              ],
            ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildErrorIndicator(Object error) {
    final errorLocalized = S.of(context).error;
    return Center(
      child: Text('$errorLocalized: $error'),
    );
  }

  bool _isAnyButtonFocused(FocusNodes focusNodes) {
    return focusNodes.backButtonNode.hasFocus ||
        focusNodes.leftSkipNode.hasFocus ||
        focusNodes.rightSkipNode.hasFocus ||
        focusNodes.pageSelectorNode.hasFocus ||
        focusNodes.switchQuranNode.hasFocus ||
        focusNodes.surahSelectorNode.hasFocus ||
        focusNodes.switchToPlayQuranFocusNode.hasFocus ||
        focusNodes.switchScreenViewFocusNode.hasFocus ||
        focusNodes.switchQuranModeNode.hasFocus;
  }

  void _handleSwipe(DragEndDetails details, bool isPortrait) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;

    if (velocity > 0) {
      ref.read(quranReadingNotifierProvider.notifier).previousPage(isPortrait: isPortrait);
    } else {
      ref.read(quranReadingNotifierProvider.notifier).nextPage(isPortrait: isPortrait);
    }
  }

  void _scrollPageList(ScrollDirection direction, isPortrait) {
    if (direction == ScrollDirection.forward) {
      ref.read(quranReadingNotifierProvider.notifier).previousPage(isPortrait: isPortrait);
    } else {
      ref.read(quranReadingNotifierProvider.notifier).nextPage(isPortrait: isPortrait);
    }
  }

  void _showPageSelector(BuildContext context, int totalPages, int currentPage, bool switcherScreen) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return QuranReadingPageSelector(
          isPortrait: switcherScreen,
          currentPage: currentPage,
          scrollController: _gridScrollController,
          totalPages: totalPages,
        );
      },
    );
  }

  FloatingActionButtonLocation _getFloatingActionButtonLocation(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    switch (textDirection) {
      case TextDirection.ltr:
        return FloatingActionButtonLocation.endFloat;
      case TextDirection.rtl:
        return FloatingActionButtonLocation.startFloat;
      default:
        return FloatingActionButtonLocation.endFloat;
    }
  }

  bool _isThereCurrentDialogShowing(BuildContext context) => ModalRoute.of(context)?.isCurrent != true;
}
