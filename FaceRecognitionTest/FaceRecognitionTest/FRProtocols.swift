//
//  Protocols.swift
//  FaceRecognitionTest
//
//  Created by Sachindra on 01/09/19.
//  Copyright © 2019 3 Roots Studios. All rights reserved.
//

import Foundation
import UIKit

protocol FaceDetectionProtocol: AnyObject {
    func detectFacesOnImage(image: UIImage)
    func detectAge(image: CIImage, completion: @escaping(_ age: String) -> Void)
    func faceDetectionCompleted()
    func getFaceIds(completion: @escaping () -> Void)
}

protocol FaceRecognitionProtocol: AnyObject {
    func detectExistingImages()
    func findSimilarFaces()
}
