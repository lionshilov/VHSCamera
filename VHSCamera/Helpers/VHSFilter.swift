//
//  VHSFilter.swift
//  VHSCamera
//
//  Created by Лев Шилов on 19.10.2024.
//


import CoreImage
import UIKit

class VHSFilter {
    private let context = CIContext()
    
    func apply(to image: CIImage) -> CIImage? {
        // 1. Применение эффекта интерлейсинга
        guard let interlacedImage = applyInterlacing(to: image) else { return image }
        
        // 2. Добавление шумов и зернистости
        guard let noisyImage = addNoise(to: interlacedImage) else { return interlacedImage }
        
        // 3. Применение хроматической аберрации
        guard let aberratedImage = applyChromaticAberration(to: noisyImage) else { return noisyImage }
        
        // 4. Добавление дефектов ленты
        guard let distortedImage = addTapeDefects(to: aberratedImage) else { return aberratedImage }
        
        // 5. Регулировка цветовой палитры
        guard let colorAdjustedImage = adjustColors(of: distortedImage) else { return distortedImage }
        
        return colorAdjustedImage
    }
    
    // MARK: - Приватные методы
    
    // 1. Эффект интерлейсинга
    private func applyInterlacing(to image: CIImage) -> CIImage? {
        // Создание полос для имитации интерлейсинга
        let lineHeight: CGFloat = 2
        let spacing: CGFloat = 4
        let color = UIColor.black.withAlphaComponent(0.1)
        
        UIGraphicsBeginImageContext(image.extent.size)
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.setFillColor(color.cgColor)
        
        var y: CGFloat = 0
        while y < image.extent.size.height {
            context.fill(CGRect(x: 0, y: y, width: image.extent.size.width, height: lineHeight))
            y += lineHeight + spacing
        }
        
        guard let stripesImage = UIGraphicsGetImageFromCurrentImageContext()?.ciImage else {
            UIGraphicsEndImageContext()
            return image
        }
        UIGraphicsEndImageContext()
        
        // Наложение полос на изображение
        return stripesImage.composited(over: image)
    }
    
    // 2. Добавление шумов и зернистости
    private func addNoise(to image: CIImage) -> CIImage? {
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator") else { return image }
        guard let noiseImage = noiseFilter.outputImage?.cropped(to: image.extent) else { return image }
        
        let noiseIntensity: CGFloat = 0.02
        let noiseAdjusted = noiseImage.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: -0.1,
            kCIInputContrastKey: 1.0,
            kCIInputSaturationKey: 0
        ]).applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: noiseIntensity, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: noiseIntensity, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: noiseIntensity, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)
        ])
        
        // Смешивание шума с исходным изображением
        return image.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: noiseAdjusted
        ])
    }
    
    // 3. Применение хроматической аберрации
    private func applyChromaticAberration(to image: CIImage) -> CIImage? {
        let displacement: CGFloat = 2
        
        // Смещение красного канала
        let redImage = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).transformed(by: CGAffineTransform(translationX: -displacement, y: 0))
        
        // Смещение зеленого канала
        let greenImage = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        
        // Смещение синего канала
        let blueImage = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).transformed(by: CGAffineTransform(translationX: displacement, y: 0))
        
        // Объединение цветовых каналов
        let combinedImage = redImage
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: greenImage])
            .applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: blueImage])
        
        return combinedImage
    }
    
    // 4. Добавление дефектов ленты
    private func addTapeDefects(to image: CIImage) -> CIImage? {
        // Создание случайных вертикальных линий
        let scratchIntensity: CGFloat = 0.05
        let scratches = generateScratches(size: image.extent.size, intensity: scratchIntensity)
        
        // Наложение дефектов на изображение
        return scratches?.composited(over: image)
    }
    
    private func generateScratches(size: CGSize, intensity: CGFloat) -> CIImage? {
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(intensity).cgColor)
        context.setLineWidth(1)
        
        for _ in 0..<Int(size.width / 50) {
            let x = CGFloat.random(in: 0...size.width)
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: size.height))
            context.strokePath()
        }
        
        let scratchesImage = UIGraphicsGetImageFromCurrentImageContext()?.ciImage
        UIGraphicsEndImageContext()
        
        return scratchesImage
    }
    
    // 5. Регулировка цветовой палитры
    private func adjustColors(of image: CIImage) -> CIImage? {
        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 1.2,
            kCIInputBrightnessKey: -0.05,
            kCIInputContrastKey: 1.1
        ])
    }
}

