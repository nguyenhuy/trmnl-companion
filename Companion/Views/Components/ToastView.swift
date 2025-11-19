//
//  ToastView.swift
//  Companion
//
//  Created by Assistant on 2025.
//

import SwiftUI

struct ToastView: View {
    let message: String
    let isSuccess: Bool
    @Binding var isShowing: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(isSuccess ? .green : .red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSuccess ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        ))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowing = false
            }
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeInOut(duration: 0.3)) {
                    isShowing = false
                }
            }
        }
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let isSuccess: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                if isShowing {
                    ToastView(
                        message: message,
                        isSuccess: isSuccess,
                        isShowing: $isShowing
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isShowing)
                }
                
                Spacer()
            }
            .padding(.top, 50)
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, isSuccess: Bool = true) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, isSuccess: isSuccess))
    }
}