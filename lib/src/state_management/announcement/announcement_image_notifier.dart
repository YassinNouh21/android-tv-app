import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mawaqit/src/mawaqit_image/mawaqit_image_cache.dart';

class ImageDimensions {
  final double aspectRatio;

  ImageDimensions({required this.aspectRatio});

  /// Determines if the image is portrait based on aspect ratio
  bool get isPortrait => aspectRatio < 1.0;

  /// Determines if the image is landscape based on aspect ratio
  bool get isLandscape => aspectRatio >= 1.0;

  /// Get the optimal BoxFit based on image and screen orientation
  BoxFit getOptimalBoxFit(bool isScreenPortrait) {
    // Smart BoxFit selection based on image and screen orientation
    if (isPortrait && isScreenPortrait) {
      // Portrait image + Portrait screen: BoxFit.cover
      return BoxFit.cover;
    } else if (isPortrait && !isScreenPortrait) {
      // Portrait image + Landscape screen: BoxFit.fitHeight
      return BoxFit.fitHeight;
    } else if (isLandscape && isScreenPortrait) {
      // Landscape image + Portrait screen: BoxFit.fitWidth
      return BoxFit.fitWidth;
    } else {
      // Landscape image + Landscape screen: BoxFit.fill
      return BoxFit.fill;
    }
  }
}

// Provider for each announcement image using AsyncValue
final announcementImageProvider =
    FutureProvider.autoDispose.family<ImageDimensions, String>((ref, imageUrl) async {
  final completer = Completer<ImageDimensions>();
  ImageStreamListener? imageStreamListener;
  ImageStream? imageStream;

  final imageProvider = MawaqitNetworkImageProvider(imageUrl);

  imageStreamListener = ImageStreamListener(
    (ImageInfo imageInfo, bool synchronousCall) {
      final image = imageInfo.image;
      final aspectRatio = image.width.toDouble() / image.height.toDouble();
      if (!completer.isCompleted) {
        completer.complete(ImageDimensions(aspectRatio: aspectRatio));
      }
    },
    onError: (exception, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(exception, stackTrace);
      }
    },
  );

  imageStream = imageProvider.resolve(ImageConfiguration.empty);
  imageStream.addListener(imageStreamListener);

  ref.onDispose(() {
    imageStream?.removeListener(imageStreamListener!);
  });

  return completer.future;
});
