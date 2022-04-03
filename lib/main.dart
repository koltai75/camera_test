import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
  }) : super(key: key);
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Camera Test'),
      ),
      body: const MyCamera(),
    );
  }
}

class MyCamera extends StatefulWidget {
  const MyCamera({Key? key}) : super(key: key);

  @override
  State<MyCamera> createState() => _MyCameraState();
}

class _MyCameraState extends State<MyCamera> with WidgetsBindingObserver {
  late Future<bool> _initalizeCameraFuture;
  CameraController? _cameraController;

  @override
  void initState() {
    _initalizeCameraFuture = _initializeCamera();
    WidgetsBinding.instance!.addObserver(this);
    super.initState();
  }

  @override
  void dispose() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.dispose();
      _cameraController = null;
    }
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() {
          _initalizeCameraFuture = _initializeCamera();
        });
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          _cameraController!.dispose();
          _cameraController = null;
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
      future: _initalizeCameraFuture,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(
              child: Text('No data received from _initalizeCamera.'));
        }
        if (!snapshot.data!) {
          return const Center(
              child: Text('Permission to camera was not granted.'));
        }
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          return const Center(child: Text('Camera controller not initalized.'));
        }
        return CameraPreview(
          _cameraController!,
        );
      });

  Future<bool> _initializeCamera() async {
    if (!await Permission.camera.request().isGranted) {
      return Future.value(false);
    } else {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return Future.value(false);
      }
      try {
        _cameraController = CameraController(cameras[0], ResolutionPreset.high,
            enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
        await _cameraController!.initialize();
        return Future.value(true);
      } catch (e) {
        return Future.value(false);
      }
    }
  }
}
