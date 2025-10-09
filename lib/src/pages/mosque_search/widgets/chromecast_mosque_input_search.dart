import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/models/mosque.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/state_management/on_boarding/on_boarding.dart';
import 'package:mawaqit/src/widgets/mosque_simple_tile.dart';
import 'package:provider/provider.dart' as Provider;
import '../../../../i18n/AppLanguage.dart';
import '../../../helpers/AppRouter.dart';
import '../../../helpers/SharedPref.dart';
import '../../../helpers/keyboard_custom.dart';
import '../../../state_management/random_hadith/random_hadith_notifier.dart';
import '../../home/OfflineHomeScreen.dart';
import 'package:fpdart/fpdart.dart' as fp;
import 'package:sizer/sizer.dart';

class ChromeCastMosqueInputSearch extends ConsumerStatefulWidget {
  const ChromeCastMosqueInputSearch({
    Key? key,
    this.onDone,
    this.selectedNode = const fp.None(),
  }) : super(key: key);

  final void Function()? onDone;
  final fp.Option<FocusNode> selectedNode;

  @override
  ConsumerState<ChromeCastMosqueInputSearch> createState() => _ChromeCastMosqueInputSearchState();
}

class _ChromeCastMosqueInputSearchState extends ConsumerState<ChromeCastMosqueInputSearch> {
  final inputController = TextEditingController();
  final scrollController = ScrollController();
  SharedPref sharedPref = SharedPref();

  List<Mosque> results = [];
  bool loading = false;
  bool noMore = false;
  String? error;
  bool showKeyboard = true;

  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _loadMoreFocusNode = FocusNode();
  List<FocusNode> _resultFocusNodes = [];
  int _currentFocusIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
    _loadMoreFocusNode.addListener(_onLoadMoreFocus);
  }

  void _onLoadMoreFocus() {
    if (_loadMoreFocusNode.hasFocus && !loading && !noMore && loadMore != null) {
      loadMore?.call();
      scrollToTheEndOfTheList();
    }
  }

  void _updateFocusNodes() {
    for (var node in _resultFocusNodes) {
      node.dispose();
    }

    _resultFocusNodes = List.generate(
      results.length,
      (index) => FocusNode(debugLabel: 'chromecast_result_${index}_node'),
    );

    for (int i = 0; i < _resultFocusNodes.length; i++) {
      final currentIndex = i;
      _resultFocusNodes[i].addListener(() {
        if (_resultFocusNodes[currentIndex].hasFocus && mounted) {
          setState(() {
            _currentFocusIndex = currentIndex;
          });
        }
      });
    }
  }

  void Function()? loadMore;

  onboardingWorkflowDone() {
    sharedPref.save('boarding', 'true');
    AppRouter.pushReplacement(OfflineHomeScreen());
  }

  void scrollToTheEndOfTheList() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: 200.milliseconds,
        curve: Curves.ease,
      );
    }
  }

  void _searchMosque(String mosque, int page) async {
    if (loading) return;
    loadMore = () => _searchMosque(mosque, page + 1);

    if (mosque.isEmpty) {
      setState(() {
        error = S.of(context).mosqueNameError;
        loading = false;
      });
      return;
    }

    setState(() {
      error = null;
      loading = true;
      showKeyboard = false;
    });

    final mosqueManager = Provider.Provider.of<MosqueManager>(context, listen: false);
    await mosqueManager.searchMosques(mosque, page: page).then((value) {
      if (!mounted) return;

      setState(() {
        loading = false;

        if (page == 1) {
          results = [];
          _currentFocusIndex = -1;
        }

        noMore = value.isEmpty;
        final oldResultsLength = results.length;
        results = [...results, ...value];

        _updateFocusNodes();

        if (page == 1 && results.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _resultFocusNodes.isNotEmpty) {
              setState(() {
                _currentFocusIndex = 0;
              });
              _resultFocusNodes[0].requestFocus();
            }
          });
        }

        if (page > 1 && _currentFocusIndex == oldResultsLength - 1 && value.isNotEmpty) {
          _currentFocusIndex = oldResultsLength;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted &&
                _resultFocusNodes.isNotEmpty &&
                _currentFocusIndex < _resultFocusNodes.length &&
                _resultFocusNodes[_currentFocusIndex].canRequestFocus) {
              _resultFocusNodes[_currentFocusIndex].requestFocus();
              _ensureItemVisible(_currentFocusIndex);
            }
          });
        }
      });
    }).catchError((e, stack) {
      if (!mounted) return;

      setState(() {
        logger.w(e.toString(), stackTrace: stack);
        loading = false;
        error = S.of(context).backendError;
      });
    });
  }

  Future<void> _selectMosque(Mosque mosque) {
    return context.read<MosqueManager>().setMosqueUUid(mosque.uuid.toString()).then((value) {
      if (context.read<MosqueManager>().typeIsMosque) {
        ref.read(mosqueManagerProvider.notifier).state = Option.fromNullable(SearchSelectionType.mosque);
      } else {
        ref.read(mosqueManagerProvider.notifier).state = Option.fromNullable(SearchSelectionType.home);
      }
    }).catchError((e, stack) {
      if (e is InvalidMosqueId) {
        setState(() {
          loading = false;
          error = S.of(context).slugError;
        });
      } else {
        setState(() {
          loading = false;
          error = S.of(context).backendError;
        });
      }
    });
  }

  void _ensureItemVisible(int index) {
    if (index < 0 || index >= results.length || !scrollController.hasClients) return;

    final double itemHeight = 80.0;
    final double listViewHeight = MediaQuery.of(context).size.height * 0.6;
    double itemPosition = index * itemHeight;

    if (itemPosition < scrollController.offset || itemPosition > scrollController.offset + listViewHeight) {
      scrollController.animateTo(
        itemPosition - (listViewHeight / 2) + (itemHeight / 2),
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  String applyNameMask(String value) {
    return value;
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _loadMoreFocusNode.dispose();
    for (var node in _resultFocusNodes) {
      node.dispose();
    }
    inputController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      child: Align(
        alignment: Alignment(0, -.3),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.symmetric(vertical: 80, horizontal: 10),
          cacheExtent: 99999,
          children: [
            Text(
              S.of(context).searchMosque,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark ? null : theme.primaryColor,
              ),
            ).animate().slideY(begin: -1).fade(),
            SizedBox(height: 20),
            searchField(theme).animate().slideX(begin: 1, delay: 200.milliseconds).fadeIn(),
            SizedBox(height: 10),
            if (showKeyboard)
              KeyboardCustom(
                keyboardType: KeyboardType.alphanumeric,
                controller: inputController,
                applyMask: applyNameMask,
                onSubmit: (val) => _searchMosque(inputController.text, 1),
              ).animate().slideY(begin: 1).fade(),
            SizedBox(height: 20),
            for (var i = 0; i < results.length; i++)
              Focus(
                onKeyEvent: (node, event) {
                  // If we're on the first item and arrow up is pressed
                  if (i == 0 && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _searchFocusNode.requestFocus();
                    setState(() {
                      showKeyboard = true;
                      results = [];
                      _currentFocusIndex = -1;
                    });
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MosqueSimpleTile(
                  key: Key('mosque_tile_${results[i].uuid}'),
                  autoFocus: false,
                  mosque: results[i],
                  selectedNode: widget.selectedNode,
                  focusNode: _resultFocusNodes.isNotEmpty && i < _resultFocusNodes.length ? _resultFocusNodes[i] : null,
                  hasFocus: _currentFocusIndex == i,
                  onTap: () => _selectMosque(results[i]),
                ),
              ).animate().slideX(delay: 70.milliseconds * (i % 5)).fade(),
            if (results.isNotEmpty)
              Focus(
                focusNode: _loadMoreFocusNode,
                child: Center(
                  child: SizedBox(
                    height: 40,
                    child: Builder(
                      builder: (context) {
                        if (loading) return CircularProgressIndicator();
                        if (noMore && results.isEmpty) return Text(S.of(context).mosqueNoResults);
                        if (noMore) return Text(S.of(context).mosqueNoMore);
                        return GestureDetector(
                          onTap: () {
                            if (!noMore && loadMore != null) {
                              loadMore?.call();
                              scrollToTheEndOfTheList();
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white10
                                  : theme.primaryColor.withOpacity(0.1),
                            ),
                            child: Text(
                              'load more',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark ? Colors.white70 : theme.primaryColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget searchField(ThemeData theme) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown && showKeyboard) {
          FocusScope.of(context).nextFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextFormField(
        controller: inputController,
        focusNode: _searchFocusNode,
        autofocus: true,
        keyboardType: TextInputType.none,
        textInputAction: TextInputAction.search,
        onFieldSubmitted: (val) => _searchMosque(val, 1),
        cursorColor: theme.brightness == Brightness.dark ? null : theme.primaryColor,
        style: GoogleFonts.inter(
          color: theme.brightness == Brightness.dark ? null : theme.primaryColor,
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          errorText: error,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor, width: 2),
          ),
          hintText: S.of(context).searchForMosque,
          hintStyle: TextStyle(
            fontSize: 8.sp,
            fontWeight: FontWeight.normal,
            color: theme.brightness == Brightness.dark ? null : theme.primaryColor.withOpacity(0.4),
          ),
          suffixIcon: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => _searchMosque(inputController.text, 1),
            child: Icon(Icons.search_rounded),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: theme.primaryColor, width: 1),
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 2,
            horizontal: 20,
          ),
        ),
      ),
    );
  }
}
