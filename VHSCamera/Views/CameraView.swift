//
//  CameraView.swift
//  VHSCamera
//
//  Created by Лев Шилов on 19.10.2024.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    let filters = ["Retro", "1980s", "Vintage", "Noise"]

    var body: some View {
        ZStack {
            // Превью камеры с примененным фильтром
            ProcessedCameraPreview(viewModel: viewModel)
                .ignoresSafeArea()

            VStack {
                // Верхняя панель с элементами управления
                HStack {
                    Button(action: {
                        viewModel.toggleFlash()
                    }) {
                        Image(systemName: viewModel.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        // Дополнительные настройки или кнопка переключения режимов
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: {
                        viewModel.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.2))

                Spacer()

                // Элементы управления внизу
                VStack(spacing: 0) {
                    // Селектор VHS фильтров
                    FilterPickerView(selectedFilter: $viewModel.selectedFilter, filters: filters)
                        .padding(.bottom, 10)

                    // Кнопки управления
                    HStack {
                        Spacer()

                        // Кнопка захвата
                        Button(action: {
                            if viewModel.isPhotoMode {
                                viewModel.capturePhoto()
                            } else {
                                viewModel.isRecording ? viewModel.stopRecording() : viewModel.startRecording()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .fill(viewModel.isRecording ? Color.red : Color.white)
                                    .frame(width: 50, height: 50)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .background(Color.black.opacity(0.2))
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

// Дополнительный View для селектора VHS фильтров
struct FilterPickerView: View {
    @Binding var selectedFilter: String
    let filters: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(filters, id: \.self) { filter in
                Text(filter)
                    .foregroundColor(selectedFilter == filter ? .white : .gray)
                    .font(.system(size: selectedFilter == filter ? 18 : 14))
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation {
                            selectedFilter = filter
                        }
                    }
            }
        }
    }
}
