import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/file_item.dart';

class ImageViewerScreen extends StatefulWidget {
  final FileItem fileItem;

  const ImageViewerScreen({super.key, required this.fileItem});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final TransformationController _transformationController =
      TransformationController();
  double _rotationAngle = 0.0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _rotateImage() {
    setState(() {
      _rotationAngle += 1.5708; // 90 degrees in radians (pi / 2)
      if (_rotationAngle >= 6.28318) {
        _rotationAngle = 0.0;
      }
    });
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
      _rotationAngle = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.fileItem.path);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        title: Text(
          widget.fileItem.name,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            onPressed: _rotateImage,
            tooltip: 'Rotar 90°',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetZoom,
            tooltip: 'Restablecer zoom',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 5.0,
          boundaryMargin: const EdgeInsets.all(20),
          child: Transform.rotate(
            angle: _rotationAngle,
            child: FutureBuilder<bool>(
              future: file.exists(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!) {
                  return const Center(
                    child: Text(
                      'No se pudo encontrar la imagen en el almacenamiento local.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Image.file(
                  file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            'Formato de imagen no compatible o archivo vacío: ${widget.fileItem.name}',
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
