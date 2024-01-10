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
                    Button(
                        action: {
                            viewModel.connectToClient()
                        }, label: {
                            Text("Connect to driver")
                        }
                    )
                }
            }
        }
        .frame(width: 500, height: 200, alignment: .center)
        .onAppear {
            viewModel.checkDextState()
        }
    }
}

#Preview {
    MainView()
}
