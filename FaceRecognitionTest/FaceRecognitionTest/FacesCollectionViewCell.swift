//
//  FacesCollectionViewCell.swift
//  FaceRecognitionTest
//
//  Created by Sachindra on 31/08/19.
//  Copyright © 2019 3 Roots Studios. All rights reserved.
//

import UIKit

class FacesCollectionViewCell: UICollectionViewCell {
    @IBOutlet var faceView: UIImageView!
    @IBOutlet var ageLabel: UILabel!
    
    func updateCell(face: Face) {
        faceView.image = face.image
        ageLabel.text = face.age
        faceView.layer.borderColor = face.isPreExisting ? UIColor.red.cgColor : UIColor.green.cgColor
        faceView.layer.cornerRadius = faceView.bounds.width / 2.0
        faceView.layer.borderWidth = 3.0
    }
}
