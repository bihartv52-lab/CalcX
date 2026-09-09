import 'package:flutter/material.dart';

class NeonScaffold extends StatelessWidget {
  const NeonScaffold({
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    super.key,
  });

  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      extendBody: true,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF6F5FA) : const Color(0xFF050505),
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF131313),
                    Color(0xFF080808),
                    Color(0xFF050505),
                  ],
                ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
