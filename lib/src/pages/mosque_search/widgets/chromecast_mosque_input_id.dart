import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:google_fonts/google_fonts.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/main.dart';
import 'package:mawaqit/src/models/mosque.dart';
import 'package:mawaqit/src/pages/mosque_search/widgets/permission_screen_with_button.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/services/permissions_manager.dart';
import 'package:mawaqit/src/services/user_preferences_manager.dart';
import 'package:mawaqit/src/state_management/on_boarding/on_boarding.dart';
import 'package:mawaqit/src/widgets/mosque_simple_tile.dart';
import 'package:mawaqit/src/pages/onBoarding/widgets/on_boarding_permission_adhan_screen.dart';
import 'package:mawaqit/src/widgets/permissionScreenNavigator.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:fpdart/fpdart.dart' as fp;
import '../../../../i18n/AppLanguage.dart';
import '../../../helpers/AppRouter.dart';
import '../../../helpers/SharedPref.dart';
import '../../../helpers/keyboard_custom.dart';
import '../../../state_management/random_hadith/random_hadith_notifier.dart';
import '../../home/OfflineHomeScreen.dart';
import 'package:sizer/sizer.dart';

class ChromeCastMosqueInputId extends ConsumerStatefulWidget {
  const ChromeCastMosqueInputId({
    Key? key,
    this.onDone,
    this.selectedNode = const None(),
    this.isOnboarding = false,
  }) : super(key: key);

  final void Function()? onDone;
  final Option<FocusNode> selectedNode;
  final bool isOnboarding;

  @override
  ConsumerState<ChromeCastMosqueInputId> createState() => _ChromeCastMosqueInputIdState();
}

class _ChromeCastMosqueInputIdState extends ConsumerState<ChromeCastMosqueInputId> {
  final inputController = TextEditingController();
  Mosque? searchOutput;
  SharedPref sharedPref = SharedPref();
  bool loading = false;
  String? error;

  FocusNode _inputFocusNode = FocusNode();
  FocusNode _mosqueTileFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _mosqueTileFocusNode.dispose();
    inputController.dispose();
    super.dispose();
  }

  void _setMosqueId(String mosqueId) async {
    if (mosqueId.isEmpty) {
      return setState(() => error = S.of(context).missingMosqueId);
    }
    if (int.tryParse(mosqueId) == null) {
      return setState(() => error = S.of(context).mosqueIdIsNotValid(mosqueId));
    }

    setState(() {
      error = null;
      loading = true;
    });

    final mosqueManager = context.read<MosqueManager>();

    await mosqueManager.searchMosqueWithId(mosqueId).then((value) {
      if (!mounted) return;

      setState(() {
        searchOutput = value;
        loading = false;
      });

      // Move focus to the mosque tile after result appears
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mosqueTileFocusNode.requestFocus();
        }
      });
    }).catchError((e, stack) {
      if (!mounted) return;

      debugPrintStack(stackTrace: stack, label: e.toString());
      if (e is InvalidMosqueId) {
        setState(() {
          loading = false;
          error = S.of(context).mosqueIdIsNotValid(mosqueId);
        });
      } else {
        setState(() {
          loading = false;
          error = S.of(context).backendError;
        });
      }
    });
  }

  Future<void> _handleMosqueSelection() async {
    final mosqueManager = context.read<MosqueManager>();

    try {
      await mosqueManager.setMosqueUUid(searchOutput!.uuid.toString());

      final hadithLangCode = await context.read<AppLanguage>().getHadithLanguage(mosqueManager);
      ref.read(randomHadithNotifierProvider.notifier).fetchAndCacheHadith(language: hadithLangCode);

      if (searchOutput != null) {
        if (searchOutput?.type == "MOSQUE") {
          ref.read(mosqueManagerProvider.notifier).state = fp.Option.fromNullable(SearchSelectionType.mosque);
        } else {
          ref.read(mosqueManagerProvider.notifier).state = fp.Option.fromNullable(SearchSelectionType.home);
        }
      }

/*       if (!widget.isOnboarding && searchOutput?.type != "MOSQUE") {
        await PermissionScreenNavigator.checkAndShowPermissionScreen(
          context: context,
          selectedNode: widget.selectedNode,
          onComplete: widget.onDone,
        );
      } else { */
      widget.onDone?.call();
      /* } */
    } catch (e, stack) {
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
    }
  }

  String applyNameMask(String value) {
    String maskedValue = value;
    return maskedValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showKeyboard = searchOutput == null;

    return Material(
      child: Align(
        alignment: Alignment(0, -.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              S.of(context).selectMosqueId,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: theme.brightness == Brightness.dark ? null : theme.primaryColor,
              ),
            ),
            SizedBox(height: 10),
            buildInputWidget(context, theme),
            if (showKeyboard)
              KeyboardCustom(
                keyboardType: KeyboardType.numeric,
                controller: inputController,
                applyMask: applyNameMask,
                onSubmit: _setMosqueId,
              ).animate().slideY(begin: 1).fade()
            else
              SizedBox(),
            if (searchOutput != null)
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    setState(() {
                      searchOutput = null;
                      error = null;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _inputFocusNode.requestFocus();
                      }
                    });
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MosqueSimpleTile(
                    focusNode: _mosqueTileFocusNode,
                    key: ValueKey(searchOutput!.uuid),
                    autoFocus: false,
                    mosque: searchOutput!,
                    selectedNode: widget.selectedNode,
                    onTap: _handleMosqueSelection),
              ).animate().slideY(begin: 1).fade(),
          ],
        ),
      ),
    );
  }

  final navKey = GlobalKey<NavigatorState>();

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (LogicalKeyboardKey.arrowLeft == event.logicalKey) {
      FocusManager.instance.primaryFocus!.focusInDirection(TraversalDirection.left);
    } else if (LogicalKeyboardKey.arrowRight == event.logicalKey) {
      FocusManager.instance.primaryFocus!.focusInDirection(TraversalDirection.right);
    } else if (LogicalKeyboardKey.arrowUp == event.logicalKey) {
      FocusManager.instance.primaryFocus!.focusInDirection(TraversalDirection.up);
    } else if (LogicalKeyboardKey.arrowDown == event.logicalKey) {
      FocusManager.instance.primaryFocus!.focusInDirection(TraversalDirection.down);
    } else if (LogicalKeyboardKey.goBack == event.logicalKey) {
      navKey.currentState!.pop();
    }
    return KeyEventResult.handled;
  }

  Padding buildInputWidget(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Focus(
          canRequestFocus: false,
          onKey: _handleKeyEvent,
          child: TextFormField(
            controller: inputController,
            focusNode: _inputFocusNode,
            style: GoogleFonts.inter(
              color: theme.brightness == Brightness.dark ? null : theme.primaryColor,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
            onFieldSubmitted: _setMosqueId,
            cursorColor: theme.brightness == Brightness.dark ? null : theme.primaryColor,
            keyboardType: TextInputType.none,
            textInputAction: TextInputAction.search,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp("[0-9]")),
            ],
            decoration: InputDecoration(
              filled: true,
              errorText: error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: theme.primaryColor, width: 2),
              ),
              hintText: S.of(context).selectWithMosqueId,
              hintStyle: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.normal,
                color: theme.brightness == Brightness.dark ? null : theme.primaryColor.withOpacity(0.4),
              ),
              suffixIcon: IconButton(
                tooltip: "Search by Id",
                icon: loading ? CircularProgressIndicator() : Icon(Icons.search),
                color: theme.brightness == Brightness.dark ? Colors.white70 : theme.primaryColor,
                onPressed: () => _setMosqueId(inputController.text),
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
        ),
      ),
    );
  }
}
