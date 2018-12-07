//
//  ViewController.swift
//  Face
//
//  Created by Ali Hashim on 1/19/18.
//  Copyright © 2018 Ali Hashim. All rights reserved.
//

import UIKit
import AVFoundation
import Vision
import FirebaseFirestore
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var validBtn: UIButton!
    @IBOutlet weak var userInstructionLabel: UILabel!
    @IBOutlet weak var faceLabel: UILabel!
    @IBOutlet weak var globalView: UIView!
    @IBOutlet weak var loader: UIActivityIndicatorView!
    
    lazy var db = Firestore.firestore()
    let systemSoundID: SystemSoundID = 1016

    var frontCamera: AVCaptureDevice? = {
        return AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
    }()
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        guard let session = self.session else{return nil}
        
        var previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        return previewLayer
    }()
    
    var session: AVCaptureSession?
    let shapeLayer = CAShapeLayer()
    let faceDetection = VNDetectFaceRectanglesRequest()
    let faceLandmarks = VNDetectFaceLandmarksRequest()
    let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
    let faceDetectionRequest = VNSequenceRequestHandler()
    let nbElementToPush = 25
    
    var timer : Timer?
    var canPush = false
    var countPushes = 0
    
    var smiles : [[(CGFloat,CGFloat)]] = []
    var normals : [[(CGFloat,CGFloat)]] = []
    
    var currentFace : [(CGFloat, CGFloat)] = []
    var isSmiling = false
    
    var eyeTimer : Timer?
    var eyesAreClosed = false
    
    var currentEyeLabel = 0

    var closedEyesData : [[(CGFloat,CGFloat)]] = []
    var openedEyesData : [[(CGFloat,CGFloat)]] = []
    
    var userNormalEyesHeight : [Double] = []
    
    var pushedEyes : [[Double]] = []
    var pushStatus = "closed"
    
    let currentClassifieurName = "eyesHeights++"
    
    var eyesHeightsValues : [[Double]] = []
    var eyesHeightsIntLabels : [Int] = [] //0 closed - 1 opened
    
    var kppv : KNearestNeighborsClassifier?
    
    var showEyesPoint = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        sessionPrepare()
        //drawPoints(points: normalFaceExemple)
        //print(getEyeHeights(facePoints: normalFaceExemple))
        
        getEyesHeights()
//        getSmilesMouths()
//        getOpenedEyes()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.frame
        shapeLayer.frame = view.layer.frame
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let previewLayer = previewLayer else { return }
        
        globalView.layer.addSublayer(previewLayer)
        
        shapeLayer.strokeColor = UIColor.blue.cgColor
        shapeLayer.lineWidth = 4.0
        
        //needs to filp coordinate system for Vision
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        globalView.layer.addSublayer(shapeLayer)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        session?.stopRunning()
    }
    
    func getIntLabel(_ label: String) -> Int{
        switch label {
        case "closed":
            return 0
        case "opened":
            return 1
        case "leftClosed":
            return 2
        case "rightClosed":
            return 3
        default:
            return -1
        }
    }
    
    func getStrLabel(_ label: Int) -> String{
        switch label {
        case 0:
            return "closed"
        case 1:
            return "opened"
        case 2:
            return "leftClosed"
        case 3:
            return "rightClosed"
        default:
            return ""
        }
    }
    
    func getEyesHeights(){
        loader.startAnimating()
        db.collection(currentClassifieurName).getDocuments { (snap, err) in
            for doc in snap?.documents ?? []{
                guard let values = doc.data()["values"] as? [Double],
                    let label = doc.data()["key"] as? String
                    ,label == "opened" || label == "closed"
                    else { continue }
                self.eyesHeightsValues.append(values)
                let intLabel = self.getIntLabel(label)
                self.eyesHeightsIntLabels.append(intLabel)
            }
            
            if self.eyesHeightsValues.count > 0{
                self.kppv = KNearestNeighborsClassifier(data: self.eyesHeightsValues, labels: self.eyesHeightsIntLabels)
            }
            self.session?.startRunning()
            self.loader.stopAnimating()
            print("getEyesHeights ok")
        }
    }
    
    func getEyeHeights(facePoints : [(CGFloat, CGFloat)]) -> [Double]{
        var eyeHeights : [Double] = []
        let oposatePoints = [(9, 15),(10, 14),(11, 13),(17, 23),(18, 22),(19, 21)]
        
        for oposatePoint in oposatePoints {
            let dist = distance(facePoints[oposatePoint.0], facePoints[oposatePoint.1])
            eyeHeights.append(pow(Double(dist * 1000), 3))
        }
        
        return eyeHeights
    }
    
    func getYPred() -> [Int]{
        let status = getIntLabel(pushStatus)
        var yPred : [Int] = []
        for _ in 0..<nbElementToPush{
            yPred.append(status)
        }
        return yPred
    }
    
    func distance(_ a: (CGFloat,CGFloat), _ b: (CGFloat,CGFloat)) -> CGFloat {
        let xDist = a.0 - b.0
        let yDist = a.1 - b.1
        return CGFloat(sqrt(xDist * xDist + yDist * yDist))
    }

    func sessionPrepare() {
        session = AVCaptureSession()
        guard let session = session, let captureDevice = frontCamera else {
            print("session could not start")
            return
        }
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            session.beginConfiguration()
            
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey) : Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ]
            
            output.alwaysDiscardsLateVideoFrames = true
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            let queue = DispatchQueue(label: "output.queue")
            output.setSampleBufferDelegate(self, queue: queue)
            print("setup delegate")
        } catch {
            print("can't setup session")
        }
    }
    
    func pushIn3Sec(){
        userInstructionLabel.text = "Move to position : " + pushStatus + " eyes"
        Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (timer) in
            self.userInstructionLabel.text = ""
            self.canPush = true
        }
    }
    
    @IBAction func onValid(_ sender: Any) {
        validBtn.isHidden = true
        pushIn3Sec()
    }
    
    @IBAction func onButton(_ sender: UIButton) {
        switch sender.tag {
        case 0:
            pushStatus = "closed"
        case 1:
            pushStatus = "opened"
        case 2:
            pushStatus = "leftClosed"
        case 3:
            pushStatus = "rightClosed"
        default:
            return
        }
        
        globalView.isHidden = false
        showEyesPoint = true
        pushIn3Sec()
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate)
        let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as! [String : Any]?)
        
        //leftMirrored for front camera
        let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImageOrientation.leftMirrored.rawValue))
        
        detectFace(on: ciImageWithOrientation)
    }
}

extension ViewController {
    func detectFace(on image: CIImage) {
        try? faceDetectionRequest.perform([faceDetection], on: image)
        if let results = faceDetection.results as? [VNFaceObservation] {
            
            if results.count == 0{  //No face
                DispatchQueue.main.async {
                    self.shapeLayer.sublayers?.removeAll()
                    self.checkEyeStatus(1)
                    self.currentEyeLabel = 1
                    self.faceLabel.text = ""
                }
            }
            if !results.isEmpty {
                
                faceLandmarks.inputFaceObservations = results
                detectLandmarks(on: image)
                
                DispatchQueue.main.async {
                    
                    self.shapeLayer.sublayers?.removeAll()
                    
                }
            }
        }
    }
    
    func detectLandmarks(on image: CIImage) {
        try? faceLandmarksDetectionRequest.perform([faceLandmarks], on: image)
        if let landmarksResults = faceLandmarks.results as? [VNFaceObservation] {
            
            for observation in landmarksResults {
                
                DispatchQueue.main.async {
                    if let boundingBox = self.faceLandmarks.inputFaceObservations?.first?.boundingBox {
                        let faceBoundingBox = boundingBox.scaled(to: self.view.bounds.size)
                        //different types of landmarks
                        
                        let allpoints = observation.landmarks?.allPoints
                        self.convertPointsForFace(allpoints, faceBoundingBox)
                        
                        if let points = allpoints?.normalizedPoints{
                            self.currentFace = points.map({ ($0.x, $0.y) })
                            
                            self.userNormalEyesHeight = []
                            
                            let eyeHeights = self.getEyeHeights(facePoints: self.currentFace)
                            
                            let pred = self.kppv?.predict([eyeHeights]) ?? []
                            //print(self.kppv?.predict([eyeHeights]) ?? [])
                            
                            self.pushEyesHeights(eyeHeights)
                            self.checkEyeStatus(pred.first ?? 0)
                            self.currentEyeLabel = pred.first ?? 0
                            //self.setFaceLabel(status: self.currentEyeLabel)
                        }
                    }
                }
            }
        }
    }
    
    func hasUpperSize(new : [Double]) -> Bool {
        return (new.first ?? 0) > (userNormalEyesHeight.first ?? 0) && (new.last ?? 0) > (userNormalEyesHeight.last ?? 0)
    }
    
    func setFaceLabel(status : Int){
        switch status {
        case 0 :
            faceLabel.text = "-.-"
        case 1 :
            faceLabel.text = "O.O"
        case 2 :
            faceLabel.text = "O.-"
        case 3 :
            faceLabel.text = "-.O"
            
        default:
            break
        }
    }
    
    func checkEyeStatus(_ status : Int){
        if status != 1 && status == currentEyeLabel{
            guard (eyeTimer?.isValid ?? false) == false else { return }
            eyeTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true, block: { (timer) in
                print("\(status) confirmed")
                self.userNormalEyesHeight.removeAll()
                self.setFaceLabel(status: self.currentEyeLabel)
                if status == 0 && self.showEyesPoint == false {
                    AudioServicesPlaySystemSound (self.systemSoundID)
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                } //WAKE UP
            })
        }else {
            self.setFaceLabel(status: self.currentEyeLabel)
            eyeTimer?.invalidate()
        }
    }
    
    func pushEyesHeights(_ points : [Double]){
        guard canPush else { return }
        if countPushes >= nbElementToPush {
            let pred = kppv?.predict(pushedEyes) ?? []
            let acc = kppv?.accuracy(yTests: pred, yPred: getYPred()) ?? 0
            let date = Timestamp(date: Date())
            let action = UIAlertAction(title: "Send", style: .default) { (action) in
                for eye in self.pushedEyes{
                    self.db.collection(self.currentClassifieurName).addDocument(data: ["values": eye,
                                                                         "key" : self.pushStatus,
                                                                         "label" : self.getIntLabel(self.pushStatus),
                                                                         "date" : date])
                }
                self.eyesHeightsValues.append(contentsOf: self.pushedEyes)
                let intLabels = self.getYPred()
                self.eyesHeightsIntLabels.append(contentsOf: intLabels)
                self.kppv = KNearestNeighborsClassifier(data: self.eyesHeightsValues, labels: self.eyesHeightsIntLabels)
                self.pushedEyes.removeAll()
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
                self.pushedEyes.removeAll()
            }
            self.showAlert(title: "Finished !", message: "Send \(pushStatus) eyes ? (\(acc)%)", actions: [action, cancel])
            self.showEyesPoint = false
            self.canPush = false
            self.countPushes = 0
            self.globalView.isHidden = true
            return
        }
        
        self.pushedEyes.append(points)
        countPushes += 1
    }

    //mouth = [24...39]
    //eyes [8...23] + [63...64]
    func drawPoints(points :[(CGFloat, CGFloat)]){
        guard points.count == 65 else { return }
        self.globalView.subviews.forEach({
            if $0.tag == 1 { $0.removeFromSuperview() }
        })
        var limitPoints = points[8...23]
        limitPoints.append(contentsOf: points[63...64])
        for point in points{
            let x = (point.0 * 250) + 100
            let y = (point.1 * -250) + 300
            let pointView = UIView(frame: CGRect(x: x, y: y, width: 3, height: 3))
            pointView.layer.cornerRadius = pointView.frame.width / 2
            pointView.backgroundColor = UIColor.red
            pointView.tag = 1
            if limitPoints.contains(where: { (compare) -> Bool in
                return compare == point
            }){
                pointView.backgroundColor = UIColor.green
            }
            self.globalView.addSubview(pointView)
        }
    }
    
    func convertPointsForFace(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect) {
        guard showEyesPoint else { return }
        if let points = landmark?.normalizedPoints{
            
            let faceLandmarkVertices = points.map { (point: (CGPoint)) -> Vertex in
                let pointX = point.x * boundingBox.width + boundingBox.origin.x
                let pointY = point.y * boundingBox.height + boundingBox.origin.y
                
                return Vertex(x: Double(pointX), y: Double(pointY))
            }
            
            var eyes =  Array(faceLandmarkVertices[8...23])
            eyes.append(contentsOf: faceLandmarkVertices[63...64])
                
            DispatchQueue.main.async {
                self.draw(vertices: eyes, boundingBox: boundingBox)
            }
        }
    }
    
    func draw(vertices: [Vertex], boundingBox: CGRect) {
        let newLayer = CAShapeLayer()
        newLayer.strokeColor = UIColor.blue.cgColor
        newLayer.lineWidth = 4.0
        var newVertices = vertices
        
        newVertices.remove(at: newVertices.count - 1)
        
        let triangles = Delaunay().triangulate(newVertices)
        
        for triangle in triangles {
            let triangleLayer = CAShapeLayer()
            triangleLayer.path = triangle.toPath()
            triangleLayer.strokeColor = canPush ? UIColor.green.cgColor : UIColor.red.cgColor
            triangleLayer.lineWidth = 1.0
            triangleLayer.fillColor = UIColor.clear.cgColor
            triangleLayer.backgroundColor = UIColor.clear.cgColor
            shapeLayer.addSublayer(triangleLayer)
        }
    }
}
