//
//  String+Extensions.swift
//  ObjectDetectionSample
//
//  Created by Adarsh Manoharan on 26/06/3 R.
//

import UIKit

public extension String {

    func convertCharactersOnly() -> String {
        let charsetToRemove = CharacterSet.letters.inverted
        return self.components(separatedBy: charsetToRemove).joined(separator: "")
    }

    func covertedToDashedString() -> String {
        return self.replacingOccurrences(of: " ", with: "-")
    }

    func size(usingFont font: UIFont) -> CGSize {
      let attributedString = NSAttributedString(string: self, attributes: [NSAttributedString.Key.font: font])
      return attributedString.size()
    }
    
    var alphanumeric: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }
}
