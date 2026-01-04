//
//  PotteryClientApp.swift
//  PotteryClient
//
//  Created by TT on 12/30/25.
//

import SwiftUI
import Stripe

@main
struct PotteryClientApp: App {
    init() {
        StripeAPI.defaultPublishableKey = "pk_test_51Sll9OFbw2iFq4DqvxdUAA6KGPngGBscLFanXV2T4DQoG6dbqUfBhuNN0zhI5oPk19G6cI2HxlJkpSc6nTuA6Cz800Uh7DYo03"
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
