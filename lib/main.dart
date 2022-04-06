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
                  builder: (context) => const MyCameraPreview(),
                )),
            child: const Text('Start CameraPreview')),
      ));
}

class MyCameraPreview extends StatefulWidget {
  const MyCameraPreview({Key? key}) : super(key: key);

  @override
  State<MyCameraPreview> createState() => _MyCameraPreviewState();
}

class _MyCameraPreviewState extends State<MyCameraPreview>
    with WidgetsBindingObserver {
  // camera controller
  CameraController? _cameraController;
  late Future<bool> _initalizeCameraFuture;
  bool _isCameraControllerDisposed = false;

  // delay progress
  double _progress = 0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _initalizeCameraFuture = _initializeCamera();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    // dispose camera controller if it was initialized
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController!.dispose();
    }
    _progressTimer?.cancel();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // if resumed, start again with _initalizeCamera
        setState(() {
          _isCameraControllerDisposed = false;
          _initalizeCameraFuture = _initializeCamera();
        });
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // if camera controller is initalized, dispose it
        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          _cameraController!.dispose();
        }
        // stop current progress timer
        _progressTimer?.cancel();
        // this will prevent CameraPreview using a disposed controller
        if (mounted) {
          setState(() {
            _isCameraControllerDisposed = true;
          });
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
              // progress indicator while _initalizeCamera is running, its
              // value is updated from a Timer.periodic in  _initalizeCamera
              return Center(
                  child: SizedBox(
                      width: 128,
                      height: 128,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8,
                      )));
            }

            // status message depending on the result of _initializeCamera,
            // non-empty means everything is ok
            var statusMessage = '';

            if (!snapshot.hasData) {
              statusMessage = 'no data received from _initalizeCamera';
            } else if (!snapshot.data!) {
              statusMessage = 'permission to camera was not granted';
            } else if (_cameraController == null ||
                !_cameraController!.value.isInitialized) {
              statusMessage = 'camera controller not initalized';
            }

            // build CameraPreview in a Scaffold
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
    // current permission to use camera
    final isGranted = await Permission.camera.isGranted;

    // if no permission, we try to request it
    if (!isGranted) {
      // ask for user's permission
      if (!await Permission.camera.request().isGranted) {
        // initalization failed, permission not granted
        return Future.value(false);
      }
    }

    // get available cameras
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      // initalization failed, no cameras found
      return Future.value(false);
    }
    try {
      // create controller
      _cameraController = CameraController(cameras[0], ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);

      // setup a delay timer and progress for test purposes, camera controller
      // will be initalized after the time specified here passed, and
      // the progress indicator's value is updated in Timer.periodic
      const waitForMilliseconds = 2000;
      final start = DateTime.now().millisecondsSinceEpoch;

      _progressTimer =
          Timer.periodic(const Duration(milliseconds: 10), (timer) {
        if (mounted) {
          setState(() {
            _progress = (DateTime.now().millisecondsSinceEpoch - start) /
                waitForMilliseconds;
          });
        }
      });

      // delay and call initalize on camera controller after
      await Future.delayed(const Duration(milliseconds: waitForMilliseconds));
      _progressTimer?.cancel();
      await _cameraController!.initialize();

      // this indicates that the initalization was successful
      return Future.value(true);
    } catch (e) {
      // initalization failed
      return Future.value(false);
    }
  }
}
