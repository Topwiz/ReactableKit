//
//  SafeAsyncView.swift
//  ExmapleApp
//
//  Created by ReactableKit on 3/21/25.
//

import SwiftUI
import ReactableKit

struct SafeAsyncView: View {
    @StateObject private var store = Store(SafeAsyncReactable())
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Safe Async & Send Order Test")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                // 로딩 상태
                if store.state.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("실행 중...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // 기존 Safe Async 테스트
                VStack(alignment: .leading, spacing: 12) {
                    Text("📡 Safe Async 테스트")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !store.state.userData.isEmpty {
                        Text("Data: \(store.state.userData)")
                            .foregroundColor(.green)
                            .padding(.horizontal)
                    }
                    
                    if let errorMessage = store.state.errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        Button("Load User Data (Success)") {
                            store.action(.loadUserData)
                        }
                        .buttonStyle(TestButtonStyle(color: .blue))
                        .disabled(store.state.isLoading)
                        
                        Button("Load User Data (Error)") {
                            store.action(.loadUserDataWithError)
                        }
                        .buttonStyle(TestButtonStyle(color: .red))
                        .disabled(store.state.isLoading)
                        
                        Button("Cancel") {
                            store.action(.cancel)
                        }
                        .buttonStyle(TestButtonStyle(color: .gray))
                        .disabled(!store.state.isLoading)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                // Send 순서 테스트
                VStack(alignment: .leading, spacing: 12) {
                    Text("🧪 Send 순서 테스트")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        Button("🚀 순차 Send 테스트") {
                            store.action(.testSequentialSends)
                        }
                        .buttonStyle(TestButtonStyle(color: .blue))
                        
                        Button("⚡ 빠른 연속 Send 테스트") {
                            store.action(.testFastSends)
                        }
                        .buttonStyle(TestButtonStyle(color: .green))
                        
                        Button("⏰ 비동기 Send 테스트") {
                            store.action(.testAsyncSends)
                        }
                        .buttonStyle(TestButtonStyle(color: .orange))
                        
                        Button("🔄 혼합 Send 테스트") {
                            store.action(.testMixedSends)
                        }
                        .buttonStyle(TestButtonStyle(color: .purple))
                        
                        Button("🗑️ 로그 초기화") {
                            store.action(.resetLogs)
                        }
                        .buttonStyle(TestButtonStyle(color: .red))
                    }
                    .disabled(store.state.isLoading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                // 외부 반복 액션 테스트
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔥 외부 반복 액션 테스트")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("외부에서 반복문으로 액션을 연속 호출했을 때 순서가 보장되는지 테스트합니다.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        Button("🎯 외부 반복 액션 테스트 (10회)") {
                            // 먼저 테스트 시작 액션 호출
                            store.action(.startExternalActionTest)
                            
                            // 0.1초 후에 반복 액션들을 연속으로 호출
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                for i in 1...10 {
                                    store.action(.externalActionTest(i))
                                }
                            }
                        }
                        .buttonStyle(TestButtonStyle(color: .mint))
                        
                        Button("🎯 외부 반복 액션 테스트 (빠른 20회)") {
                            // 먼저 테스트 시작 액션 호출
                            store.action(.startExternalActionTest)
                            
                            // 0.1초 후에 반복 액션들을 매우 빠르게 연속으로 호출
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                for i in 1...20 {
                                    // 각 액션을 즉시 호출 (동시성 테스트)
                                    store.action(.externalActionTest(i))
                                }
                            }
                        }
                        .buttonStyle(TestButtonStyle(color: .cyan))
                        
                        Button("🎯 외부 지연 반복 액션 테스트 (5회)") {
                            // 먼저 테스트 시작 액션 호출
                            store.action(.startExternalActionTest)
                            
                            // 각 액션을 0.05초 간격으로 호출
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                for i in 1...5 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                                        store.action(.externalActionTest(i))
                                    }
                                }
                            }
                        }
                        .buttonStyle(TestButtonStyle(color: .indigo))
                    }
                    .disabled(store.state.isLoading)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                // 로그 뷰
                if !store.state.logs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("📋 실행 로그")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("총 \(store.state.logs.count)개")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(store.state.logs.enumerated()), id: \.offset) { index, log in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .frame(width: 30, alignment: .trailing)
                                        
                                        Text(log)
                                            .font(.system(.caption, design: .monospaced))
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color(.systemBackground))
                                    )
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .frame(maxHeight: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                // 설명
                VStack(alignment: .leading, spacing: 8) {
                    Text("ℹ️ 테스트 설명")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 순차 테스트: 5개의 연속 send() 호출")
                        Text("• 빠른 연속: 20개의 빠른 send() 호출")
                        Text("• 비동기: Task.sleep() 중간에 send() 호출")
                        Text("• 혼합: 연속 + 비동기 + 연속 패턴")
                        Text("• 외부 반복: 외부에서 반복문으로 액션 호출")
                        Text("• 모든 send()와 액션은 순서대로 실행되어야 함")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .padding()
        }
        .navigationTitle("Safe Async & Send Order")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Custom Button Style

struct TestButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    NavigationView {
        SafeAsyncView()
    }
}
