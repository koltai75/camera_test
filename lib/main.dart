import 'package:flutter/material.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Flutter Camera Test',
        home: MyHomePage(),
      );
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
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Camera Test'),
      ),
      body: Center(
        child: ElevatedButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyCamera(),
                )),
            child: const Text('Photo')),
      ));
}

class MyCamera extends StatefulWidget {
  const MyCamera({Key? key}) : super(key: key);

  @override
  State<MyCamera> createState() => _MyCameraState();
}

class _MyCameraState extends State<MyCamera> with WidgetsBindingObserver {
  late Future<bool> _initalizeCameraFuture;
  CameraController? _cameraController;
  double _progress = 0;
  bool _isCameraControllerDisposed = false;
  Timer? _timer;

  @override
  void initState() {
    _initalizeCameraFuture = _initializeCamera();
    WidgetsBinding.instance!.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.dispose();
    }
    _timer?.cancel();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() {
          _isCameraControllerDisposed = false;
          _initalizeCameraFuture = _initializeCamera();
        });
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          _cameraController!.dispose();
          _timer?.cancel();
          if (mounted) {
            setState(() {
              _isCameraControllerDisposed = true;
            });
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) => _isCameraControllerDisposed
      ? const SizedBox()
      : FutureBuilder<bool>(
          future: _initalizeCameraFuture,
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                  child: SizedBox(
                      width: 128,
                      height: 128,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8,
                      )));
            }

            var statusMessage = '';

            if (!snapshot.hasData) {
              statusMessage = 'no data received from _initalizeCamera';
            } else if (!snapshot.data!) {
              statusMessage = 'permission to camera was not granted';
            } else if (_cameraController == null ||
                !_cameraController!.value.isInitialized) {
              statusMessage = 'camera controller not initalized';
            }

            return Scaffold(
              appBar: AppBar(
                title: const Text('Flutter Camera Test'),
              ),
              body: Center(
                child: statusMessage.isNotEmpty
                    ? Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                      )
                    : CameraPreview(
                        _cameraController!,
                      ),
              ),
              persistentFooterButtons: [
                Center(
                  child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back')),
                )
              ],
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

        final start = DateTime.now().millisecondsSinceEpoch;
        const waitForSeconds = 2;
        const intervalMilliseconds = 10;

        _timer = Timer.periodic(
            const Duration(milliseconds: intervalMilliseconds), (timer) {
          if (mounted) {
            setState(() {
              _progress = (DateTime.now().millisecondsSinceEpoch - start) /
                  (waitForSeconds * 1000);
            });
          }
        });

        await Future.delayed(const Duration(seconds: waitForSeconds));
        _timer?.cancel();
        await _cameraController!.initialize();
        return Future.value(true);
      } catch (e) {
        return Future.value(false);
      }
    }
  }
}
