//
//  ContentView.swift
//  VHSCamera
//
//  Created by Лев Шилов on 19.10.2024.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Элементы управления
                HStack {
                    Button(action: {
                        viewModel.switchCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if viewModel.isPhotoMode {
                            viewModel.capturePhoto()
                        } else {
                            viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
                        }
                    }) {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 4)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : Color.white)
                                    .frame(width: 65, height: 65)
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.toggleFlash()
                    }) {
                        Image(systemName: viewModel.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                
                // Переключатель режимов
                HStack {
                    Button(action: {
                        viewModel.isPhotoMode = true
                    }) {
                        Text("Фото")
                            .foregroundColor(viewModel.isPhotoMode ? .yellow : .white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.isPhotoMode = false
                    }) {
                        Text("Видео")
                            .foregroundColor(!viewModel.isPhotoMode ? .yellow : .white)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

