import 'package:flutter/material.dart';

class Suggestion extends StatelessWidget {
  final Icon icon;
  final String title;
  final IconButton button;
  final IconButton cancelButton;
  const Suggestion({super.key, required this.icon, required this.title, required this.button, required this.cancelButton});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: ElevationOverlay.applySurfaceTint(
          Theme.of(context).colorScheme.surface,
          Theme.of(context).colorScheme.surfaceTint,
          3),
      margin: EdgeInsets.zero,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            key: const Key("suggestions"),
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: Text(title, softWrap: true)),
              const SizedBox(width: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [cancelButton, const SizedBox(width: 4), button],
              )
            ],
          )
      ),
    );
  }
}