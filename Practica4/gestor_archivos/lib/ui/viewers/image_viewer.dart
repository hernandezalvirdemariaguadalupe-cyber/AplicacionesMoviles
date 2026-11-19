import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../common.dart';

/// Visor de imágenes con zoom (pellizco, doble toque y botones) y rotación en pasos de 90°.
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.entry});
  final FsEntry entry;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> with SingleTickerProviderStateMixin {
  final _ctrl = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _zoomAnim;
  Uint8List? bytes;
  Object? error;
  int quarterTurns = 0;
  double scale = 1;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final s = _ctrl.value.getMaxScaleOnAxis();
      if ((s - scale).abs() > 0.01) setState(() => scale = s);
    });
    _anim.addListener(() => _ctrl.value = _zoomAnim!.value);
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await context.read<AppState>().storage.read(widget.entry.ref);
      if (mounted) setState(() => bytes = b);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  void _zoomTo(double target, [Offset? focal]) {
    final size = context.size ?? const Size(400, 400);
    final f = focal ?? Offset(size.width / 2, size.height / 2);
    final end = Matrix4.identity()
      ..translateByDouble(-f.dx * (target - 1), -f.dy * (target - 1), 0, 1)
      ..scaleByDouble(target, target, 1, 1);
    _zoomAnim = Matrix4Tween(begin: _ctrl.value, end: target == 1 ? Matrix4.identity() : end).animate(
        CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    Offset? doubleTapAt;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Información', icon: const Icon(Icons.info_outline), onPressed: () => showMetadata(context, widget.entry)),
          IconButton(tooltip: 'Compartir', icon: const Icon(Icons.share), onPressed: () => shareEntry(context, widget.entry)),
        ],
      ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(FsException.from(error!, action: 'leer la imagen').message,
                    style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              ),
            )
          : bytes == null
              ? const Center(child: CircularProgressIndicator())
              : GestureDetector(
                  onDoubleTapDown: (d) => doubleTapAt = d.localPosition,
                  onDoubleTap: () => _zoomTo(scale > 1.5 ? 1 : 2.5, doubleTapAt),
                  child: InteractiveViewer(
                    transformationController: _ctrl,
                    minScale: 0.5,
                    maxScale: 8,
                    clipBehavior: Clip.none,
                    child: Center(
                      child: AnimatedRotation(
                        turns: quarterTurns / 4,
                        duration: const Duration(milliseconds: 250),
                        child: Image.memory(
                          bytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('La imagen está dañada o su formato no es compatible.',
                                style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _btn(Icons.rotate_left, 'Girar a la izquierda', () => setState(() => quarterTurns--)),
            _btn(Icons.zoom_out, 'Alejar', () => _zoomTo((scale / 1.5).clamp(1, 8))),
            TextButton(
              onPressed: () {
                _zoomTo(1);
                setState(() => quarterTurns = 0);
              },
              child: Text('${(scale * 100).round()}%  ${((quarterTurns % 4) * 90)}°',
                  style: const TextStyle(color: Colors.white)),
            ),
            _btn(Icons.zoom_in, 'Acercar', () => _zoomTo((scale * 1.5).clamp(1, 8))),
            _btn(Icons.rotate_right, 'Girar a la derecha', () => setState(() => quarterTurns++)),
          ]),
        ),
      ),
    );
  }

  Widget _btn(IconData i, String tip, VoidCallback onTap) =>
      IconButton(tooltip: tip, icon: Icon(i, color: Colors.white), onPressed: onTap);
}
