//
//  FileHelper.swift
//  ObjectDetectionSample
//
//  Created by Adarsh Manoharan on 26/06/3 R.
//

import Foundation

class ODFileCheck {
    static func isExisting(fileName: String) -> Bool {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent(fileName) {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    static func isCurrentVersionIsBellow(version: Int, fileName: String) -> Bool {
        if let currentVersion = UserDefaults.standard.value(forKey: fileName) as? Int {
            if currentVersion < version {
                ODFileCheck.storeFileVersion(version: version, fileName: fileName)
                return true
            }
            return false
        }
        return false
    }
    
    static func storeFileVersion(version: Int, fileName: String) {
        UserDefaults.standard.setValue(version, forKey: fileName)
    }
    
    static func getPath(fileName: String) -> String? {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent(fileName) {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                return filePath
            } else {
                return nil
            }
        }
        return nil
    }
    
    static func getPathLocalFile(fileName: String, type: String) -> String? {
        if let filePath = Bundle.main.path(forResource: fileName, ofType: type) {
            return filePath
        }
        return nil
    }
    
    static func getPathLocalURL(fileName: String, type: String) -> URL? {
        if let fileURL = Bundle.main.url(forResource: fileName, withExtension: type) {
            return fileURL
        }
        return nil
    }
    
    static func getPathURL(fileName: String) -> URL? {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent(fileName) {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                return pathComponent
            } else {
                return nil
            }
        }
        return nil
    }
}
