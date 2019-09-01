# FaceDetectionRecognition
The project here takes an image from user gallery, detects all faces in that, finds out the age for each face, and then uses azure services to recognize similar faces for subsequent images picked from gallery. 

1. Face detection is done using 'Vision' framework for iOS and VNDetectFaceRectanglesRequest. 
2. For age detection Core ML model 'AgeNet' is used. 
3. For face recognition Azure cognitive face services are used.
