//
//  CameraViewModel.swift
//  VHSCamera
//
//  Created by Лев Шилов on 19.10.2024.
//


import Foundation
import AVFoundation
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {

    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isPhotoMode = true
    @Published var capturedImage: UIImage?
    
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var backgroundRecordingID: UIBackgroundTaskIdentifier?
    
    override init() {
        super.init()
        configureSession()
    }
    
    private func configureSession() {
        session.beginConfiguration()
        
        // Добавление видео входа
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Нет доступной камеры.")
            return
        }
        
        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
            } else {
                print("Не удалось добавить видео вход в сессию.")
                session.commitConfiguration()
                return
            }
        } catch {
            print("Ошибка при создании видео входа: \(error)")
            session.commitConfiguration()
            return
        }
        
        // Добавление аудио входа
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            print("Нет доступного микрофона.")
            return
        }
        
        do {
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                print("Не удалось добавить аудио вход в сессию.")
            }
        } catch {
            print("Ошибка при создании аудио входа: \(error)")
        }
        
        // Добавление фото выхода
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        } else {
            print("Не удалось добавить фото выход в сессию.")
            session.commitConfiguration()
            return
        }
        
        // Добавление видео выхода
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        } else {
            print("Не удалось добавить видео выход в сессию.")
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    // Функции для фотографирования и записи видео
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func startRecording() {
        if !movieOutput.isRecording {
            let connection = movieOutput.connection(with: .video)
            connection?.videoOrientation = .portrait
            
            // Настройка выходного файла
            let outputFileName = NSUUID().uuidString
            let outputFilePath = NSTemporaryDirectory() + "\(outputFileName).mov"
            let outputURL = URL(fileURLWithPath: outputFilePath)
            
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            isRecording = true
        }
    }
    
    func stopRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
            isRecording = false
        }
    }
    
    func switchCamera() {
        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else { return }
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        let newCameraDevice = currentInput.device.position == .back ? getCamera(position: .front) : getCamera(position: .back)
        
        do {
            let newVideoInput = try AVCaptureDeviceInput(device: newCameraDevice!)
            session.addInput(newVideoInput)
            videoDeviceInput = newVideoInput
        } catch {
            print("Ошибка при переключении камеры: \(error)")
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
    }
    
    private func getCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.devices(for: .video).first { $0.position == position }
    }
    
    func toggleFlash() {
        flashMode = flashMode == .on ? .off : .on
    }
    
    func updateVideoOrientation() {
        guard let connection = movieOutput.connection(with: .video) else { return }
        if connection.isVideoOrientationSupported {
            switch UIDevice.current.orientation {
            case .portrait:
                connection.videoOrientation = .portrait
            case .landscapeRight:
                connection.videoOrientation = .landscapeLeft
            case .landscapeLeft:
                connection.videoOrientation = .landscapeRight
            case .portraitUpsideDown:
                connection.videoOrientation = .portraitUpsideDown
            default:
                connection.videoOrientation = .portrait
            }
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        capturedImage = UIImage(data: imageData)
        
        // Сохранение фотографии в библиотеку
        UIImageWriteToSavedPhotosAlbum(capturedImage!, nil, nil, nil)
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Сохранение видео в библиотеку
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
    }
}
