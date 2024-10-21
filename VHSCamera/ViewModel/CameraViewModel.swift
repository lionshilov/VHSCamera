//
//  CameraViewModel.swift
//  VHSCamera
//
//  Created by Лев Шилов on 19.10.2024.
//

import Foundation
import AVFoundation
import SwiftUI
import CoreImage

class CameraViewModel: NSObject, ObservableObject {
    
    @Published var session = AVCaptureSession()
    @Published var isRecording = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isPhotoMode = true
    @Published var capturedImage: UIImage?
    @Published var processedFrame: UIImage?
    @Published var selectedFilter: String = "Retro"
    
    // Приватные свойства
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    private let context = CIContext()
    
    // Свойства для записи видео с эффектом
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime?
    
    override init() {
        super.init()
        configureSession()
    }
    
    // MARK: - Конфигурация сессии
    private func configureSession() {
        session.beginConfiguration()
        
        // Настройка видео входа
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Нет доступной камеры.")
            session.commitConfiguration()
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
        
        // Настройка аудио входа (для записи звука)
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
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
        }
        
        // Настройка фото выхода
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // Настройка видео выхода для обработки кадров
        if session.canAddOutput(videoDataOutput) {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = false
            }
        } else {
            print("Не удалось добавить видео выход для обработки кадров в сессию.")
            session.commitConfiguration()
            return
        }
        
        session.commitConfiguration()
    }
    
    // MARK: - Управление сессией
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
    
    // MARK: - Управление фото и видео
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func startRecording() {
        if !isRecording {
            let outputFileName = NSUUID().uuidString
            let outputFilePath = NSTemporaryDirectory() + "\(outputFileName).mov"
            let outputURL = URL(fileURLWithPath: outputFilePath)
            
            do {
                assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
                
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: NSNumber(value: 1080),
                    AVVideoHeightKey: NSNumber(value: 1920)
                ]
                
                assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                assetWriterInput?.expectsMediaDataInRealTime = true
                
                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: NSNumber(value: 1080),
                    kCVPixelBufferHeightKey as String: NSNumber(value: 1920)
                ]
                
                pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: assetWriterInput!,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )
                
                // Добавление аудио входа для записи звука
                let audioSettings = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 44100.0,
                    AVEncoderBitRateKey: 64000
                ] as [String : Any]
                
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput.expectsMediaDataInRealTime = true
                
                if assetWriter!.canAdd(assetWriterInput!) {
                    assetWriter!.add(assetWriterInput!)
                }
                
                if assetWriter!.canAdd(audioInput) {
                    assetWriter!.add(audioInput)
                }
                
                assetWriter!.startWriting()
                isRecording = true
            } catch {
                print("Ошибка инициализации записи: \(error)")
            }
        }
    }
    
    func stopRecording() {
        if isRecording {
            isRecording = false
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting {
                print("Запись завершена")
                if let url = self.assetWriter?.outputURL {
                    UISaveVideoAtPathToSavedPhotosAlbum(url.path, nil, nil, nil)
                }
                self.assetWriter = nil
                self.assetWriterInput = nil
                self.pixelBufferAdaptor = nil
                self.recordingStartTime = nil
            }
        }
    }
    
    // MARK: - Переключение камеры
    func switchCamera() {
        guard let currentInput = videoDeviceInput else { return }
        let currentPosition = currentInput.device.position
        let preferredPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: preferredPosition) else {
            print("Нет доступной камеры в позиции \(preferredPosition).")
            return
        }

        do {
            let newVideoInput = try AVCaptureDeviceInput(device: newDevice)
            session.beginConfiguration()

            // Удаление текущего видео входа
            session.removeInput(currentInput)

            // Добавление нового видео входа
            if session.canAddInput(newVideoInput) {
                session.addInput(newVideoInput)
                videoDeviceInput = newVideoInput
            } else {
                print("Не удалось добавить новый видео вход в сессию.")
                // Восстановление старого входа в случае неудачи
                if session.canAddInput(currentInput) {
                    session.addInput(currentInput)
                }
                session.commitConfiguration()
                return
            }

            // Обновление настроек соединения `videoDataOutput`
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                connection.isVideoMirrored = (preferredPosition == .front)
            }

            session.commitConfiguration()
        } catch {
            print("Ошибка при переключении камеры: \(error)")
            session.commitConfiguration()
        }
    }
    
    // MARK: - Управление фокусом и зумом
    func focus(at point: CGPoint) {
        let device = videoDeviceInput.device
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            print("Ошибка установки фокуса: \(error)")
        }
    }
    
    func zoom(delta: CGFloat) {
        let device = videoDeviceInput.device
        do {
            try device.lockForConfiguration()
            let zoomFactor = min(max(device.videoZoomFactor * delta, 1.0), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = zoomFactor
            device.unlockForConfiguration()
        } catch {
            print("Ошибка зума: \(error)")
        }
    }
    
    // MARK: - Вспомогательные методы
    func toggleFlash() {
        flashMode = flashMode == .on ? .off : .on
    }
    
    // Создание пиксельного буфера из CIImage
    func createPixelBuffer(from image: CIImage) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: NSNumber(value: Int(image.extent.width)),
            kCVPixelBufferHeightKey as String: NSNumber(value: Int(image.extent.height)),
            kCVPixelBufferCGImageCompatibilityKey as String: NSNumber(value: true),
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: NSNumber(value: true)
        ]
        
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height),
                            kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer)
        
        guard let buffer = pixelBuffer else { return nil }
        
        context.render(image, to: buffer)
        return buffer
    }
}

// MARK: - Обработка фотографий
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else { return }
        var ciImage = CIImage(data: imageData)
        
        // Применяем выбранный фильтр к фото
        ciImage = applyFilter(to: ciImage)
        
        // Конвертируем обратно в UIImage
        if let ciImage = ciImage, let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            capturedImage = UIImage(cgImage: cgImage)
            
            // Сохранение фотографии в библиотеку
            UIImageWriteToSavedPhotosAlbum(capturedImage!, nil, nil, nil)
        }
    }
}

// MARK: - Обработка видеопотока
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Получение изображения из буфера
        guard let ciImage = getCIImage(from: sampleBuffer) else { return }
        
        // Применение выбранного фильтра
        guard let filteredImage = applyFilter(to: ciImage) else { return }
        
        // Конвертация в UIImage для отображения
        if let cgImage = context.createCGImage(filteredImage, from: filteredImage.extent) {
            let uiImage = UIImage(cgImage: cgImage)
            
            DispatchQueue.main.async {
                self.processedFrame = uiImage
            }
        }
        
        // Запись видео с эффектом VHS (если запись активна)
        if isRecording {
            if assetWriter?.status == .unknown {
                if let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) as CMTime? {
                    assetWriter?.startSession(atSourceTime: timeStamp)
                    recordingStartTime = timeStamp
                }
            }
            
            if let pixelBuffer = createPixelBuffer(from: filteredImage),
               let input = assetWriterInput,
               input.isReadyForMoreMediaData {
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                let frameTime = CMTimeSubtract(presentationTime, recordingStartTime ?? CMTime.zero)
                pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: frameTime)
            }
        }
    }
    
    // Метод для получения CIImage из CMSampleBuffer
    private func getCIImage(from sampleBuffer: CMSampleBuffer) -> CIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return CIImage(cvPixelBuffer: pixelBuffer)
    }
    
    // Метод для применения выбранного фильтра
    func applyFilter(to ciImage: CIImage?) -> CIImage? {
        guard let ciImage = ciImage else { return nil }
        
        let filteredImage: CIImage?
        switch selectedFilter {
        case "Retro":
            filteredImage = ciImage.applyingFilter("CIPhotoEffectTransfer")
        case "1980s":
            filteredImage = ciImage.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 6])
        case "Vintage":
            filteredImage = ciImage.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 1.0])
        case "Noise":
            filteredImage = ciImage.applyingFilter("CINoiseReduction", parameters: ["inputNoiseLevel": 0.02])
        default:
            filteredImage = ciImage
        }
        
        return filteredImage
    }
}

