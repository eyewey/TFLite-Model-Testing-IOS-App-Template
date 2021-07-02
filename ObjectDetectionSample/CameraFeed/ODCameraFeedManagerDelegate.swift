//
//  EWCameraFeedManagerDelegate.swift
//  EyeWey
//
//  Created by Adarsh Manoharan on 27/02/3 R.
//

import Foundation
import AVFoundation

// MARK: CameraFeedManagerDelegate Declaration
protocol ODCameraFeedManagerDelegate: class {

  /**
   This method delivers the pixel buffer of the current frame seen by the device's camera.
   */
  func didOutput(pixelBuffer: CVPixelBuffer)

  /**
   This method intimates that the camera permissions have been denied.
   */
  func presentCameraPermissionsDeniedAlert()

  /**
   This method intimates that there was an error in video configuration.
   */
  func presentVideoConfigurationErrorAlert()

  /**
   This method intimates that a session runtime error occurred.
   */
  func sessionRunTimeErrorOccurred()

  /**
   This method intimates that the session was interrupted.
   */
  func sessionWasInterrupted(canResumeManually resumeManually: Bool)

  /**
   This method intimates that the session interruption has ended.
   */
  func sessionInterruptionEnded()
    

    func didOutput(sampleBuffer: CMSampleBuffer, output: AVCaptureOutput, connection: AVCaptureConnection)

}
extension ODCameraFeedManagerDelegate {
    func didOutput(sampleBuffer: CMSampleBuffer, output: AVCaptureOutput, connection: AVCaptureConnection) {
        
    }
}
/**
 This enum holds the state of the camera initialization.
 */
enum EWCameraConfiguration {

  case success
  case failed
  case permissionDenied
}
