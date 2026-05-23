import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mawaqit/i18n/l10n.dart';
import 'package:mawaqit/src/const/constants.dart';

class OrientationPreviewWidget extends StatefulWidget {
  const OrientationPreviewWidget({Key? key}) : super(key: key);

  @override
  State<OrientationPreviewWidget> createState() => _OrientationPreviewWidgetState();
}

class _OrientationPreviewWidgetState extends State<OrientationPreviewWidget> with SingleTickerProviderStateMixin {
  bool _showLandscape = true;
  late Timer _timer;
  late AnimationController _controller;
  late Animation<double> _frontScale;
  late Animation<double> _frontOpacity;
  late Animation<double> _backScale;
  late Animation<double> _backOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _frontScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _frontOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _backScale = Tween<double>(begin: 1.0, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _backOpacity = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.value = 1.0;

    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _showLandscape = !_showLandscape);
      _controller.forward(from: 0.0);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = S.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableH = constraints.maxHeight;
        final availableW = constraints.maxWidth;

        final cardMaxHeight = availableH * 0.75;
        final landscapeMaxWidth = availableW * 0.85;
        final portraitMaxWidth = availableW * 0.45;
        final labelFontSize = availableH * 0.04;
        final labelSpacing = availableH * 0.03;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: availableW * 0.05,
            vertical: availableH * 0.05,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Back card
              FadeTransition(
                opacity: _backOpacity,
                child: ScaleTransition(
                  scale: _backScale,
                  child: _buildCardContent(
                    imagePath:
                        _showLandscape ? 'assets/img/onboarding/portrait.png' : 'assets/img/onboarding/landscape.png',
                    aspectRatio: _showLandscape ? 9 / 16 : 16 / 9,
                    label: _showLandscape ? tr.portrait : tr.landscape,
                    cardMaxHeight: cardMaxHeight,
                    landscapeMaxWidth: landscapeMaxWidth,
                    portraitMaxWidth: portraitMaxWidth,
                    labelFontSize: labelFontSize,
                    labelSpacing: labelSpacing,
                  ),
                ),
              ),
              // Front card
              FadeTransition(
                opacity: _frontOpacity,
                child: ScaleTransition(
                  scale: _frontScale,
                  child: _buildCardContent(
                    imagePath:
                        _showLandscape ? 'assets/img/onboarding/landscape.png' : 'assets/img/onboarding/portrait.png',
                    aspectRatio: _showLandscape ? 16 / 9 : 9 / 16,
                    label: _showLandscape ? tr.landscape : tr.portrait,
                    cardMaxHeight: cardMaxHeight,
                    landscapeMaxWidth: landscapeMaxWidth,
                    portraitMaxWidth: portraitMaxWidth,
                    labelFontSize: labelFontSize,
                    labelSpacing: labelSpacing,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardContent({
    required String imagePath,
    required double aspectRatio,
    required String label,
    required double cardMaxHeight,
    required double landscapeMaxWidth,
    required double portraitMaxWidth,
    required double labelFontSize,
    required double labelSpacing,
  }) {
    final isPortrait = aspectRatio < 1.0;
    final radius = isPortrait ? 4.0 : 10.0;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final nativeWidth = isPortrait ? OnboardingConstant.kPortraitNativeWidth : OnboardingConstant.kLandscapeNativeWidth;

    final maxWidth = isPortrait ? portraitMaxWidth : landscapeMaxWidth;
    final imageMaxHeight = math.max(0.0, cardMaxHeight - labelSpacing - labelFontSize * 1.5);
    double imageWidth = maxWidth;
    double imageHeight = imageWidth / aspectRatio;
    if (imageHeight > imageMaxHeight) {
      imageHeight = imageMaxHeight;
      imageWidth = imageHeight * aspectRatio;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: imageWidth,
          height: imageHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
              // Decode at physical pixel size, capped to the source's native width.
              cacheWidth: math.max(
                1,
                math.min(
                  nativeWidth,
                  (imageWidth * devicePixelRatio).round(),
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  isPortrait ? Icons.stay_current_portrait : Icons.stay_current_landscape,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: labelSpacing),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
