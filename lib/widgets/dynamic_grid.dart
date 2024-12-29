import 'dart:math';

import 'package:flutter/material.dart';

class DynamicGridViewHeight {
  final int type; // 0 = ratio, 1 = fixed, 2 = width + value so the name is "add"
  final double value;

  const DynamicGridViewHeight.ratio(double ratio) : type = 0, value = ratio;
  const DynamicGridViewHeight.fixed(double height) : type = 1, value = height;
  const DynamicGridViewHeight.add(double height) : type = 2, value = height;
}

class DynamicGridView extends StatelessWidget {
  const DynamicGridView({super.key, required this.maxWidthOnPortrait, required this.maxWidthOnLandscape, this.spaceBetween = 0, required this.sliver, required this.children, this.height = const DynamicGridViewHeight.ratio(1)});

  final List<Widget> children;
  final int maxWidthOnPortrait;
  final int maxWidthOnLandscape;
  final double spaceBetween;
  final bool sliver;
  final DynamicGridViewHeight height;

  @override
  Widget build(context) {
    int maxWidth = MediaQuery.of(context).orientation == Orientation.portrait ? maxWidthOnPortrait : maxWidthOnLandscape;
    double aspectRatio = 1.0;
    switch(height.type) {
      case 0:
        aspectRatio = height.value;
        break;
      case 1:
        aspectRatio = (MediaQuery.of(context).size.width / max(1, MediaQuery.of(context).size.width ~/ maxWidth)) / height.value;
        break;
      case 2:
        aspectRatio = (MediaQuery.of(context).size.width / max(1, MediaQuery.of(context).size.width ~/ maxWidth)) / (MediaQuery.of(context).size.width / max(1, MediaQuery.of(context).size.width ~/ maxWidth) + height.value);
        break;
    }
    return sliver ? SliverGrid.count(
        childAspectRatio: aspectRatio,
        mainAxisSpacing: spaceBetween,
        crossAxisSpacing: spaceBetween,
        crossAxisCount: max(1, MediaQuery.of(context).size.width ~/ maxWidth),
        children: children
    ) : GridView.count(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: aspectRatio,
        mainAxisSpacing: spaceBetween,
        crossAxisSpacing: spaceBetween,
        crossAxisCount: max(1, MediaQuery.of(context).size.width ~/ maxWidth),
        children: children
    );
  }
}