import SwiftUI
import UniformTypeIdentifiers

/// Import/export in the web app's backup format (Settings → Export backup / Import backup).
struct DataView: View {
    @EnvironmentObject private var store: OverloadStore
    @State private var importing = false
    @State private var exporting = false
    @State private var pending: OverloadBackup?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { importing = true } label: { Label("Import backup", systemImage: "square.and.arrow.down") }
                    Button { exporting = true } label: { Label("Export backup", systemImage: "square.and.arrow.up") }
                } footer: {
                    Text("Uses the same JSON file as Settings → Export backup in the Overload web app, so you can move your history between the browser, this iPhone and your Apple Watch.")
                }
                Section("On this iPhone") {
                    LabeledContent("Workouts", value: "\(store.history.count)")
                    LabeledContent("Saved workouts", value: "\(store.templates.count)")
                    LabeledContent("Unit", value: store.unit.rawValue)
                }
            }
            .navigationTitle("Data")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    pending = try OverloadStore.decodeBackup(Data(contentsOf: url))
                } catch {
                    message = error.localizedDescription
                }
            }
            .fileExporter(isPresented: $exporting, document: BackupDocument(backup: store.exportBackup()),
                          contentType: .json, defaultFilename: "overload-backup-\(Date().formatted(.iso8601.year().month().day()))") { result in
                if case .failure(let e) = result { message = e.localizedDescription }
            }
            .confirmationDialog("Import \(pending?.history.count ?? 0) workouts?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
                Button("Add new workouts") {
                    if let p = pending { message = "Added \(store.merge(p)) workouts." }
                    pending = nil
                }
                Button("Replace everything", role: .destructive) {
                    if let p = pending { store.replaceAll(with: p); message = "Backup imported." }
                    pending = nil
                }
                Button("Cancel", role: .cancel) { pending = nil }
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var backup: OverloadBackup

    init(backup: OverloadBackup) { self.backup = backup }

    init(configuration: ReadConfiguration) throws {
        guard let raw = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        backup = try OverloadStore.decodeBackup(raw)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try e.encode(backup))
    }
}
