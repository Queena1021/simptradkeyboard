import SwiftUI
import KeyboardCore

struct LearningDataView: View {
    @State private var entries: [LearningStore.Entry] = []
    @State private var store: LearningStore?

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    store?.reset()
                    reload()
                } label: {
                    Text("重設學習資料")
                }
            }
            Section("已學詞彙") {
                if entries.isEmpty {
                    Text("（未有資料）").foregroundStyle(.secondary)
                } else {
                    ForEach(entries, id: \.code) { e in
                        HStack {
                            Text(e.candidate).font(.title3)
                            Spacer()
                            Text(e.code).font(.caption).foregroundStyle(.secondary)
                            Text("×\(e.count)").monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("學習資料")
        .onAppear {
            if store == nil, let url = AppGroup.learningDBURL() {
                store = try? LearningStore(path: url.path)
            }
            reload()
        }
    }

    private func reload() {
        entries = store?.allEntries() ?? []
    }
}
