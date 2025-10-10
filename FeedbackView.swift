import SwiftUI
import UIKit
import MessageUI
import PhotosUI
import TelemetryDeck

// MARK: - View Model

final class FeedbackViewModel: ObservableObject {
    // Inputs
    @Published var topic: String = "" { didSet { if topic.count > Self.maxTopic { topic = String(topic.prefix(Self.maxTopic)) } } }
    @Published var details: String = "" { didSet { if details.count > Self.maxDetails { details = String(details.prefix(Self.maxDetails)) } } }

    // Images for thumbnails and attachments
    @Published var images: [UIImage] = []

    // UI state
    @Published var toastMessage: String? = nil
    @Published var isProcessing: Bool = false
    @Published var showMailComposer: Bool = false
    @Published var showShareSheet: Bool = false

    static let maxTopic = 80
    static let maxDetails = 1000
    static let maxPhotos = 5

    var topicCount: Int { topic.count }
    var detailsCount: Int { details.count }
    var remainingPhotos: Int { max(0, Self.maxPhotos - images.count) }

    var canSend: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func add(images newImages: [UIImage]) {
        guard !newImages.isEmpty else { return }
        let available = Self.maxPhotos - images.count
        if available <= 0 {
            toastMessage = NSLocalizedString("feedback.limit.photos", comment: "")
            return
        }
        let toAdd = Array(newImages.prefix(available))
        images.append(contentsOf: toAdd)
        if newImages.count > toAdd.count {
            toastMessage = NSLocalizedString("feedback.limit.photos", comment: "")
        }
    }

    func removePhoto(at index: Int) {
        guard images.indices.contains(index) else { return }
        images.remove(at: index)
    }

    func prepareCompressedAttachments() async -> (datas: [Data], failed: Int, totalBytes: Int) {
        let result = await ImageResizer.compressForEmail(images: images, maxWidth: 2000, jpegQuality: 0.8)
        return result
    }

    func buildSubject() -> String {
        let subjectTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let subjectSuffix = subjectTopic.isEmpty ? "No subject" : subjectTopic
        return "[CycloNotes Feedback] \(subjectSuffix)"
    }

    func buildBody() -> String {
        let appName = Bundle.main.displayName
        let os = UIDevice.current.systemVersion
        let model = UIDevice.current.modelName
        let version = Bundle.main.appVersion
        let build = Bundle.main.appBuild
        let header = "Application Name:\t\t\t\(appName)\niOS:\t\t\t\t\t\t\(os)\nDevice Model:\t\t\t\(model)\nApp Version:\t\t\t\(version)\nApp Build:\t\t\t\t\(build)\n--------------------------------------------------\n"
        let bodyText = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = header + (bodyText.isEmpty ? "" : bodyText) + "\n\n(Attachments: see photos)"
        return combined
    }

    func reset() {
        topic = ""
        details = ""
        images = []
        toastMessage = nil
        isProcessing = false
    }
}

// MARK: - View

struct FeedbackView: View {
    @StateObject private var vm = FeedbackViewModel()
    @State private var isPresentingMail: Bool = false
    @State private var isPresentingShare: Bool = false
    @State private var shareItems: [Any] = []
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    // For PhotosPicker (iOS 16+)
    @State private var pickerItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Topic
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("feedback.topic.label", comment: "")).font(.headline)
                        TextField(NSLocalizedString("feedback.placeholder.topic", comment: ""), text: $vm.topic)
                            .textFieldStyle(.roundedBorder)
                        counterText(current: vm.topicCount, max: FeedbackViewModel.maxTopic)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 6) {
                        Text(NSLocalizedString("feedback.description.label", comment: "")).font(.headline)
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $vm.details)
                                .frame(minHeight: 140)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                            if vm.details.isEmpty {
                                Text(NSLocalizedString("feedback.placeholder.description", comment: ""))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 8)
                            }
                        }
                        counterText(current: vm.detailsCount, max: FeedbackViewModel.maxDetails)
                    }

                    // Photos
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("feedback.addPhotos", comment: "")).font(.headline)
                        photosPickerOrFallback
                        thumbnailsGrid
                    }

                    // Diagnostics note
                    Text(NSLocalizedString("feedback.diagnostics.footer", comment: ""))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    // Send button
                    Button(action: sendTapped) {
                        HStack {
                            if vm.isProcessing { ProgressView().progressViewStyle(.circular) }
                            Text(NSLocalizedString("feedback.createEmail", comment: ""))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.canSend || vm.isProcessing)
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("feedback.title", comment: ""))
            .overlay(alignment: .bottom) { toastOverlay }
        }
        // Mail composer
        .sheet(isPresented: $isPresentingMail) {
            let subject = vm.buildSubject()
            let body = vm.buildBody()
            MailComposeView(subject: subject, body: body, recipients: ["grace.anderson.au@gmail.com"], attachmentsProvider: {
                await vm.prepareCompressedAttachments()
            }) { result in
                switch result {
                case .sent:
                    break
                case .cancelled, .failed:
                    vm.toastMessage = NSLocalizedString("feedback.toast.notSent", comment: "")
                }
                isPresentingMail = false
                // Always reset and navigate to Activity tab regardless of result
                vm.reset()
                selectedTab = 0
            }
        }
        // Share sheet fallback
        .sheet(isPresented: $isPresentingShare) {
            ShareSheetView(items: shareItems) { completed in
                if completed == false {
                    vm.toastMessage = NSLocalizedString("feedback.toast.notSent", comment: "")
                }
                isPresentingShare = false
                // Always reset and navigate to Activity tab regardless of completion
                vm.reset()
                selectedTab = 0
            }
        }
    }

    private func counterText(current: Int, max: Int) -> some View {
        let text = String(format: NSLocalizedString("feedback.limit.text", comment: ""), current, max)
        let color: Color = current >= max ? .red : (Double(current) / Double(max) >= 0.9 ? .orange : .secondary)
        return Text(text).font(.footnote).foregroundStyle(color).frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var photosPickerOrFallback: some View {
        if #available(iOS 16.0, *) {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: FeedbackViewModel.maxPhotos - vm.images.count, matching: .images) {
                Label(NSLocalizedString("feedback.addPhotos", comment: ""), systemImage: "photo.on.rectangle")
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    var uiImages: [UIImage] = []
                    for item in items.prefix(FeedbackViewModel.maxPhotos) {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            uiImages.append(img)
                        }
                    }
                    await MainActor.run {
                        let before = vm.images.count
                        vm.add(images: uiImages)
                        let after = vm.images.count
                        if before == after && !uiImages.isEmpty {
                            vm.toastMessage = NSLocalizedString("feedback.limit.photos", comment: "")
                        }
                        pickerItems = []
                    }
                }
            }
        } else {
            Text(NSLocalizedString("feedback.fallback.photos.ios15", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var thumbnailsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
            ForEach(Array(vm.images.enumerated()), id: \.offset) { idx, img in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 90)
                        .clipped()
                        .cornerRadius(8)
                    Button(action: { vm.removePhoto(at: idx) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(4)
                    }
                    .accessibilityLabel(String(format: NSLocalizedString("feedback.accessibility.removePhoto", comment: ""), idx + 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var toastOverlay: some View {
        Group {
            if let message = vm.toastMessage {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .imageScale(.medium)
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 4)
                    Spacer()
                }
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: message)
            }
        }
    }

    private func sendTapped() {
        Task {
            let payload = Analytics.merged(with: [
                "hasTopic": vm.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "false" : "true",
                "hasDetails": vm.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "false" : "true",
                "imagesCount": String(vm.images.count)
            ])
            TelemetryDeck.signal("feedbackCreateEmailTapped", parameters: payload)

            vm.isProcessing = true
            defer { vm.isProcessing = false }

            let subject = vm.buildSubject()
            let body = vm.buildBody()

            // Prefer Mail app
            if MFMailComposeViewController.canSendMail() {
                // Preflight compression to warn about size/failed attachments
                let attach = await vm.prepareCompressedAttachments()
                if attach.failed > 0 {
                    vm.toastMessage = NSLocalizedString("feedback.error.attach", comment: "")
                }
                if attach.totalBytes > 20 * 1024 * 1024 {
                    vm.toastMessage = NSLocalizedString("feedback.warn.largeAttachments", comment: "")
                }
                isPresentingMail = true
            } else {
                // Fallback share sheet: prepare items first
                let attach = await vm.prepareCompressedAttachments()
                if attach.failed > 0 {
                    vm.toastMessage = NSLocalizedString("feedback.error.attach", comment: "")
                }
                if attach.totalBytes > 20 * 1024 * 1024 {
                    vm.toastMessage = NSLocalizedString("feedback.warn.largeAttachments", comment: "")
                }
                var items: [Any] = [subject + "\n\n" + body]
                items.append(contentsOf: attach.datas)
                await MainActor.run {
                    shareItems = items
                    isPresentingShare = true
                }
            }
        }
    }
}

// MARK: - Mail Composer Wrapper

struct MailComposeView: UIViewControllerRepresentable {
    enum Result { case sent, cancelled, failed }

    let subject: String
    let body: String
    let recipients: [String]
    let attachmentsProvider: () async -> (datas: [Data], failed: Int, totalBytes: Int)
    let onResult: (Result) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        Task {
            let attach = await attachmentsProvider()
            for (idx, data) in attach.datas.enumerated() {
                vc.addAttachmentData(data, mimeType: "image/jpeg", fileName: "photo-\(idx + 1).jpg")
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onResult: (Result) -> Void
        init(onResult: @escaping (Result) -> Void) { self.onResult = onResult }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            switch result {
            case .sent: onResult(.sent)
            case .cancelled: onResult(.cancelled)
            default: onResult(.failed)
            }
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Share Sheet Wrapper

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    FeedbackView()
}

