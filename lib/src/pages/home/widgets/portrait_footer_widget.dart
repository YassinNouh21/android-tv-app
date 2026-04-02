import 'package:flutter/material.dart';
import 'package:mawaqit/src/mawaqit_image/mawaqit_network_image.dart';
import 'package:mawaqit/src/pages/home/widgets/FlashWidget.dart';
import 'package:mawaqit/src/pages/home/widgets/footer.dart';
import 'package:mawaqit/src/pages/home/widgets/HomeLogoVersion.dart';
import 'package:mawaqit/src/themes/UIShadows.dart';
import 'package:sizer/sizer.dart';

class PortraitFooterWidget extends StatelessWidget {
  const PortraitFooterWidget({
    super.key,
    required this.mosque,
  });

  final dynamic mosque;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6.5.h,
      color: mosque.flash?.content.isEmpty != false ? null : Colors.black.withOpacity(.3),
      padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 0.3.h),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // QR Code section
            Expanded(
              flex: 2,
              child: _buildQrCodeSection(),
            ),
            // Flash message in the middle
            Expanded(
              flex: 14,
              child: FlashWidget(),
            ),
            // Logo section
            Expanded(
              flex: 2,
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: HomeLogoVersion(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCodeSection() {
    return Container(
      margin: EdgeInsets.only(right: 0.5.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "ID ${mosque.id}",
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 5.5.sp,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: kAfterAdhanTextShadow,
            ),
          ),
          SizedBox(height: 0.1.h),
          Flexible(
            child: Container(
              height: 4.5.h,
              width: 4.5.h,
              child: FittedBox(
                fit: BoxFit.contain,
                child: MawaqitNetworkImage(
                  imageUrl: kFooterQrLink,
                  errorBuilder: (context, url, error) => SizedBox(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
