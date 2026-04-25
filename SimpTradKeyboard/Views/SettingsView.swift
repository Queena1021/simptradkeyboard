import SwiftUI
import KeyboardCore

struct SettingsView: View {
    @State private var outputMode: OutputMode = .traditional
    @State private var imeMode: IMEMode = .quick
    private let settings = Settings.shared()

    var body: some View {
        Form {
            Section("輸出") {
                Picker("語言", selection: $outputMode) {
                    Text("繁體").tag(OutputMode.traditional)
                    Text("简体").tag(OutputMode.simplified)
                }
                .pickerStyle(.segmented)
                .onChange(of: outputMode) { newValue in
                    settings.outputMode = newValue
                }
            }
            Section("輸入法") {
                Picker("輸入方式", selection: $imeMode) {
                    Text("速成").tag(IMEMode.quick)
                    Text("倉頡").tag(IMEMode.cangjie)
                }
                .pickerStyle(.segmented)
                .onChange(of: imeMode) { newValue in
                    settings.imeMode = newValue
                }
            }
            Section {
                NavigationLink("啟用鍵盤教學") { OnboardingView() }
                NavigationLink("學習資料") { LearningDataView() }
            }
        }
        .navigationTitle("SimpTradKeyboard")
        .onAppear {
            outputMode = settings.outputMode
            imeMode = settings.imeMode
        }
    }
}

#Preview { NavigationStack { SettingsView() } }
