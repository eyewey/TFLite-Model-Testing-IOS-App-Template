//
//  CameraDetectionViewController.swift
//  ObjectDetectionSample
//
//  Created by Adarsh Manoharan on 26/06/3 R.
//

import UIKit
import SnapKit

class CameraDetectionViewController: UIViewController {

    let cameraPreview: ODCameraPreviewView = {
        let preview = ODCameraPreviewView(frame: .zero)
        return preview
    }()
    
    let outPutLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()

    var scanType: CameraScanType = .classifier
    var modelName: String = ""
    var labelName: String = ""

    let overlayView: ODOverlayView = {
        let preview = ODOverlayView(frame: .zero)
        return preview
    }()

    init(modelName: String, labelName: String) {
        super.init(nibName: nil, bundle: nil)
        self.modelName = modelName
        self.labelName = labelName
    }

    required init?(coder aDecoder: NSCoder) {
       super.init(coder: aDecoder)
    }
    

    // MARK: Constants
    private let displayFont: UIFont! = UIFont.systemFont(ofSize: 23)
    private let edgeOffset: CGFloat = 2.0
    private let labelOffset: CGFloat = 10.0
    private let animationDuration = 0.5
    private let collapseTransitionThreshold: CGFloat = -30.0
    private let expandTransitionThreshold: CGFloat = 30.0
    private let delayBetweenInferencesMs: Double = 200

    // Holds the results at any time
    private var result: Result?
    private var resultClassifier: ResultClassifier?
    private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000

    // MARK: Controllers that manage functionality
    private lazy var cameraFeedManager = ODCameraFeedManager(previewView: cameraPreview)
    private var modelDataHandler: ODObjectDetectionModelHandler? {
        let modelFileInfo: FileInfo = (name: modelName, extension: "tflite")
        let labelFileInfo: FileInfo = (name: labelName, extension: "txt")
        if scanType == .classifier {
            return ODImageClassifierModelDataHandler(modelFileInfo: modelFileInfo,
                                                     labelsFileInfo: labelFileInfo)
        }
        return ODObjectDetectionModelDataHandler(modelFileInfo: modelFileInfo,
                                                 labelsFileInfo: labelFileInfo)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Detection"
        guard modelDataHandler != nil else {
          fatalError("Failed to load model")
        }
        self.setUI()
        overlayView.clearsContextBeforeDrawing = true
        self.view.backgroundColor = .white
        self.setDelegates()
    }

    private func setUI() {
        self.view.addSubview(cameraPreview)
        self.cameraPreview.translatesAutoresizingMaskIntoConstraints = false
        cameraPreview.snp.makeConstraints { make in
            make.edges.equalTo(self.view.safeAreaInsets).priority(.high)
        }
        self.view.addSubview(overlayView)
        overlayView.backgroundColor = .clear
        self.overlayView.translatesAutoresizingMaskIntoConstraints = false
        self.overlayView.snp.makeConstraints { make in
            make.edges.equalTo(self.view.safeAreaInsets).priority(.high)
        }
        
        let bottomView = UIView()
        bottomView.backgroundColor = .white
        
        self.view.addSubview(bottomView)
        bottomView.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(self.view.safeAreaInsets).inset(0).priority(.high)
            make.height.equalTo(60).priority(.high)
        }

        self.view.addSubview(outPutLabel)
        outPutLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalTo(self.view.safeAreaInsets).inset(15).priority(.high)
        }
    }

    private func setDelegates() {
        cameraFeedManager.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cameraFeedManager.checkCameraConfigurationAndStartSession()
        
    }

    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)

      cameraFeedManager.stopSession()
    }
}
// MARK: Camera Feed Delegates
extension CameraDetectionViewController: ODCameraFeedManagerDelegate {

    func didOutput(pixelBuffer: CVPixelBuffer) {
        if scanType == .detection {
            runModel(onPixelBuffer: pixelBuffer)
        } else {
            let currentTimeMs = Date().timeIntervalSince1970 * 1000
            guard (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else { return }
            previousInferenceTimeMs = currentTimeMs

            // Pass the pixel buffer to TensorFlow Lite to perform inference.
            resultClassifier = modelDataHandler?.runModel(onFrame: pixelBuffer)

            // Display results by handing off to the InferenceViewController.
            DispatchQueue.main.async { [weak self] in
//                let resolution = CGSize(width: CVPixelBufferGetWidth(pixelBuffer),
//                                        height: CVPixelBufferGetHeight(pixelBuffer))
//
                guard let _ = self else { return }
                guard let tempResult = self?.resultClassifier, tempResult.inferences.count > 0 else {
                  return
                }
            
                tempResult.inferences.forEach { item in
                    let predictionAccuracy = item.confidence * 100.0
                    if predictionAccuracy > 90 {
                        self?.outPutLabel.text = item.label
                        
                        self?.outPutLabel.becomeFirstResponder()
                        UIAccessibility.post(notification: .announcement, argument: self?.outPutLabel.text)
                    }
                }
            }
        }
    }

    func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(title: "Camera session Denied",
                                                message: "Please allow permission for camera",
                                                preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "Cancel",
                                         style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings",
                                           style: .default) { _ in

          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                    options: [:], completionHandler: nil)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)

        present(alertController, animated: true, completion: nil)

    }

    func presentVideoConfigurationErrorAlert() {
        let alertController = UIAlertController(title: "Config faild",
                                                message: "Confuguration Failed, Please recheck the config.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(okAction)

        present(alertController, animated: true, completion: nil)
    }

    func sessionRunTimeErrorOccurred() {
        // TODO: Handle later
    }

    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        // TODO: Handle later
    }

    func sessionInterruptionEnded() {
        // TODO: Handle later
    }

    /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
     */
    @objc  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {

        // Run the live camera pixelBuffer through tensorFlow to get the result

        let currentTimeMs = Date().timeIntervalSince1970 * 1000

        guard  (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else {
            return
        }

        previousInferenceTimeMs = currentTimeMs
        result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)

        guard let displayResult = result else {
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        DispatchQueue.main.async {
            self.drawAfterPerformingCalculations(onInferences: displayResult.inferences,
                                                 withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
        }
    }

    /**
     This method takes the results, translates the bounding box rects to the current view,
     draws the bounding boxes, classNames and confidence scores of inferences.
     */
    func drawAfterPerformingCalculations(onInferences inferences: [Inference], withImageSize imageSize: CGSize) {

      self.overlayView.objectOverlays = []
      self.overlayView.setNeedsDisplay()

      guard !inferences.isEmpty else {
        return
      }

      var objectOverlays: [ObjectOverlay] = []

      for inference in inferences {

        // Translates bounding box rect to current view.
        var convertedRect = inference.rect
            .applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width,
                                        y: self.overlayView.bounds.size.height / imageSize.height))

        if convertedRect.origin.x < 0 {
          convertedRect.origin.x = self.edgeOffset
        }

        if convertedRect.origin.y < 0 {
          convertedRect.origin.y = self.edgeOffset
        }

        if convertedRect.maxY > self.overlayView.bounds.maxY {
          convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
        }

        if convertedRect.maxX > self.overlayView.bounds.maxX {
          convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
        }

        let confidenceValue = Int(inference.confidence * 100.0)
        let string = "\(inference.className)  (\(confidenceValue)%)"

        let size = string.size(usingFont: self.displayFont)

        let objectOverlay = ObjectOverlay(name: string, borderRect: convertedRect,
                                          nameStringSize: size, color: inference.displayColor, font: self.displayFont)

        objectOverlays.append(objectOverlay)
      }

      // Hands off drawing to the OverlayView
      self.draw(objectOverlays: objectOverlays)

    }

    /** Calls methods to update overlay view with detected bounding boxes and class names.
     */
    func draw(objectOverlays: [ObjectOverlay]) {

      self.overlayView.objectOverlays = objectOverlays
      self.overlayView.setNeedsDisplay()
    }

}


