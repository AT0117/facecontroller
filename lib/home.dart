import 'dart:io';
import 'package:camera/camera.dart';
import 'package:facecontroller/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CameraController cameraController;
  final FaceMeshDetector meshDetector = FaceMeshDetector(
    option: FaceMeshDetectorOptions.faceMesh,
  );

  bool isProcessing = false;
  List<FaceMesh> meshes = [];

  Color screenColor = Colors.black;
  String directionText = "Look straight ahead";

  void initializeCamera() {
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    cameraController = CameraController(
      frontCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    cameraController.initialize().then((_) {
      if (!mounted) return;

      cameraController.startImageStream((CameraImage image) {
        if (isProcessing) return;
        processCameraFrame(image, frontCamera);
      });

      setState(() {});
    });
  }

  Future<void> processCameraFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    isProcessing = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation:
            InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation270deg,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );

      final meshesProcessed = await meshDetector.processImage(inputImage);

      if (meshes.isNotEmpty) {
        evaluateHeadTurn(meshes.first);
      }

      setState(() {
        meshes = meshesProcessed;
      });
    } finally {
      isProcessing = false;
    }
  }

  void evaluateHeadTurn(FaceMesh face) {
    final pNose = face.points[1];
    final pLeftCheek = face.points[234];
    final pRightCheek = face.points[454];

    final leftDistance = (pNose.x - pLeftCheek.x).abs();
    final rightDistance = (pRightCheek.x - pNose.x).abs();

    if (leftDistance > rightDistance * 1.5) {
      screenColor = Colors.blue.shade900;
      directionText = "Looking Left";
    } else if (rightDistance > leftDistance * 1.5) {
      screenColor = Colors.red.shade900;
      directionText = "Looking Right";
    } else {
      screenColor = Colors.black;
      directionText = "Center";
    }
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  @override
  void dispose() {
    cameraController.stopImageStream();
    cameraController.dispose();
    meshDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: screenColor,
      appBar: AppBar(
        title: Text(directionText),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1 / cameraController.value.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(cameraController),
                  CustomPaint(
                    painter: MeshPainter(
                      meshes,
                      Size(
                        cameraController.value.previewSize!.height,
                        cameraController.value.previewSize!.width,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MeshPainter extends CustomPainter {
  final List<FaceMesh> meshes;
  final Size absoluteImageSize;

  MeshPainter(this.meshes, this.absoluteImageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;

    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    for (final FaceMesh mesh in meshes) {
      for (final FaceMeshPoint point in mesh.points) {
        final double mirroredX = size.width - (point.x.toDouble() * scaleX);
        final double y = point.y.toDouble() * scaleY;

        canvas.drawCircle(Offset(mirroredX, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MeshPainter oldDelegate) {
    return true;
  }
}
