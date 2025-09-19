//
//  CancellableAsyncExample.swift
//  SampleProject
//
//  Created by Jeehoon Son on 1/24/25.
//

import SwiftUI
import ReactableKit


@MainActor
final class CancellableReactable: Reactable, PathState {
    
    enum Action: Hashable, Sendable {
        case startDownload(id: String)
        case startProcessing
        case startAnalysis
        case startMultiStepTask
        case cancelDownload(id: String)
        case cancelProcessing
        case cancelAnalysis
        case cancelMultiStep
        case cancelAll
        case reset
    }
    
    struct State: Sendable {
        @ViewState var downloadProgress: [String: Int] = [:]
        @ViewState var processingProgress: Int = 0
        @ViewState var analysisProgress: Int = 0
        @ViewState var status: String = "Ready"
        @ViewState var isProcessing: Bool = false
        @ViewState var isAnalyzing: Bool = false
        @ViewState var steps: [String] = []
        @ViewState var isMultiStepRunning: Bool = false
    }
    
    enum Mutation: Sendable {
        case updateDownloadProgress(String, Int)
        case removeDownload(String)
        case updateProcessingProgress(Int)
        case updateAnalysisProgress(Int)
        case setStatus(String)
        case setProcessing(Bool)
        case setAnalyzing(Bool)
        case addStep(String)
        case clearSteps
        case setMultiStepRunning(Bool)
        case reset
    }
    
    let initialState = State()
    
    func mutate(action: Action, state: State, send: @escaping MutationSender<Mutation>) async {
        switch action {
        case let .startDownload(id):
            // Cancel existing download with same ID
            if state.downloadProgress[id] != nil {
                self.cancel(.startDownload(id: id))
                await send(.removeDownload(id))
            }
            
            await send(.setStatus("Starting download: \(id)"))
            await send(.updateDownloadProgress(id, 0))
            
            await withCancellation(for: action, send: send) { isCancelled, send in
                for i in 1...10 {
                    if isCancelled() {
                        await send(.setStatus("Download \(id) cancelled"))
                        await send(.removeDownload(id))
                        return
                    }
                    
                    await send(.updateDownloadProgress(id, i * 10))
                    await send(.setStatus("Downloading \(id): \(i * 10)%"))
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
                
                await send(.removeDownload(id))
                await send(.setStatus("Download \(id) completed!"))
            }
            
        case .startProcessing:
            self.cancel(.startProcessing)
            
            await send(.setProcessing(true))
            await send(.updateProcessingProgress(0))
            await send(.setStatus("Processing started..."))
            
            await withCancellation(for: action, send: send) { isCancelled, send in
                for i in 1...20 {
                    if isCancelled() {
                        await send(.setStatus("Processing cancelled"))
                        await send(.setProcessing(false))
                        await send(.updateProcessingProgress(0))
                        return
                    }
                    
                    await send(.updateProcessingProgress(i * 5))
                    await send(.setStatus("Processing: \(i * 5)%"))
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                
                await send(.setProcessing(false))
                await send(.setStatus("Processing completed!"))
            }
            
        case .startAnalysis:
            self.cancel(.startAnalysis)
            
            await send(.setAnalyzing(true))
            await send(.updateAnalysisProgress(0))
            await send(.setStatus("Analysis started..."))
            
            await withCancellation(for: action, send: send) { isCancelled, send in
                for i in 1...15 {
                    if isCancelled() {
                        await send(.setAnalyzing(false))
                        await send(.updateAnalysisProgress(0))
                        await send(.setStatus("Analysis cancelled"))
                        return
                    }
                    
                    let progress = min(100, i * 7)
                    await send(.updateAnalysisProgress(progress))
                    await send(.setStatus("Analyzing: \(progress)%"))
                    try? await Task.sleep(nanoseconds: 400_000_000)
                }
                
                await send(.setAnalyzing(false))
                await send(.setStatus("Analysis completed!"))
            }
            
        case .startMultiStepTask:
            self.cancel(.startMultiStepTask)
            
            await send(.setMultiStepRunning(true))
            await send(.clearSteps)
            await send(.setStatus("Starting multi-step task..."))
            
            await withCancellation(for: action, send: send) { isCancelled, send in
                let steps = [
                    "📝 Preparing data...",
                    "🔄 Processing...",
                    "📊 Analyzing results...",
                    "💾 Saving data...",
                    "✅ Finalizing..."
                ]
                
                for (index, step) in steps.enumerated() {
                    if isCancelled() {
                        await send(.addStep("❌ Cancelled at step \(index + 1)"))
                        await send(.setStatus("Multi-step task cancelled"))
                        await send(.setMultiStepRunning(false))
                        return
                    }
                    
                    await send(.addStep(step))
                    await send(.setStatus("Step \(index + 1) of \(steps.count): \(step)"))
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                await send(.addStep("🎉 All steps completed!"))
                await send(.setStatus("Multi-step task completed successfully!"))
                await send(.setMultiStepRunning(false))
            }
            
        case let .cancelDownload(id):
            let count = self.cancel(.startDownload(id: id))
            if count > 0 {
                await send(.setStatus("Download \(id) cancelled"))
            }
            
        case .cancelProcessing:
            let count = self.cancel(.startProcessing)
            if count > 0 {
                await send(.setStatus("Processing cancelled"))
            }
            
        case .cancelAnalysis:
            let count = self.cancel(.startAnalysis)
            if count > 0 {
                await send(.setStatus("Analysis cancelled"))
            }
            
        case .cancelMultiStep:
            let count = self.cancel(.startMultiStepTask)
            if count > 0 {
                await send(.setStatus("Multi-step task cancelled"))
            }
            
        case .cancelAll:
            let count = self.cancelAll()
            await send(.setStatus("Cancelled all \(count) tasks"))
            
        case .reset:
            self.cancelAll()
            
        }
    }
    
    func reduce(state: inout State, mutation: Mutation) {
        switch mutation {
        case let .updateDownloadProgress(id, progress):
            state.downloadProgress[id] = progress
        case let .removeDownload(id):
            state.downloadProgress[id] = nil
        case let .updateProcessingProgress(progress):
            state.processingProgress = progress
        case let .updateAnalysisProgress(progress):
            state.analysisProgress = progress
        case let .setStatus(status):
            state.status = status
        case let .setProcessing(value):
            state.isProcessing = value
        case let .setAnalyzing(value):
            state.isAnalyzing = value
        case let .addStep(step):
            state.steps.append(step)
        case .clearSteps:
            state.steps = []
        case let .setMultiStepRunning(value):
            state.isMultiStepRunning = value
        case .reset:
            state.downloadProgress = [:]
            state.processingProgress = 0
            state.analysisProgress = 0
            state.status = "Ready"
            state.isProcessing = false
            state.isAnalyzing = false
            state.steps = []
            state.isMultiStepRunning = false
        }
    }
}


struct CancellableAsyncView: View {
    @StateObject private var store = Store(CancellableReactable())
    @State private var downloadIdCounter = 1
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("withCancellation Pattern")
                        .font(.title3)
                        .bold()
                    
                    Text("Cancel tasks with self.cancel(action)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(store.state.status)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Downloads Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Downloads")
                            .font(.headline)
                        Spacer()
                        Button("Add Download") {
                            let id = "File-\(downloadIdCounter)"
                            downloadIdCounter += 1
                            Task {
                                await store.action(.startDownload(id: id))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    
                    if !store.state.downloadProgress.isEmpty {
                        ForEach(store.state.downloadProgress.sorted(by: { $0.key < $1.key }), id: \.key) { id, progress in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(id)
                                        .font(.system(.body, design: .monospaced))
                                    Spacer()
                                    Button("Cancel") {
                                        Task {
                                            await store.action(.cancelDownload(id: id))
                                        }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .tint(.red)
                                }
                                ProgressView(value: Double(progress), total: 100)
                                    .progressViewStyle(.linear)
                                Text("\(progress)%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Processing Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Processing")
                            .font(.headline)
                        Spacer()
                        Button(store.state.isProcessing ? "Cancel" : "Start") {
                            Task {
                                if store.state.isProcessing {
                                    await store.action(.cancelProcessing)
                                } else {
                                    await store.action(.startProcessing)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(store.state.isProcessing ? .red : .blue)
                    }
                    
                    if store.state.processingProgress > 0 {
                        ProgressView(value: Double(store.state.processingProgress), total: 100)
                            .progressViewStyle(.linear)
                        Text("\(store.state.processingProgress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // Analysis Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Analysis")
                            .font(.headline)
                        Spacer()
                        Button(store.state.isAnalyzing ? "Cancel" : "Start") {
                            Task {
                                if store.state.isAnalyzing {
                                    await store.action(.cancelAnalysis)
                                } else {
                                    await store.action(.startAnalysis)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(store.state.isAnalyzing ? .red : .purple)
                    }
                    
                    if store.state.analysisProgress > 0 {
                        ProgressView(value: Double(store.state.analysisProgress), total: 100)
                            .progressViewStyle(.linear)
                        Text("\(store.state.analysisProgress)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(10)
                
                // Multi-Step Task Section
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Multi-Step Task")
                            .font(.headline)
                        Spacer()
                        Button(store.state.isMultiStepRunning ? "Cancel" : "Start") {
                            Task {
                                if store.state.isMultiStepRunning {
                                    await store.action(.cancelMultiStep)
                                } else {
                                    await store.action(.startMultiStepTask)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(store.state.isMultiStepRunning ? .red : .green)
                    }
                    
                    if !store.state.steps.isEmpty {
                        ForEach(store.state.steps, id: \.self) { step in
                            Text(step)
                                .font(.system(.body, design: .rounded))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .background(Color.green.opacity(0.05))
                .cornerRadius(10)
                
                // Control Buttons
                HStack(spacing: 15) {
                    Button("Cancel All Tasks") {
                        Task {
                            await store.action(.cancelAll)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button("Reset") {
                        Task {
                            await store.action(.reset)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
            .padding(.vertical)
        }
        .navigationTitle("Cancellation")
        .navigationBarTitleDisplayMode(.inline)
    }
}


#Preview {
    NavigationView {
        CancellableAsyncView()
    }
}
