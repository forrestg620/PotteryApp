//
//  ContentView.swift
//  PotteryClient
//
//  Created by TT on 12/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @Namespace private var animationNamespace

    var body: some View {
        Group {
            if networkManager.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: networkManager.isAuthenticated)
    }
}

// If MainTabView isn't defined, use FeedView as a fallback:
struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "house")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}

