//
//  ViewController.swift
//  ObjectTrackingML
//
//  Created by Avinash Reddy on 11/11/17.
//  Copyright © 2017 Avinash Reddy. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet var cameraView: UIView!
    
    // didSet is used to set the overlay on the fly while running the project
    @IBOutlet weak var overlayView: UIView! 	 {
        didSet {
            self.overlayView.layer.borderColor = UIColor.green.cgColor
            self.overlayView.layer.borderWidth = 5
            self.overlayView.layer.cornerRadius = 8
            self.overlayView.backgroundColor = .clear
        }
    }
    
    lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard let backCamera =  AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: backCamera) else {
            return session
        }
        session.addInput(input)
        return session
    }()
    lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    
    var previousObservation : VNDetectedObjectObservation?
    let visionSequenceHandler = VNSequenceRequestHandler()
    let confidenceThreshold: Float = 0.45
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "ObjectTrackingQueue"))
        self.captureSession.addOutput(videoOutput)
        self.captureSession.startRunning()
        
        self.overlayView.frame = .zero
        self.cameraView.layer.addSublayer(self.cameraLayer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // CXPixelBuffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let lastObservation = self.previousObservation else {
            return
        }
        
        let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: self.handleVisionRequestUpdate)
        request.trackingLevel = VNRequestTrackingLevel.accurate
        
        do {
            try self.visionSequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("error performing the object tracking request")
        }
        
    }
    
    func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let currentObservation = request.results?.first as? VNDetectedObjectObservation else {
                return
            }
            
            self.previousObservation = currentObservation
            
            // we need to make sure that what we see on the screen has a high enough probsbility of being correct ( > 0.4 -> between 0 and 1)
            guard currentObservation.confidence >= self.confidenceThreshold else {
                self.overlayView.frame = .zero
                return
            }
            
            var currentBoundingBox = currentObservation.boundingBox
            currentBoundingBox.origin.y = 1 - currentBoundingBox.origin.y
            let newBoundingBox = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: currentBoundingBox)
            
            self.overlayView.frame = newBoundingBox
        }
    }

    
    

    @IBAction func pressedScreen(_ sender: UITapGestureRecognizer) {
        print("screen tap")
        self.overlayView.frame.size = CGSize(width: 100, height: 100)
        self.overlayView.center = sender.location(in: self.view)
        
        let originalRect = self.overlayView?.frame ?? .zero
        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        let currentObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.previousObservation = currentObservation    }
    
}

