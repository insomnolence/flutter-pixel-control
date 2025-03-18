import 'package:flutter/material.dart';

class BackgroundMesh extends StatelessWidget {
  final Widget child;

  const BackgroundMesh({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/black_mesh.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}
