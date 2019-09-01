//
//  AzureFaceRecognition.swift
//  Azure iOS Facial Recognition
//
//  Created by Alejandro Cotilla on 8/14/18.
//  Copyright © 2018 Alejandro Cotilla. All rights reserved.
//

import UIKit

let APIKey = <API KEY> // Ocp-Apim-Subscription-Key
let Region = "southeastasia" //

//southeastasia.api.cognitive.microsoft.com
let FindSimilarsUrl = "https://\(Region).api.cognitive.microsoft.com/face/v1.0/findsimilars"
let DetectUrl = "https://\(Region).api.cognitive.microsoft.com/face/v1.0/detect?returnFaceId=true"

class AzureFaceRecognition: NSObject {

    static let shared = AzureFaceRecognition()
    
    // See Face - Detect endpoint details
    // https://westus.dev.cognitive.microsoft.com/docs/services/563879b61984550e40cbbe8d/operations/563879b61984550f30395236
    func syncDetectFaceIds(imageData: Data, completion: @escaping([String]) -> Void) {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/octet-stream"
        headers["Ocp-Apim-Subscription-Key"] = APIKey
        
        self.makePOSTRequest(url: DetectUrl, postData: imageData, headers: headers) { (response) in
            let faceIds = self.extractFaceIds(fromResponse: response)
            completion(faceIds)
        }
    }

    // See Face - Find Similar endpoint details
    // https://westus.dev.cognitive.microsoft.com/docs/services/563879b61984550e40cbbe8d/operations/563879b61984550f30395237
    func findSimilars(faceId: String, faceIds: [String], completion: @escaping ([String]) -> Void) {

        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        headers["Ocp-Apim-Subscription-Key"] = APIKey

        let params: [String: Any] = [
            "faceId": faceId,
            "faceIds": faceIds,
            "mode": "matchFace"
        ]

        // Convert the Dictionary to Data
        let data = try! JSONSerialization.data(withJSONObject: params)

        self.makePOSTRequest(url: FindSimilarsUrl, postData: data, headers: headers) { (response) in
            // Use a low confidence value to get more matches
            let faceIds = self.extractFaceIds(fromResponse: response, minConfidence: 0.4)
              completion(faceIds)
        }

    }
    
    private func extractFaceIds(fromResponse response: [AnyObject], minConfidence: Float? = nil) -> [String] {
        var faceIds: [String] = []
        for faceInfo in response {
            if let faceId = faceInfo["faceId"] as? String  {
                var canAddFace = true
                if minConfidence != nil {
                    let confidence = (faceInfo["confidence"] as! NSNumber).floatValue
                    canAddFace = confidence >= minConfidence!
                }
                if canAddFace { faceIds.append(faceId) }
            }
            
        }
        
        return faceIds
    }

    private func makePOSTRequest(url: String, postData: Data, headers: [String: String], completion: @escaping([AnyObject]) -> Void) {
        var object: [AnyObject] = []
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = postData

        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyObject], json != nil {
                object = json
                completion(object)
            }
            else {
                print("ERROR response: \(String(data: data!, encoding: .utf8) ?? "")")
                completion([])
            }
            
        }.resume()
    }
}
