import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:mawaqit/src/helpers/AppRouter.dart';
import 'package:mawaqit/src/helpers/HexColor.dart';
import 'package:mawaqit/src/pages/home/widgets/audio_controller.dart';
import 'package:mawaqit/src/services/mosque_manager.dart';
import 'package:mawaqit/src/widgets/MawaqitDrawer.dart';
import 'package:provider/provider.dart';

class MosqueBackgroundScreen extends riverpod.ConsumerStatefulWidget {
  final Widget child;

  const MosqueBackgroundScreen({Key? key, required this.child}) : super(key: key);

  @override
  riverpod.ConsumerState<MosqueBackgroundScreen> createState() => _MosqueBackgroundScreenState();
}

class _MosqueBackgroundScreenState extends riverpod.ConsumerState<MosqueBackgroundScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late FocusNode _focusNode;
  DateTime? _enterKeyDownTime;

  static const _longPressDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isAudioControllable {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) return false;
    return ref.read(activeAudioControllerProvider) != null;
  }

  @override
  Widget build(BuildContext context) {
    final mosqueProvider = context.watch<MosqueManager>();
    if (!mosqueProvider.loaded) return const SizedBox();
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        final isEnterOrSelect =
            event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter;

        if (event is KeyDownEvent) {
          if (event.isArrow) {
            if (!(_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
              _scaffoldKey.currentState?.openDrawer();
              return KeyEventResult.handled;
            }
          }

          if (isEnterOrSelect && _enterKeyDownTime == null && _isAudioControllable) {
            _enterKeyDownTime = DateTime.now();
            return KeyEventResult.handled;
          }
        }

        if (event is KeyUpEvent && isEnterOrSelect && _enterKeyDownTime != null) {
          final holdDuration = DateTime.now().difference(_enterKeyDownTime!);
          _enterKeyDownTime = null;

          final controller = ref.read(activeAudioControllerProvider);
          if (controller != null) {
            final isLongPress = holdDuration >= _longPressDuration;
            if (isLongPress) {
              controller.longPress(ref);
            } else {
              controller.tap(ref);
            }
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: MawaqitDrawer(goHome: () => AppRouter.popAll()),
        body: _buildBackgroundDecoration(mosqueProvider),
      ),
    );
  }

  Widget _buildBackgroundDecoration(MosqueManager mosqueProvider) {
    final mosqueConfig = mosqueProvider.mosqueConfig!;
    if (mosqueConfig.backgroundType == "color") {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: HexColor(mosqueConfig.backgroundColor),
        child: RepaintBoundary(child: widget.child),
      );
    } else {
      String imageUrl = '';
      switch (mosqueConfig.backgroundMotif) {
        case "0":
          imageUrl = mosqueProvider.mosque?.interiorPicture ?? "";
          break;
        case "-1":
          imageUrl = mosqueProvider.mosque?.exteriorPicture ?? "";
          break;
        default:
          imageUrl = mosqueConfig.motifUrl;
      }
      return CachedNetworkImage(
        imageUrl: imageUrl,
        imageBuilder: (context, imageProvider) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            child: RepaintBoundary(child: widget.child),
            decoration: BoxDecoration(
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(.4), BlendMode.srcOver),
              ),
            ),
          );
        },
        placeholder: (context, url) {
          return Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            ),
          );
        },
        errorWidget: (context, url, error) => Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: RepaintBoundary(child: widget.child),
        ),
      );
    }
  }
}

extension on KeyEvent {
  bool get isArrow =>
      logicalKey == LogicalKeyboardKey.arrowDown ||
      logicalKey == LogicalKeyboardKey.arrowUp ||
      logicalKey == LogicalKeyboardKey.arrowLeft ||
      logicalKey == LogicalKeyboardKey.arrowRight;
}
