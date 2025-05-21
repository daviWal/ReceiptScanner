//
//  ContentView.swift
//  BillScanner
//
//  Created by David Walitza on 21.05.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink(destination: SavedReceiptsView()) {
                    HStack {
                        Image(systemName: "doc.richtext")
                        Text("Saved Bills")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                }

                NavigationLink(destination: CameraScannerView()) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Scan New Receipt")
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Bill Scanner")
        }
    }
}

#Preview {
    ContentView()
}
