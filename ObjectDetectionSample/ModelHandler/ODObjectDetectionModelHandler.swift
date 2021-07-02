//
//  EWObjectDetectionModelHandler.swift
//  EyeWey
//
//  Created by Adarsh Manoharan on 11/03/3 R.
//

import CoreImage
import TensorFlowLite
import UIKit
import Accelerate

/// Stores results for a particular frame that was successfully run through the `Interpreter`.
struct Result {
    let inferenceTime: Double
    let inferences: [Inference]
}

public enum CameraScanType {
    case classifier
    case detection
}

struct ResultClassifier {
    let inferenceTime: Double
    let inferences: [InferenceClassifier]
}

/// Stores one formatted inference.
struct Inference {
    let confidence: Float
    let className: String
    let rect: CGRect
    let displayColor: UIColor
}

struct InferenceClassifier {
    let confidence: Float
    let label: String
}
/// Information about a model file or labels file.
typealias FileInfo = (name: String, extension: String)

/// Information about the MobileNet SSD model.
enum MobileNetSSD {
    static let modelInfo: FileInfo = (name: "detect", extension: "tflite")
    static let labelsInfo: FileInfo = (name: "labelmap", extension: "txt")
}
enum MobileNetClassifierSSD {
    static let modelInfo: FileInfo = (name: "model_currency", extension: "tflite")
    static let labelsInfo: FileInfo = (name: "currency_labels", extension: "txt")
}
class ODObjectDetectionModelHandler: NSObject {
    // MARK: - Internal Properties
    /// The current thread count used by the TensorFlow Lite Interpreter.
    var threadCount: Int = 2
    let threadCountLimit = 10

    // image mean and std for floating model, should be consistent with parameters used in model training
    let imageMean: Float = 127.5
    let imageStd: Float = 127.5

    /// TensorFlow Lite `Interpreter` object for performing inference on a given model.
    var interpreter: Interpreter

    let bgraPixel = (channels: 4, alphaComponent: 3, lastBgrComponent: 2)
    let rgbPixelChannels = 3
    let colorStrideValue = 10
    let colors = [
        UIColor.red,
        UIColor(displayP3Red: 90.0/255.0, green: 200.0/255.0, blue: 250.0/255.0, alpha: 1.0),
        UIColor.green,
        UIColor.orange,
        UIColor.blue,
        UIColor.purple,
        UIColor.magenta,
        UIColor.yellow,
        UIColor.cyan,
        UIColor.brown
    ]

    // MARK: - Initialization

    /// A failable initializer for `ModelDataHandler`. A new instance is created if the model and
    /// labels files are successfully loaded from the app's main bundle. Default `threadCount` is 1.
    init?(modelFileInfo: FileInfo, labelsFileInfo: FileInfo, threadCount: Int = 1) {
        let modelFilename = modelFileInfo.name

        // Construct the path to the model file.
        guard let modelPath = ODFileCheck.getPathLocalFile(fileName: modelFilename, type: modelFileInfo.extension) else {
            print("Failed to load the model file with name: \(modelFilename).")
            return nil
        }

        // Specify the options for the `Interpreter`.
        self.threadCount = threadCount
        var options = InterpreterOptions()
        options.threadCount = threadCount
        do {
            // Create the `Interpreter`.
            interpreter = try Interpreter(modelPath: modelPath, options: options)
            // Allocate memory for the model's input `Tensor`s.
            try interpreter.allocateTensors()
        } catch let error {
            print("Failed to create the interpreter with error: \(error.localizedDescription)")
            return nil
        }

        super.init()
    }

    /// Returns the RGB data representation of the given image buffer with the specified `byteCount`.
    ///
    /// - Parameters
    ///   - buffer: The BGRA pixel buffer to convert to RGB data.
    ///   - byteCount: The expected byte count for the RGB data calculated using the values that the
    ///       model was trained on: `batchSize * imageWidth * imageHeight * componentsCount`.
    ///   - isModelQuantized: Whether the model is quantized (i.e. fixed point values rather than
    ///       floating point values).
    /// - Returns: The RGB data representation of the image buffer or `nil` if the buffer could not be
    ///     converted.
    func rgbDataFromBuffer(
        _ buffer: CVPixelBuffer,
        byteCount: Int,
        isModelQuantized: Bool
    ) -> Data? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }
        guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let destinationChannelCount = 3
        let destinationBytesPerRow = destinationChannelCount * width

        var sourceBuffer = vImage_Buffer(data: sourceData,
                                         height: vImagePixelCount(height),
                                         width: vImagePixelCount(width),
                                         rowBytes: sourceBytesPerRow)

        guard let destinationData = malloc(height * destinationBytesPerRow) else {
            print("Error: out of memory")
            return nil
        }

        defer {
            free(destinationData)
        }
        var destinationBuffer = vImage_Buffer(data: destinationData,
                                              height: vImagePixelCount(height),
                                              width: vImagePixelCount(width),
                                              rowBytes: destinationBytesPerRow)

        if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
            vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        } else if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32ARGB {
            vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
        }

        let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
        if isModelQuantized {
            return byteData
        }

        // Not quantized, convert to floats
        let bytes = [UInt8](unsafeData: byteData)!
        var floats = [Float]()
        for element in 0..<bytes.count {
            floats.append((Float(bytes[element]) - imageMean) / imageStd)
        }
        return Data(copyingBufferOf: floats)
    }

    /// This assigns color for a particular class.
    func colorForClass(withIndex index: Int) -> UIColor {

        // We have a set of colors and the depending upon a stride, it assigns variations to of the base
        // colors to each object based on its index.
        let baseColor = colors[index % colors.count]

        var colorToAssign = baseColor

        let percentage = CGFloat((colorStrideValue / 2 - index / colors.count) * colorStrideValue)

        if let modifiedColor = baseColor.getModified(byPercentage: percentage) {
            colorToAssign = modifiedColor
        }

        return colorToAssign
    }
    public func runModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
        return nil
    }
    public func runModel(onFrame pixelBuffer: CVPixelBuffer) -> ResultClassifier? {
        return nil
    }
}
