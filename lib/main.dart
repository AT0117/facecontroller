import 'package:camera/camera.dart';
import 'package:facecontroller/home.dart';
import 'package:flutter/material.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const FaceControllerApp());
}

class FaceControllerApp extends StatefulWidget {
  const FaceControllerApp({super.key});

  @override
  State<FaceControllerApp> createState() => _FaceControllerAppState();
}

class _FaceControllerAppState extends State<FaceControllerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      title: 'Face Controller',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
