import AVFoundation
import PhotosUI
import SwiftUI
import Vision

/// Point the camera at food (or a barcode) and log it.
/// Photo mode runs Vision's on-device classifier over a captured frame; barcode
/// mode reads EAN/UPC and looks the product up on OpenFoodFacts.
struct CameraScanView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case food = "Food photo"
        case barcode = "Barcode"
        var id: String { rawValue }
    }

    let day: Date
    let meal: Meal
    var onLogged: () -> Void

    @Environment(NutritionStore.self) private var nutrition
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .food
    @State private var torchOn = false
    @State private var isWorking = false
    @State private var statusText: String?
    @State private var guesses: [FoodGuess] = []
    @State private var showingGuesses = false
    @State private var offProduct: OFFProduct?
    @State private var pickedItem: PhotosPickerItem?
    @State private var captureRequested = false
    @State private var handledBarcode = false

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreview(torchOn: torchOn,
                              captureRequested: $captureRequested,
                              onPhoto: { image in classify(image) },
                              onBarcode: { code in
                                  guard mode == .barcode, !handledBarcode else { return }
                                  handledBarcode = true
                                  lookup(barcode: code)
                              })
                    .ignoresSafeArea()

                ScanOverlay(active: isWorking || mode == .barcode)

                VStack {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 40)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)

                    Spacer()

                    if let statusText {
                        Text(statusText)
                            .font(.subheadline.bold())
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 8)
                    }

                    HStack(spacing: 40) {
                        // Torch — "bright light if it can't see".
                        Button {
                            torchOn.toggle()
                        } label: {
                            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(.ultraThinMaterial, in: Circle())
                        }

                        if mode == .food {
                            Button {
                                statusText = "Scanning…"
                                isWorking = true
                                captureRequested = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 4)
                                        .frame(width: 74, height: 74)
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 60, height: 60)
                                }
                            }
                            .disabled(isWorking)
                        }

                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(mode == .food ? "Scan Food" : "Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                statusText = "Scanning photo…"
                isWorking = true
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        classify(image)
                    } else {
                        finishScan(message: "Couldn't read that photo.")
                    }
                    pickedItem = nil
                }
            }
            .onChange(of: mode) { _, _ in
                handledBarcode = false
                statusText = mode == .barcode ? "Line up the barcode" : nil
            }
            .sheet(isPresented: $showingGuesses) {
                FoodGuessList(guesses: guesses, day: day, meal: meal) {
                    dismiss()
                    onLogged()
                }
                .presentationDetents([.medium, .large])
                .onDisappear { handledBarcode = false }
            }
            .sheet(item: $offProduct) { product in
                ServingSheet(product: product, day: day, meal: meal) {
                    dismiss()
                    onLogged()
                }
                .presentationDetents([.medium])
                .onDisappear { handledBarcode = false }
            }
        }
    }

    // MARK: - Food classification (on-device Vision)

    private func classify(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            finishScan(message: "Couldn't read that photo.")
            return
        }
        Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            let observations = request.results ?? []

            var found: [FoodGuess] = []
            for observation in observations where observation.confidence > 0.05 {
                guard let food = GenericFoods.match(observation.identifier) else { continue }
                if !found.contains(where: { $0.food.id == food.id }) {
                    found.append(FoodGuess(food: food, confidence: Double(observation.confidence)))
                }
                if found.count >= 6 { break }
            }

            await MainActor.run {
                if found.isEmpty {
                    finishScan(message: "Couldn't tell what that is — try the light, get closer, or use search.")
                } else {
                    finishScan(message: nil)
                    guesses = found
                    showingGuesses = true
                }
            }
        }
    }

    // MARK: - Barcode lookup

    private func lookup(barcode: String) {
        statusText = "Looking up \(barcode)…"
        isWorking = true
        Task {
            let product = try? await OpenFoodFactsClient.product(barcode: barcode)
            if let product {
                finishScan(message: nil)
                offProduct = product
            } else {
                finishScan(message: "No match for \(barcode) — try search or quick add.")
                handledBarcode = false
            }
        }
    }

    private func finishScan(message: String?) {
        isWorking = false
        statusText = message
    }
}

struct FoodGuess: Identifiable, Hashable {
    var id: String { food.id }
    let food: GenericFood
    let confidence: Double
}

/// The "x-ray" sweep line over the viewfinder.
struct ScanOverlay: View {
    let active: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !active)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
                let y = geo.size.height * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)
                Rectangle()
                    .fill(LinearGradient(colors: [.green.opacity(0), .green.opacity(0.8), .green.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 60)
                    .position(x: geo.size.width / 2, y: y)
                    .opacity(active ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Guesses from the classifier — pick one, adjust the serving, log it.
struct FoodGuessList: View {
    let guesses: [FoodGuess]
    let day: Date
    let meal: Meal
    var onAdded: () -> Void

    @Environment(NutritionStore.self) private var nutrition
    @Environment(\.dismiss) private var dismiss
    @State private var selected: FoodGuess?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Best guesses — macros are typical estimates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(guesses) { guess in
                    Button {
                        selected = guess
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(guess.food.name)
                                    .foregroundStyle(.primary)
                                Text("\(Int(guess.food.caloriesPer100g)) kcal / 100 g · typical serving \(Int(guess.food.servingGrams)) g")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(guess.confidence * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Detected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
            }
            .sheet(item: $selected) { guess in
                ServingSheet(product: OFFProduct(code: "generic-\(guess.food.id)",
                                                 name: guess.food.name,
                                                 brand: "Estimate",
                                                 caloriesPer100g: guess.food.caloriesPer100g,
                                                 proteinPer100g: guess.food.proteinPer100g,
                                                 carbsPer100g: guess.food.carbsPer100g,
                                                 fatPer100g: guess.food.fatPer100g,
                                                 servingSize: "\(Int(guess.food.servingGrams)) g"),
                             day: day, meal: meal) {
                    dismiss()
                    onAdded()
                }
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Camera plumbing

struct CameraPreview: UIViewControllerRepresentable {
    var torchOn: Bool
    @Binding var captureRequested: Bool
    var onPhoto: (UIImage) -> Void
    var onBarcode: (String) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onPhoto = onPhoto
        controller.onBarcode = onBarcode
        return controller
    }

    func updateUIViewController(_ controller: CameraViewController, context: Context) {
        controller.setTorch(on: torchOn)
        if captureRequested {
            controller.capturePhoto()
            DispatchQueue.main.async {
                captureRequested = false
            }
        }
    }
}

final class CameraViewController: UIViewController,
                                  AVCapturePhotoCaptureDelegate,
                                  AVCaptureMetadataOutputObjectsDelegate {
    var onPhoto: ((UIImage) -> Void)?
    var onBarcode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    private var configured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted else { return }
            DispatchQueue.main.async {
                self?.configureSession()
            }
        }
    }

    private func configureSession() {
        guard !configured,
              let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        configured = true
        self.device = device

        session.beginConfiguration()
        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        let metadata = AVCaptureMetadataOutput()
        if session.canAddOutput(metadata) {
            session.addOutput(metadata)
            metadata.setMetadataObjectsDelegate(self, queue: .main)
            let wanted: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128]
            metadata.metadataObjectTypes = wanted.filter {
                metadata.availableMetadataObjectTypes.contains($0)
            }
        }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        setTorch(on: false)
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func setTorch(on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    func capturePhoto() {
        guard configured else { return }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        onPhoto?(image)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue else { return }
        onBarcode?(code)
    }
}
