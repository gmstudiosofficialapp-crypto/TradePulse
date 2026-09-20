import 'package:flutter/material.dart';

import '../../models/otc_asset.dart';
import '../layout/entrance.dart';
import 'asset_card.dart';

class AssetGrid extends StatelessWidget {
  const AssetGrid({super.key, required this.assets});

  final List<OtcAsset> assets;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100
            ? 3
            : width >= 700
                ? 2
                : 1;
        final itemWidth =
            (width - (12 * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in assets.asMap().entries)
              SizedBox(
                width: itemWidth,
                child: Entrance(
                  delay: Duration(milliseconds: 40 * entry.key.clamp(0, 10)),
                  child: AssetCard(asset: entry.value),
                ),
              ),
          ],
        );
      },
    );
  }
}
