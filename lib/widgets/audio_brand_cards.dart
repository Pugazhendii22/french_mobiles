import 'package:flutter/material.dart';

class AudioBrandData {
  final Widget logo;
  final String brandName;
  final String discountText;
  final Color borderColor;
  final List<Color> gradientColors;
  final List<double> gradientStops;

  const AudioBrandData({
    required this.logo,
    required this.brandName,
    required this.discountText,
    required this.borderColor,
    required this.gradientColors,
    required this.gradientStops,
  });
}

const _appleLogo = Icon(Icons.apple, size: 40, color: Colors.black);

const _boatLogo = Text.rich(
  TextSpan(
    style: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: Colors.black,
      fontFamily: 'Roboto',
    ),
    children: [
      TextSpan(text: 'bo'),
      TextSpan(
        text: 'A',
        style: TextStyle(color: Color(0xFFE91C24)),
      ),
      TextSpan(text: 't'),
    ],
  ),
);

const _oneplusLogo = Row(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.center,
  children: [
    SizedBox(
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFEB0028), width: 1.6),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '1',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFFEB0028),
                height: 1,
              ),
            ),
            Positioned(
              top: 2,
              right: 3,
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEB0028),
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    SizedBox(width: 4),
    Text(
      'ONE',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFFEB0028),
      ),
    ),
    Text(
      'PLUS',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black,
      ),
    ),
  ],
);

const appleBrandData = AudioBrandData(
  logo: _appleLogo,
  brandName: 'Apple',
  discountText: 'Up to 50% off',
  borderColor: Color(0xFFB5B2F2),
  gradientColors: [
    Colors.white,
    Color(0xFFF6F7F9),
    Color(0xFFD9DEFA),
    Color(0xFFA4ACF0),
    Color(0xFFBCB9F8),
    Colors.white,
  ],
  gradientStops: [0.0, 0.12, 0.5, 0.78, 0.9, 1.0],
);

const boatBrandData = AudioBrandData(
  logo: _boatLogo,
  brandName: 'boAt',
  discountText: 'Up to 80% off',
  borderColor: Color(0xFFE2C7E6),
  gradientColors: [
    Colors.white,
    Color(0xFFF7F6FA),
    Color(0xFFEDDDEF),
    Color(0xFFBF96C1),
    Color(0xFFCDA4D0),
    Colors.white,
  ],
  gradientStops: [0.0, 0.12, 0.5, 0.78, 0.9, 1.0],
);

const oneplusBrandData = AudioBrandData(
  logo: _oneplusLogo,
  brandName: 'Oneplus',
  discountText: 'Up to 50% off',
  borderColor: Color(0xFFECC0BF),
  gradientColors: [
    Colors.white,
    Color(0xFFF8F7F8),
    Color(0xFFF6DCE0),
    Color(0xFFF09CA4),
    Color(0xFFF1AAAC),
    Colors.white,
  ],
  gradientStops: [0.0, 0.12, 0.5, 0.78, 0.9, 1.0],
);

const defaultAudioBrands = [appleBrandData, boatBrandData, oneplusBrandData];

class AudioBrandCard extends StatelessWidget {
  final AudioBrandData data;

  const AudioBrandCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: data.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: data.gradientColors,
                stops: data.gradientStops,
              ),
            ),
            child: Center(
              child: data.logo,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.brandName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.discountText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F262E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AudioBrandsSection extends StatelessWidget {
  final List<AudioBrandData> brands;

  const AudioBrandsSection({super.key, this.brands = defaultAudioBrands});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'TOP AUDIO BRANDS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: Color(0xFF54535A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFEBEDF3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 12,
                  color: Color(0xFF8A93A5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomPaint(
                  painter: _AudioDashedLinePainter(),
                  size: const Size(double.infinity, 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                AudioBrandCard(data: brands[index]),
          ),
        ),
      ],
    );
  }
}

class _AudioDashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDEDEDE)
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
