//
//  ViewController.swift
//  FaceRecognitionTest
//
//  Created by Sachindra on 31/08/19.
//  Copyright © 2019 3 Roots Studios. All rights reserved.
//

import UIKit
import Vision
import CoreML
import CoreImage

class ViewController: UIViewController, UINavigationControllerDelegate {
    @IBOutlet var selectedImageView: UIImageView!
    @IBOutlet var facesCollectionView: UICollectionView!
    var faces: [Face] = []
    var ageModel: VNCoreMLModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        guard let model = try? VNCoreMLModel(for: AgeNet().model) else {
            fatalError("Can't load age model")
        }
        ageModel = model
    }

    @IBAction func selectImageFromGallery() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }

}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        self.dismiss(animated: true, completion: nil)
        
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            selectedImageView.image = image
            detectFacesOnImage(image: image)
        }
    }
    
}

extension ViewController: FaceDetectionProtocol {
    func detectFacesOnImage(image: UIImage) {
        guard let cgImage = image.cgImage else {
            return
        }
        var tempImage = image
        let detectFaceRequest = VNDetectFaceRectanglesRequest { (request, error) in
            if error != nil {
                return
            }
            guard let results = request.results as? [VNFaceObservation] else {
                return
            }
            let detectAgeDispatchGroup = DispatchGroup()

            for aFace in results {
                UIGraphicsBeginImageContextWithOptions(tempImage.size, false, 1.0)
                tempImage.draw(in: CGRect(x: 0, y: 0, width: tempImage.size.width, height: tempImage.size.height))
                
                let faceRect = aFace.boundingBox
                let tf = CGAffineTransform.init(scaleX: 1, y: -1).translatedBy(x: 0, y: -tempImage.size.height)
                let ts = CGAffineTransform.identity.scaledBy(x: tempImage.size.width, y: tempImage.size.height)
                let convertedFaceRect = faceRect.applying(ts).applying(tf)
                
                let context = UIGraphicsGetCurrentContext()
                context?.setStrokeColor(UIColor.red.cgColor)
                context?.setLineWidth(5.0)
                context?.stroke(convertedFaceRect)
                
                let updatedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                tempImage = updatedImage!
//                DispatchQueue.main.async {
//                }
                
                if let faceImage = cgImage.cropping(to: convertedFaceRect) {
                    let faceUIImage = UIImage(cgImage: faceImage)
                    let faceCIImage = CIImage(cgImage: faceImage)
                    detectAgeDispatchGroup.enter()
                    self.detectAge(image: faceCIImage) { (age) in
                                            self.faces.append(Face(faceID: nil, age: age, image: faceUIImage, isPreExisting: false))
                    detectAgeDispatchGroup.leave()
                    }
                }
            }
            detectAgeDispatchGroup.wait()
            DispatchQueue.main.async {
                self.selectedImageView.image = tempImage
                print("updatedImage:\(String(describing: tempImage))")
                self.faceDetectionCompleted()
            }
        }
        
        let detectFaceRequestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        DispatchQueue.global().async {
          do {
                  try detectFaceRequestHandler.perform([detectFaceRequest])
              } catch let error as NSError {
                  print("failed to perform face detection. Error: \(error.description)")
                  return
              }
        }
    }
    
    func detectAge(image: CIImage, completion: @escaping(_ age: String) -> Void) {
        let ageDetectionRequest = VNCoreMLRequest(model: ageModel) { (request, error) in
            if error != nil {
                fatalError("Error processing age request")
            }
            guard let results = request.results as? [VNClassificationObservation], let topResults = results.first else {
                fatalError("Unexpected age response")
            }
            let age = topResults.identifier
            completion(age)
        }
        
        let ageDetectionRequestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        DispatchQueue.global().async {
            do {
                try ageDetectionRequestHandler.perform([ageDetectionRequest])
            }
            catch {
                print(error)
            }
        }
    }

    func faceDetectionCompleted() {
        print("faceDetectionCompleted.")
        facesCollectionView.reloadData()
        
        //Now check for duplicates.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3)) {
            self.getFaceIds { () in
                self.findSimilarFaces()
            }
        }
    }
    
    func getFaceIds(completion: @escaping () -> Void) {
        print("getFaceIds...")

        //Create faceIds
        var tempFaces: [Face] = []
        let faceIDGroup = DispatchGroup()
        for face in faces {
            faceIDGroup.enter()
            guard let imageData = face.image.pngData() else {
                print("error getting image data")
                faceIDGroup.leave()
                return
            }
            AzureFaceRecognition.shared.syncDetectFaceIds(imageData: imageData) { (response) in
                guard let faceId = response.first else {
                    print("Couldnot get faceId")
                    faceIDGroup.leave()
                    return
                }
                print("detected faceId:\(faceId)")
                let tempFace = Face(faceID: faceId, age: face.age, image: face.image, isPreExisting: face.isPreExisting)
                tempFaces.append(tempFace)
                faceIDGroup.leave()
            }
        }
        faceIDGroup.wait()
        self.faces = tempFaces
        print("New face data:",self.faces)
        completion()
    }
    
    func findSimilarFaces(){
        print("findSimilarFaces...")
        var tempFaces: [Face] = []
        let faceIDGroup = DispatchGroup()
        for face in faces {
            faceIDGroup.enter()
            AzureFaceRecognition.shared.findSimilars(faceId: face.faceID, faceIds: self.getAllFaceIDs()) { (faceIds) in
                print("findSimilarFaces faceIds:\(faceIds)")
                let tempFace = Face(faceID: face.faceID, age: face.age, image: face.image, isPreExisting: (faceIds.count > 0) ? true: false)
                tempFaces.append(tempFace)
                print(faceIds.count > 0 ? "Found duplicate" : "Found original")
                faceIDGroup.leave()
            }
        }
        faceIDGroup.wait()
        faceIDGroup.notify(queue: .main) {
            print("findSimilarFaces completed.")
            self.faces = tempFaces
            self.facesCollectionView.reloadData()
        }
    }
    
    func getAllFaceIDs() -> [String] {
        let ids = faces.map { $0.faceID ?? ""}
        return ids
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return faces.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FacesCollectionViewCell", for: indexPath) as! FacesCollectionViewCell
        cell.updateCell(face: faces[indexPath.row])
        return cell
    }
}
