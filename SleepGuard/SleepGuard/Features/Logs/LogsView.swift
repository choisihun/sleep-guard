import SwiftUI
import UniformTypeIdentifiers

struct LogsView: View {
    @StateObject var viewModel: LogsViewModel
    @ObservedObject private var controller: SleepGuardController
    @State private var selectedCategories = Set(PMSetEventCategory.allCases)
    @State private var isImportingJSON = false

    init(viewModel: LogsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _controller = ObservedObject(wrappedValue: viewModel.controller)
    }

    private var filteredEvents: [PMSetEvent] {
        controller.parsedEvents.filter { selectedCategories.contains($0.category) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Logs")
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                Button {
                    Task { await viewModel.loadLogs() }
                } label: {
                    Label("최근 raw pmset log", systemImage: "arrow.clockwise")
                }
                Button {
                    isImportingJSON = true
                } label: {
                    Label("JSON 로그 열기", systemImage: "folder")
                }
                Button {
                    viewModel.copyRawLog()
                } label: {
                    Label("로그 복사", systemImage: "doc.on.doc")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(PMSetEventCategory.allCases) { category in
                        Toggle(category.displayName, isOn: categoryBinding(category))
                            .toggleStyle(.button)
                    }
                }
            }

            HSplitView {
                List(filteredEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.category.displayName)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(event.timestamp == .distantPast ? "" : event.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.message)
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(3)
                    }
                    .padding(.vertical, 3)
                }
                .frame(minWidth: 360)

                ScrollView {
                    Text(controller.rawLogText.isEmpty ? "pmset 로그를 불러오세요." : controller.rawLogText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .padding(24)
        .navigationTitle("Logs")
        .fileImporter(isPresented: $isImportingJSON, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            Task { await viewModel.loadJSONLog(at: url) }
        }
    }

    private func categoryBinding(_ category: PMSetEventCategory) -> Binding<Bool> {
        Binding {
            selectedCategories.contains(category)
        } set: { isOn in
            if isOn {
                selectedCategories.insert(category)
            } else {
                selectedCategories.remove(category)
            }
        }
    }
}
