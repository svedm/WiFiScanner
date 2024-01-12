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
            Text("WiFiScanner Manager")
                .padding()
                .font(.title)
            Text(viewModel.dextLoadingState)
                .multilineTextAlignment(.center)
            HStack {
                if viewModel.state == .unloaded {
                    Button(
                        action: {
                            viewModel.activateMyDext()
                        }, label: {
                            Text("Install Dext")
                        }
                    )
                }
                if viewModel.state == .activated {
                    Button(
                        action: {
                            viewModel.deactivateExtension()
                        }, label: {
                            Text("Uninstall Dext")
                        }
                    )
                    if !viewModel.connected {
                        Button(
                            action: {
                                viewModel.connectToClient()
                            }, label: {
                                Text("Connect to driver")
                            }
                        )
                    } else {
                        Button(
                            action: {
                                Task { await viewModel.communicate() }
                            }, label: {
                                Text("Scan networks")
                            }
                        )
                        .disabled(viewModel.isScanning)
                        Button(
                            action: {
                                viewModel.disconnect()
                            }, label: {
                                Text("Disconnect")
                            }
                        )
                    }
                }
            }
            List(viewModel.networks) { network in
                NetworkListItem(network: network)
            }
        }
        .onAppear {
            viewModel.checkDextState()
        }
    }
}

#Preview {
    MainView()
}
