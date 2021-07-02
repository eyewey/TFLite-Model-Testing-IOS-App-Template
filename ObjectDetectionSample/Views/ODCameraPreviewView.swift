//
//  ODCameraPreviewView.swift
//  ObjectDetectionSample
//
//  Created by Adarsh Manoharan on 26/06/3 R.
//

import UIKit
import AVFoundation

class ODCameraPreviewView: UIView {

  var previewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError("Layer expected is of type VideoPreviewLayer")
    }
    return layer
  }

  var session: AVCaptureSession? {
    get {
      return previewLayer.session
    }
    set {
      previewLayer.session = newValue
    }
  }

  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }
}

