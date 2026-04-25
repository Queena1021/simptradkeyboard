import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("啟用 SimpTradKeyboard").font(.title2).bold()
                StepView(number: 1, text: "打開 iOS「設定」")
                StepView(number: 2, text: "揀「一般」→「鍵盤」→「鍵盤」")
                StepView(number: 3, text: "㩒「加入新鍵盤」")
                StepView(number: 4, text: "揀 SimpTradKeyboard")
                Text("打字嗰陣長㩒🌐切到新鍵盤。")
                    .foregroundStyle(.secondary)
                Button("打開系統設定") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("啟用鍵盤")
    }
}

private struct StepView: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.headline).frame(width: 28, height: 28)
                .background(Circle().fill(.tint.opacity(0.2)))
            Text(text)
        }
    }
}
