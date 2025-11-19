//
//  OAuth2LoginView.swift
//  Companion
//
//  Created for TRMNL OAuth2 authentication.
//

import SwiftUI
import SafariServices

struct OAuth2LoginView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let authURL: URL
    let onCompletion: () -> Void
    let onCancellation: (() -> Void)?
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: authURL)
        safariViewController.delegate = context.coordinator
        safariViewController.preferredBarTintColor = UIColor.systemBackground
        safariViewController.preferredControlTintColor = UIColor.systemBlue
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: OAuth2LoginView
        
        init(_ parent: OAuth2LoginView) {
            self.parent = parent
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            parent.isPresented = false
            parent.onCancellation?()
            parent.onCompletion()
        }

        func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
            if !didLoadSuccessfully {
                parent.isPresented = false
                parent.onCancellation?()
                parent.onCompletion()
            }
        }
    }
}