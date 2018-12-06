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
    
    var pushedEyes : [[Double]] = []
    var pushStatus = "closed"
    
    let closedEyes : [(CGFloat,CGFloat)] = [(0.1915283203125, 0.8336181640625), (0.258056640625, 0.8658447265625), (0.3515625, 0.863037109375), (0.42578125, 0.83740234375), (0.6025390625, 0.8310546875), (0.677734375, 0.859619140625), (0.7626953125, 0.858642578125), (0.82177734375, 0.8262939453125), (0.2440185546875, 0.72412109375), (0.280029296875, 0.7255859375), (0.314697265625, 0.725830078125), (0.355712890625, 0.73046875), (0.397216796875, 0.728515625), (0.366455078125, 0.7109375), (0.318115234375, 0.70751953125), (0.2822265625, 0.71142578125), (0.62353515625, 0.72314453125), (0.6630859375, 0.723388671875), (0.69677734375, 0.718505859375), (0.73193359375, 0.7158203125), (0.76806640625, 0.710205078125), (0.73583984375, 0.701416015625), (0.6943359375, 0.69921875), (0.654296875, 0.70556640625), (0.436767578125, 0.3427734375), (0.490234375, 0.3505859375), (0.529296875, 0.34326171875), (0.57470703125, 0.35546875), (0.6162109375, 0.34033203125), (0.662109375, 0.31689453125), (0.60546875, 0.26123046875), (0.5302734375, 0.248046875), (0.4482421875, 0.263671875), (0.372802734375, 0.318359375), (0.457763671875, 0.314453125), (0.52783203125, 0.30908203125), (0.5888671875, 0.310546875), (0.5908203125, 0.3056640625), (0.52685546875, 0.30126953125), (0.447998046875, 0.31494140625), (0.10552978515625, 0.73193359375), (0.11309814453125, 0.58447265625), (0.1490478515625, 0.33447265625), (0.239013671875, 0.16845703125), (0.373046875, 0.04736328125), (0.525390625, 0.01416015625), (0.654296875, 0.046875), (0.76416015625, 0.16552734375), (0.83544921875, 0.32470703125), (0.8798828125, 0.562744140625), (0.88037109375, 0.72900390625), (0.47216796875, 0.736083984375), (0.45654296875, 0.566162109375), (0.411865234375, 0.47802734375), (0.477294921875, 0.47509765625), (0.5400390625, 0.439453125), (0.59619140625, 0.47021484375), (0.6416015625, 0.4775390625), (0.60693359375, 0.566162109375), (0.5673828125, 0.73876953125), (0.52587890625, 0.7547607421875), (0.53173828125, 0.655517578125), (0.54833984375, 0.522705078125), (0.3198089599609375, 0.720550537109375), (0.69598388671875, 0.712158203125)]
    
    let normalFaceExemple : [(CGFloat,CGFloat)] = [(0.1539306640625, 0.8270263671875), (0.215087890625, 0.8603515625), (0.3134765625, 0.8563232421875), (0.380615234375, 0.833984375), (0.5869140625, 0.83984375), (0.65478515625, 0.8680419921875), (0.7568359375, 0.87506103515625), (0.82958984375, 0.8427734375), (0.2174072265625, 0.727783203125), (0.2496337890625, 0.744873046875), (0.29345703125, 0.75341796875), (0.338134765625, 0.744384765625), (0.3779296875, 0.7236328125), (0.345947265625, 0.702392578125), (0.29345703125, 0.697021484375), (0.2476806640625, 0.7021484375), (0.60791015625, 0.72705078125), (0.6455078125, 0.75390625), (0.68701171875, 0.760986328125), (0.734375, 0.7530517578125), (0.771484375, 0.73095703125), (0.73876953125, 0.711181640625), (0.69091796875, 0.69921875), (0.6455078125, 0.70849609375), (0.427001953125, 0.310546875), (0.464599609375, 0.32177734375), (0.501953125, 0.31103515625), (0.53857421875, 0.32373046875), (0.578125, 0.3095703125), (0.62744140625, 0.28125), (0.56982421875, 0.2490234375), (0.50439453125, 0.236328125), (0.442138671875, 0.24658203125), (0.39697265625, 0.2783203125), (0.455078125, 0.279296875), (0.505859375, 0.275390625), (0.55908203125, 0.2802734375), (0.55615234375, 0.296875), (0.5009765625, 0.2939453125), (0.453857421875, 0.29931640625), (0.117431640625, 0.73046875), (0.1329345703125, 0.577880859375), (0.1884765625, 0.3232421875), (0.275146484375, 0.17529296875), (0.39599609375, 0.06591796875), (0.52001953125, 0.0458984375), (0.64990234375, 0.0732421875), (0.79248046875, 0.1875), (0.880859375, 0.34765625), (0.91552734375, 0.6123046875), (0.91259765625, 0.7637939453125), (0.443359375, 0.740966796875), (0.419189453125, 0.553466796875), (0.39013671875, 0.45703125), (0.43896484375, 0.46337890625), (0.49560546875, 0.43505859375), (0.5517578125, 0.46630859375), (0.6044921875, 0.45751953125), (0.56396484375, 0.5576171875), (0.5361328125, 0.74658203125), (0.484619140625, 0.7598876953125), (0.487548828125, 0.671630859375), (0.4912109375, 0.518798828125), (0.2954559326171875, 0.724456787109375), (0.690185546875, 0.7306060791015625)]
    
    let smileExemple : [(CGFloat,CGFloat)] = [(0.181396484375, 0.8275146484375), (0.2474365234375, 0.8743896484375), (0.35009765625, 0.87615966796875), (0.41455078125, 0.8497314453125), (0.615234375, 0.8438720703125), (0.6767578125, 0.87109375), (0.77685546875, 0.8665771484375), (0.8388671875, 0.8228759765625), (0.235107421875, 0.70654296875), (0.2685546875, 0.72021484375), (0.313232421875, 0.726806640625), (0.354736328125, 0.721923828125), (0.393310546875, 0.708251953125), (0.359619140625, 0.69482421875), (0.3125, 0.693115234375), (0.270263671875, 0.693359375), (0.62890625, 0.70458984375), (0.66943359375, 0.71728515625), (0.70703125, 0.722412109375), (0.74853515625, 0.714111328125), (0.78564453125, 0.697509765625), (0.75146484375, 0.689453125), (0.705078125, 0.6865234375), (0.6650390625, 0.692138671875), (0.42041015625, 0.3642578125), (0.47998046875, 0.3701171875), (0.52783203125, 0.361328125), (0.57275390625, 0.37109375), (0.62548828125, 0.359375), (0.70458984375, 0.32373046875), (0.6103515625, 0.21728515625), (0.5185546875, 0.197265625), (0.42431640625, 0.216796875), (0.33203125, 0.330078125), (0.42626953125, 0.33154296875), (0.5244140625, 0.32177734375), (0.62060546875, 0.328125), (0.62744140625, 0.27099609375), (0.51953125, 0.2529296875), (0.40625, 0.2763671875), (0.111572265625, 0.702880859375), (0.10052490234375, 0.56884765625), (0.1220703125, 0.322265625), (0.212890625, 0.14013671875), (0.363525390625, 0.00146484375), (0.5166015625, -0.0341796875), (0.654296875, 0.0029296875), (0.80029296875, 0.14111328125), (0.88818359375, 0.32080078125), (0.9140625, 0.564453125), (0.89306640625, 0.7080078125), (0.470703125, 0.73046875), (0.447998046875, 0.574462890625), (0.3916015625, 0.48876953125), (0.461669921875, 0.48388671875), (0.52685546875, 0.44873046875), (0.595703125, 0.4833984375), (0.65478515625, 0.48681640625), (0.60107421875, 0.574951171875), (0.5595703125, 0.73388671875), (0.51953125, 0.746826171875), (0.52490234375, 0.660888671875), (0.5341796875, 0.53564453125), (0.31341552734375, 0.7081298828125), (0.7076416015625, 0.7030029296875)]
    
    
    let normalEyeHeight = [4.27692289328667, 5.6396484375, 4.271274946997859, 4.541015625, 6.189097265749245, 4.210010235382105]
    let closedEyeHeight = [1.432961971760663, 1.8626825742394997, 2.2290453536158843, 1.9871607172973274, 1.9441014698846146, 1.4924562222244067]
    
    var eyesHeightsValues : [[Double]] = []
    var eyesHeightsIntLabels : [Int] = [] //0 closed - 1 opened
    
    var kppv : KNearestNeighborsClassifier?
    
    var showEyesPoint = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sessionPrepare()
        //drawPoints(points: normalFaceExemple)
        print(getEyeHeights(facePoints: normalFaceExemple))
        
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
    
    func getEyesHeights(){
        loader.startAnimating()
        db.collection("eyesHeights").getDocuments { (snap, err) in
            for doc in snap?.documents ?? []{
                guard let values = doc.data()["values"] as? [Double],
                    let label = doc.data()["key"] as? String
                    ,label == "opened" || label == "closed"
                    else { continue }
                self.eyesHeightsValues.append(values)
                let intLabel = self.getIntLabel(label)
                self.eyesHeightsIntLabels.append(intLabel)
            }
            
            self.kppv = KNearestNeighborsClassifier(data: self.eyesHeightsValues, labels: self.eyesHeightsIntLabels)
            self.session?.startRunning()
            self.loader.stopAnimating()
            print("getEyesHeights ok")
            //self.testEyeHeightClassifieur()
        }
    }
    
    func getSmilesMouths(){
        db.collection("smileMouths").getDocuments { (snap, err) in
            for doc in snap?.documents ?? []{
                guard let values = doc.data()["values"] as? [String] else { continue }
                self.smiles.append(self.formatData(values))
            }
            self.getNormalMouths()
        }
    }
    
    func getNormalMouths(){
        db.collection("normalMouths").getDocuments { (snap, err) in
            for doc in snap?.documents ?? []{
                guard let values = doc.data()["values"] as? [String] else { continue }
                self.normals.append(self.formatData(values))
            }
            print("getMouths ok")
            //self.kppv(new: self.normalFaceExemple)
            //self.kppvSmile(new: self.smileExemple)
        }
    }
    
    func getOpenedEyes(){
        db.collection("openedEyes2").getDocuments { (snap, err) in
            for doc in snap?.documents ?? []{
                guard let values = doc.data()["values"] as? [String] else { continue }
                self.openedEyesData.append(self.formatData(values))
            }
            self.getClosedEyes()
        }
    }
    
    func getClosedEyes(){
        db.collection("closedEyes2").getDocuments { (snap, err) in
            for doc in snap?.documents ?? []{
                guard let values = doc.data()["values"] as? [String] else { continue }
                self.closedEyesData.append(self.formatData(values))
            }
            print("eyes ok")
            //self.testClassifieur()
        }
    }
    
    func getEyeHeights(facePoints : [(CGFloat, CGFloat)]) -> [Double]{
        var eyeHeights : [Double] = []
        let oposatePoints = [(9, 15),(10, 14),(11, 13),(17, 23),(18, 22),(19, 21)]
        
        for oposatePoint in oposatePoints {
            let dist = distance(facePoints[oposatePoint.0], facePoints[oposatePoint.1])
            eyeHeights.append(Double(dist) * 100)
        }
        
        return eyeHeights
    }
    
    func testEyeHeightClassifieur(){
        var xTrains : [[Double]] = []
        var yTrains : [Int] = []
        var xTests : [[Double]] = []
        var yTests : [Int] = []
        
        for i in 0..<eyesHeightsValues.count{
            let rand = Int.random(in: 0...100)
            if rand < 50{
                xTrains.append(eyesHeightsValues[i])
                yTrains.append(eyesHeightsIntLabels[i])
            }else{
                xTests.append(eyesHeightsValues[i])
                yTests.append(eyesHeightsIntLabels[i])
            }
        }
        
        let yPred = kppv?.predict(xTests) ?? []
        print(accuracy(yTests: yTests, yPred: yPred))
    }
    
    func getYPred( size : Int = 50) -> [Int]{
        let status = pushStatus == "opened" ? 1 : 0
        var yPred : [Int] = []
        for _ in 0..<size{
            yPred.append(status)
        }
        return yPred
    }
    
    func accuracy(yTests : [Int], yPred : [Int]) -> Double{
        var count : Double = 0
        for i in 0..<yTests.count{
            if yTests[i] == yPred[i] { count += 1 }
        }
        
        return count / Double(yPred.count)
    }
    
    func testClassifieur(){
        var xTrains : [[(CGFloat,CGFloat)]] = []
        var yTrains : [String] = []
        var xTests : [[(CGFloat,CGFloat)]] = []
        var yTests : [String] = []
        
        for closedEye in closedEyesData {
            let rand = Int.random(in: 0...100)
            if rand < 80{
                xTrains.append(closedEye)
                yTrains.append("closed")
            }else{
                xTests.append(closedEye)
                yTests.append("closed")
            }
        }
        
        for openedEye in openedEyesData {
            let rand = Int.random(in: 0...100)
            if rand < 80{
                xTrains.append(openedEye)
                yTrains.append("opened")
            }else{
                xTests.append(openedEye)
                yTests.append("opened")
            }
        }
        
        
        
        print("ok")
    }
    
    func kppvEyes(new : [(CGFloat,CGFloat)], k : Int = 3){
        var distances : [(String, Double)] = []
        
        for closedEye in closedEyesData {
            distances.append(("closed", getDistance(points1: closedEye, points2: new)))
        }
        for openedEye in openedEyesData {
            distances.append(("opened", getDistance(points1: openedEye, points2: new)))
        }
        
        distances.sort { (mouth1, mouth2) -> Bool in
            return mouth1.1 < mouth2.1
        }
        
        guard k < distances.count else { return }
        //print(distances[0...k])
        eyesAreClosed = areClosed(distances[0...k].map({$0.0}))
        //eyesAreClosed ? print("CLOSED") : print("OPENED")
    }
    
    func kppvSmile(new : [(CGFloat,CGFloat)], k : Int = 10){
        var distances : [(String, Double)] = []
        
        for smile in smiles {
            distances.append(("smile", getDistance(points1: smile, points2: new)))
        }
        for normal in normals {
            distances.append(("normal", getDistance(points1: normal, points2: new)))
        }
        
        distances.sort { (mouth1, mouth2) -> Bool in
            return mouth1.1 < mouth2.1
        }
        
        guard k < distances.count else { return }
        print(distances[0...k])
        isSmiling = isSmile(distances[0...k].map({$0.0}))
        isSmiling ? print("SMILING") : print("NORMAL")
    }
    
    func areClosed(_ values : [String]) -> Bool{
        var nbClosed = 0
        for value in values{
            if value == "closed" { nbClosed += 1 }
        }
        
        return nbClosed >= values.count
    }
    
    func isSmile(_ values : [String]) -> Bool{
        var nbSmile = 0
        for value in values{
            if value == "smile" { nbSmile += 1 }
        }
        
        return nbSmile >= values.count
    }
    
    func getDistance(points1 : [(CGFloat,CGFloat)], points2 : [(CGFloat,CGFloat)]) -> Double{
        var value : CGFloat = 0
        for i in 0..<points1.count{
            value += distance(points1[i], points2[i])
        }
        
        return Double(value)
    }
    
    func distance(_ a: (CGFloat,CGFloat), _ b: (CGFloat,CGFloat)) -> CGFloat {
        let xDist = a.0 - b.0
        let yDist = a.1 - b.1
        return CGFloat(sqrt(xDist * xDist + yDist * yDist))
    }
    
    func formatData(_ data : [String]) -> [(CGFloat,CGFloat)]{
        var mouth : [(CGFloat,CGFloat)] = []
        for value in data{
            let split = value.split(separator: "|")
            if var first = split.first, var last = split.last{
                
                first.removeLast()
                last.removeFirst()
                guard
                    let x = Double(String(first)),
                    let y = Double(String(last)) else { continue }
                
                mouth.append((CGFloat(x), CGFloat(y)))
            }
        }
        return mouth
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
        globalView.isHidden = false
        showEyesPoint = true
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { (timer) in
            self.canPush = true
        }
    }
    
    @IBAction func onSmile(_ sender: Any) {
        pushStatus = "opened"
        pushIn3Sec()
    }
    
    @IBAction func onNormal(_ sender: Any) {
        pushStatus = "closed"
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
                            
                            let eyeHeights = self.getEyeHeights(facePoints: self.currentFace)
                            let pred = self.kppv?.predict([eyeHeights]) ?? []
                            //print(self.kppv?.predict([eyeHeights]) ?? [])
                            
                            self.pushEyesHeights(eyeHeights)
                            self.checkEyeStatus(pred.first ?? 0)
                            self.currentEyeLabel = pred.first ?? 0
                            self.setFaceLabel(status: self.currentEyeLabel)
                        }
                    }
                }
            }
        }
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
            eyeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { (timer) in
                print("\(status) confirmed")
                if status == 0 && self.canPush == false {
                    AudioServicesPlaySystemSound (self.systemSoundID)
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                } //WAKE UP
            })
        }else {
            eyeTimer?.invalidate()
        }
    }
    
    func pushEyesHeights(_ points : [Double]){
        guard canPush else { return }
        if countPushes >= 50 {
            let pred = kppv?.predict(pushedEyes) ?? []
            let acc = accuracy(yTests: pred, yPred: getYPred()) * 100
            let action = UIAlertAction(title: "Send", style: .default) { (action) in
                for eye in self.pushedEyes{
                    self.db.collection("eyesHeights").addDocument(data: ["values": eye, "key" : self.pushStatus])
                }
                self.eyesHeightsValues.append(contentsOf: self.pushedEyes)
                let intLabels = self.getYPred()
                self.eyesHeightsIntLabels.append(contentsOf: intLabels)
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
        //self.db.collection("eyesHeights").addDocument(data: ["values": points, "key" : "rightClosed"])
        countPushes += 1
    }
    
    func pushData(_ points : [CGPoint]){
        guard canPush else { return }
        if countPushes >= 50 {
            print("FINISHED")
            session?.stopRunning()
            return
        }
        let mouths = Array(points[24...39]).map({( "\($0.x) | \($0.y)" )})
        
        var eyes = Array(points[8...23]).map({( "\($0.x) | \($0.y)" )})
        eyes.append(contentsOf: points[63...64].map({( "\($0.x) | \($0.y)" )}))

        self.db.collection("openedEyes2").addDocument(data: ["values": eyes])
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
            
            let mouth = Array(faceLandmarkVertices[24...39])
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

