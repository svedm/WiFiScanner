//
//  ContentView.swift
//  WiFiScanner
//
//  Created by Svetoslav on 10.01.2024.
//

import SwiftUI

struct MainView: View {

    @ObservedObject var viewModel = MainViewModel()

    var body: some View {
        VStack(alignment: .center) {
            Text("WiFiScanner")
                .padding()
                .font(.title)
            HStack(spacing: 12) {
                Button(
                    action: {
                        viewModel.activateMyDext()
                    }, label: {
                        Text("Install Dext")
                    }
                )
                Button(
                    action: { viewModel.checkService() },
                    label: { Text("Refresh") }
                )

                if viewModel.serviceAvailable {
                    Button(
                        action: {
                            if viewModel.isConnected {
                                viewModel.disconnect()
                            } else {
                                viewModel.connectToClient()
                            }
                        }, label: {
                            Text(viewModel.isConnected ? "Disconnect" : "Connect to driver")
                        }
                    )
                    if viewModel.isConnected {
                        Button(
                            action: {
                                Task { await viewModel.communicate() }
                            }, label: {
                                Text("Scan networks")
                            }
                        )
                        .disabled(viewModel.isScanning)
                    }
                }
            }
            List(viewModel.networks) { network in
                NetworkListItem(network: network)
            }
        }
        .onAppear {
            viewModel.checkService()
        }
    }
}

#Preview {
    MainView()
}
