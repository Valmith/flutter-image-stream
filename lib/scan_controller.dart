import 'dart:typed_data';
import 'package:flutter/material.dart';

//this imports tflite package
import 'package:tflite/tflite.dart';

// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:meta/meta.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;


class ScanController extends GetxController {

  late List<CameraDescription> _cameras;
  late CameraController _cameraController;
  final RxBool _isInitialized = RxBool(false);
  CameraImage? _cameraImage;
  final RxList<Uint8List> _imageList = RxList([]);
  int _imageCount = 0;

  CameraController get cameraController => _cameraController;
  bool get isInitialized => _isInitialized.value;
  List<Uint8List> get imageList => _imageList;


  @override
  void dispose() {
    _isInitialized.value = false;
    _cameraController.dispose();
    Tflite.close();
    super.dispose();
  }

//initialize the tensorflowlite model
Future<void> _initTensorFlow() async {
  String? res = await Tflite.loadModel( // Correct method name to loadModel
    model: "assets/custom_model.tflite",
    labels: "assets/custom_label.txt", // Correct property name to labels
    numThreads: 1,
    isAsset: true,
    useGpuDelegate: false,
  );
}





  Future<void> initCamera() async {
    _cameras = await availableCameras();
    _cameraController = CameraController(_cameras[0], ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.bgra8888);
    _cameraController.initialize().then((value) {
      _isInitialized.value = true;
      _cameraController.startImageStream((image) {
        _imageCount++;
        //sets the FPS of the camera that captures the imagestream
        if(_imageCount % 10 == 0){
          _imageCount = 0;
          _objectRecognition(image);
        }
      });

      _isInitialized.refresh();
    })
        .catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other errors.');
            break;
        }
      }
    });
  }

  @override
  void onInit() {
    initCamera();
    _initTensorFlow();
    super.onInit();
  }

//the object recog gubbins stuff
  Future<void> _objectRecognition(CameraImage cameraImage) async {
    var recognitions = await Tflite.runModelOnFrame(
      bytesList: cameraImage.planes.map((plane){return plane.bytes;}).toList(),
      imageHeight: cameraImage.height,
      imageWidth: cameraImage.width,
      imageMean: 127.5,
      imageStd: 127.5,
      rotation: 90,
      numResults: 2,
      threshold: 0.1,   
      asynch: true
    );


//shows the labels in the output terminal with its label what it is detecting
if (recognitions != null){
  if(recognitions[0]['confidence'] > 70){
  print(recognitions[0]['label']);
  }

  
}

  }
//end obj recog

  void capture() {
    if (_cameraImage != null) {
      img.Image image = img.Image.fromBytes(
          _cameraImage!.width, _cameraImage!.height,
          _cameraImage!.planes[0].bytes, format: img.Format.bgra);
      Uint8List list = Uint8List.fromList(img.encodeJpg(image));
      _imageList.add(list);
      _imageList.refresh();
    }
  }
}


