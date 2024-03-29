//
//  MainView.swift
//  OceanEye
//
//  Created by Tanvir Ahmed, Nayed Ali, MD Uddin  on 11/4/23.
//

import Vision
import CoreML
import SwiftUI
import CommonCrypto
import Firebase
import UIKit
import PhotosUI


struct MainView: View {
    @State private var isImagePickerPresented = false
    @State private var originalImage: UIImage?
    @State private var matchingFish: Fish?
    @State private var isInvalidImageAlertPresented = false
    @State private var isIdentifying = false

    
    func calculateHash(image: UIImage) -> String {
        if let imageData = image.pngData() {
            var hashData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
            _ = hashData.withUnsafeMutableBytes { hashBytes in
                imageData.withUnsafeBytes { dataBytes in
                    CC_SHA256(dataBytes, CC_LONG(imageData.count), hashBytes)
                }
            }
            return hashData.map { String(format: "%02hhx", $0) }.joined()
        } else {
            return "Image data is not available."
        }
    }


    func fetchFirebaseData(imageHash: String) {
        let firebaseURL = "https://oceaneye-17058-default-rtdb.firebaseio.com/.json"

        guard let url = URL(string: firebaseURL) else {
            print("Invalid Firebase URL")
            return
        }

        isIdentifying = true

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching data from Firebase: \(error)")
                return
            }

            if let data = data {
                do {
                    let fishData = try JSONDecoder().decode([String: Fish].self, from: data)

                   
                    if let matchedFish = fishData.values.first(where: { $0.hash == imageHash }) {
                        self.matchingFish = matchedFish
                    } else {
                        self.matchingFish = nil
                        self.isInvalidImageAlertPresented = true
                    }
                } catch {
                    print("Error decoding data: \(error)")
                }
            }
        }

        task.resume()
    }

    var body: some View {
        ZStack {
            Text("OceanEye")
                .font(.title2)
                .fontWeight(.heavy)
                .position(x:200 ,y:30 )
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)

            VStack {
                ZStack {
                    Color.white.opacity(0.35)
                        .frame(width: 350, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 10)

                    Rectangle()
                        .stroke(Color.white, lineWidth: 0)
                        .frame(width: 250, height: 200)

                    if let originalImage = originalImage {
                        Image(uiImage: originalImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250, height: 200)
                            .clipped()
                    } else {
                        Text("Uploaded Picture Preview")
                            .foregroundColor(.black)
                            .font(.subheadline)
                    }
                }

                Spacer().frame(height: 40)

                Button(action: {
                    self.isImagePickerPresented = true
                }) {
                    Text("Upload Picture")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(color: .gray, radius: 5, x: 0, y: 3)
                }
                .sheet(isPresented: $isImagePickerPresented) {
                    ImagePicker(selectedImage: $originalImage)
                }

                Spacer().frame(height: 50)

                Button(action: {
                    if let originalImage = originalImage {
                        let imageHash = calculateHash(image: originalImage)
                        fetchFirebaseData(imageHash: imageHash)
                    } else {
                        print("Please upload an image first.")
                    }
                }) {
                    Text("Identify Fish 🔍")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .shadow(color: .gray, radius: 5, x: 0, y: 3)
                }
                .disabled(originalImage == nil)

                if matchingFish != nil {
                    FishDetailView(fish: matchingFish!)
                } else {
                    DetailsPlaceholderView()
                }
            }
        }
        .alert(isPresented: $isInvalidImageAlertPresented) {
            Alert(
                title: Text("Oops!"),
                message: Text("Please submit a higher resolution picture of a fish to be identified."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct Fish: Decodable {
    let hash: String
    let name: String
    let habitat: String
    let scientific: String
    let size: String
    let status: String
}

struct FishDetailView: View {
    let fish: Fish

    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 350, height: 200)
            .cornerRadius(10)
            .padding(.top, 20)
            .overlay(
                VStack(spacing: 10) {
                    Spacer()
                    Text("Name: \(fish.name)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text("Habitat: \(fish.habitat)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text("Scientific Name: \(fish.scientific)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text("Size: \(fish.size)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text("Status: \(fish.status)")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            )
    }
}

struct DetailsPlaceholderView: View {
    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 360, height: 200)
            .cornerRadius(10)
            .padding(.top, 20)
            .overlay(
                VStack(spacing: 10) {
                    Spacer()
                    Text("Fish Information")
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            )
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}


