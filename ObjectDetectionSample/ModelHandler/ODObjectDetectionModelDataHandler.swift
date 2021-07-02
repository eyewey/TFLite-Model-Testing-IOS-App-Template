//
//  EWModelDataHandler.swift
//  EyeWey
//
//  Created by Adarsh Manoharan on 04/03/3 R.
//

import CoreImage
import TensorFlowLite
import UIKit
import Accelerate

/// This class handles all data preprocessing and makes calls to run inference on a given frame
/// by invoking the `Interpreter`. It then formats the inferences obtained and returns the top N
/// results for a successful inference.
class ODObjectDetectionModelDataHandler: ODObjectDetectionModelHandler {

    let threshold: Float = 0.5
    // MARK: Private properties
    private var labels: [String] = []

    // MARK: Model parameters
    let batchSize = 32
    let inputChannels = 3
    let inputWidth = 128
    let inputHeight = 128
    /// This class handles all data preprocessing and makes calls to run inference on a given frame
    /// through the `Interpreter`. It then formats the inferences obtained and returns the top N
    /// results for a successful inference.

    override init?(modelFileInfo: FileInfo, labelsFileInfo: FileInfo, threadCount: Int = 1) {
        super.init(modelFileInfo: modelFileInfo, labelsFileInfo: labelsFileInfo, threadCount: threadCount)
        // Load the classes listed in the labels file.
        loadLabels(fileInfo: labelsFileInfo)
    }

    override func runModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(sourcePixelFormat == kCVPixelFormatType_32ARGB ||
                sourcePixelFormat == kCVPixelFormatType_32BGRA ||
                sourcePixelFormat == kCVPixelFormatType_32RGBA)

        let imageChannels = 4
        assert(imageChannels >= inputChannels)

        // Crops the image to the biggest square in the center and scales it down to model dimensions.
        let scaledSize = CGSize(width: inputWidth, height: inputHeight)
        guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
            return nil
        }

        let interval: TimeInterval
        let outputBoundingBox: Tensor
        let outputClasses: Tensor
        let outputScores: Tensor
        let outputCount: Tensor
        do {
            let inputTensor = try interpreter.input(at: 0)

            // Remove the alpha component from the image buffer to get the RGB data.
            guard let rgbData = rgbDataFromBuffer(
                scaledPixelBuffer,
                byteCount: batchSize * inputWidth * inputHeight * inputChannels,
                isModelQuantized: inputTensor.dataType == .uInt8
            ) else {
                print("Failed to convert the image buffer to RGB data.")
                return nil
            }

            // Copy the RGB data to the input `Tensor`.
            try interpreter.copy(rgbData, toInputAt: 0)

            // Run inference by invoking the `Interpreter`.
            let startDate = Date()
            try interpreter.invoke()
            interval = Date().timeIntervalSince(startDate) * 1000

            outputBoundingBox = try interpreter.output(at: 0)
            outputClasses = try interpreter.output(at: 1)
            outputScores = try interpreter.output(at: 2)
            outputCount = try interpreter.output(at: 3)
        } catch let error {
            print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
            return nil
        }

        // Formats the results
        let resultArray = formatResults(
            boundingBox: [Float](unsafeData: outputBoundingBox.data) ?? [],
            outputClasses: [Float](unsafeData: outputClasses.data) ?? [],
            outputScores: [Float](unsafeData: outputScores.data) ?? [],
            outputCount: Int(([Float](unsafeData: outputCount.data) ?? [0])[0]),
            width: CGFloat(imageWidth),
            height: CGFloat(imageHeight)
        )

        // Returns the inference time and inferences
        let result = Result(inferenceTime: interval, inferences: resultArray)
        return result
    }

    /// Filters out all the results with confidence score < threshold and returns the top N results
    /// sorted in descending order.

    func formatResults(boundingBox: [Float], outputClasses: [Float], outputScores: [Float], outputCount: Int, width: CGFloat, height: CGFloat) -> [Inference] {
        var resultsArray: [Inference] = []
        if outputCount == 0 {
            return resultsArray
        }
        for element in 0...outputCount - 1 {

            let score = outputScores[element]

            // Filters results with confidence < threshold.
            guard score >= threshold else {
                continue
            }

            // Gets the output class names for detected classes from labels list.
            let outputClassIndex = Int(outputClasses[element])
            let outputClass = labels[outputClassIndex + 1]

            var rect: CGRect = CGRect.zero

            // Translates the detected bounding box to CGRect.
            rect.origin.y = CGFloat(boundingBox[4*element])
            rect.origin.x = CGFloat(boundingBox[4*element+1])
            rect.size.height = CGFloat(boundingBox[4*element+2]) - rect.origin.y
            rect.size.width = CGFloat(boundingBox[4*element+3]) - rect.origin.x

            // The detected corners are for model dimensions. So we scale the rect with respect to the
            // actual image dimensions.
            let newRect = rect.applying(CGAffineTransform(scaleX: width, y: height))

            // Gets the color assigned for the class
            let colorToAssign = colorForClass(withIndex: outputClassIndex + 1)
            let inference = Inference(confidence: score,
                                      className: outputClass,
                                      rect: newRect,
                                      displayColor: colorToAssign)
            resultsArray.append(inference)
        }

        // Sort results in descending order of confidence.
        resultsArray.sort { (first, second) -> Bool in
            return first.confidence  > second.confidence
        }

        return resultsArray
    }

    /// Loads the labels from the labels file and stores them in the `labels` property.
    private func loadLabels(fileInfo: FileInfo) {
        let filename = fileInfo.name
        let fileExtension = fileInfo.extension
        guard let fileURL = Bundle.main.url(forResource: filename, withExtension: fileExtension) else {
            fatalError("Labels file not found in bundle. Please add a labels file with name " +
                        "\(filename).\(fileExtension) and try again.")
        }
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            labels = contents.components(separatedBy: .newlines)
        } catch {
            fatalError("Labels file named \(filename).\(fileExtension) cannot be read. Please add a " +
                        "valid labels file and try again.")
        }
    }
}

// MARK: - Extensions

extension Data {
    /// Creates a new buffer by copying the buffer pointer of the given array.
    ///
    /// - Warning: The given array's element type `T` must be trivial in that it can be copied bit
    ///     for bit with no indirection or reference-counting operations; otherwise, reinterpreting
    ///     data from the resulting buffer has undefined behavior.
    /// - Parameter array: An array with elements of type `T`.
    init<T>(copyingBufferOf array: [T]) {
        self = array.withUnsafeBufferPointer(Data.init)
    }
}

extension Array {
    /// Creates a new array from the bytes of the given unsafe data.
    ///
    /// - Warning: The array's `Element` type must be trivial in that it can be copied bit for bit
    ///     with no indirection or reference-counting operations; otherwise, copying the raw bytes in
    ///     the `unsafeData`'s buffer to a new array returns an unsafe copy.
    /// - Note: Returns `nil` if `unsafeData.count` is not a multiple of
    ///     `MemoryLayout<Element>.stride`.
    /// - Parameter unsafeData: The data containing the bytes to turn into an array.
    init?(unsafeData: Data) {
        guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
        #if swift(>=5.0)
        self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
        #else
        self = unsafeData.withUnsafeBytes {
            .init(UnsafeBufferPointer<Element>(
                start: $0,
                count: unsafeData.count / MemoryLayout<Element>.stride
            ))
        }
        #endif  // swift(>=5.0)
    }
}
