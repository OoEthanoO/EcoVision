import SwiftUI
import Photos

struct ContentView: View {
    @State private var processedImage: UIImage?
    @State private var capturedFrame: UIImage?
    @State private var isDetecting = false

    var body: some View {
        GeometryReader { geometry in
            VStack {
                CameraView(capturedFrame: $capturedFrame)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack {
                            if isDetecting {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.green)
                                    .padding(20)
                            }
                            HStack {
                                if processedImage != nil {
                                    Button(action: {
                                        saveImageToPhotos(image: processedImage!)
                                    }) {
                                        Text("Save to Photos")
                                            .padding()
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                }
                                
                                Button(action: {
                                    if processedImage != nil {
                                        processedImage = nil
                                    } else {
                                        captureAndSendFrame()
                                    }
                                }) {
                                    Text(processedImage != nil ? "Cancel" : "Detect Objects")
                                        .padding()
                                        .background(isDetecting ? Color.gray : (processedImage != nil ? Color.red : Color.green))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .disabled(isDetecting)
                            }
                        }
                        .padding(),
                        alignment: .bottom
                    )
                
                if let image = processedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.8)
                        .padding()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func captureAndSendFrame() {
        guard let frame = captureFrameFromCamera() else {
            print("Error: No frame captured")
            return
        }
        
        isDetecting = true
        
        sendFrameToServer(frame: frame) { result in
            DispatchQueue.main.async {
                self.isDetecting = false
                switch result {
                case .success(let image):
                    self.processedImage = image
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
    }

    private func captureFrameFromCamera() -> UIImage? {
        return capturedFrame
    }

    private func sendFrameToServer(frame: UIImage, completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard let url = URL(string: "https://wise-frogs-think.loca.lt/detect") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("any-value", forHTTPHeaderField: "bypass-tunnel-reminder")

        let imageData = frame.jpegData(compressionQuality: 1.0)!
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            completion(.success(image))
        }.resume()
    }
    
    private func saveImageToPhotos(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            } else {
                print("Error: Photo library access not authorized")
            }
        }
    }
}

#Preview {
    ContentView()
}
