//
//  ContentView.swift
//  XCAChatGPT
//
//  Created by Alfian Losari on 01/02/23.
//

import SwiftUI
import AVKit
import PDFKit

struct ContentView: View {
        
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var vm: ViewModel
    @FocusState var isTextFieldFocused: Bool
    
    // PDF Drawer State
    @State private var showPDFDrawer: Bool = true  // Show by default for testing
    @State private var currentPDFDocument: PDFDocument? = nil
    @State private var drawerExpanded: Bool = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            chatListView
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tap background to minimize drawer when expanded
                    #if os(iOS)
                    if showPDFDrawer {
                        minimizeDrawer()
                    }
                    #endif
                }
            
            #if os(iOS)
            if showPDFDrawer {
                RightSideDrawerView(isExpanded: $drawerExpanded) {
                    PDFDrawerContainer(pdfDocument: currentPDFDocument)
                }
            }
            #endif
        }
        .navigationTitle(vm.navigationTitle)
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Load Sample PDF Button
                Button {
                    loadSamplePDF()
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                
                // Toggle Drawer Button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showPDFDrawer.toggle()
                    }
                } label: {
                    Image(systemName: showPDFDrawer ? "doc.text.fill" : "doc.text")
                }
            }
        }
        #endif
    }
    
    var chatListView: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.messages) { message in
                            MessageRowView(message: message) { message in
                                Task { @MainActor in
                                    await vm.retry(message: message)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        isTextFieldFocused = false
                    }
                }
                #if os(iOS) || os(macOS)
                Divider()
                bottomView(image: "profile", proxy: proxy)
                Spacer()
                #endif
            }
            .onChange(of: vm.messages.last?.responseText) { _ in  scrollToBottom(proxy: proxy)
            }
        }
        .background(colorScheme == .light ? .white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
    }
    
    func bottomView(image: String, proxy: ScrollViewProxy) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if image.hasPrefix("http"), let url = URL(string: image) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .frame(width: 30, height: 30)
                } placeholder: {
                    ProgressView()
                }

            } else {
                Image(image)
                    .resizable()
                    .frame(width: 30, height: 30)
            }
            
            TextField("Send message", text: $vm.inputMessage, axis: .vertical)
                .autocorrectionDisabled()
                #if os(iOS) || os(macOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .focused($isTextFieldFocused)
                .disabled(vm.isInteracting)
            
            if vm.isInteracting {
                #if os(iOS)
                Button {
                    vm.cancelStreamingResponse()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.multicolor)
                        .foregroundColor(.red)
                }
                #else
                DotLoadingView().frame(width: 60, height: 30)
                #endif
            } else {
                Button {
                    Task { @MainActor in
                        isTextFieldFocused = false
                        scrollToBottom(proxy: proxy)
                        await vm.sendTapped()
                    }
                } label: {
                    Image(systemName: "paperplane.circle.fill")
                        .rotationEffect(.degrees(45))
                        .font(.system(size: 30))
                }
                #if os(macOS)
                .buttonStyle(.borderless)
                .keyboardShortcut(.defaultAction)
                .foregroundColor(.accentColor)
                #endif
                .disabled(vm.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let id = vm.messages.last?.id else { return }
        proxy.scrollTo(id, anchor: .bottomTrailing)
    }
    
    // MARK: - PDF Helper Methods
    
    /// Load PDF from URL
    func loadPDF(from url: URL) {
        currentPDFDocument = PDFDocument(url: url)
        if currentPDFDocument != nil {
            showPDFDrawer = true
        }
    }
    
    /// Load PDF from Data
    func loadPDF(from data: Data) {
        currentPDFDocument = PDFDocument(data: data)
        if currentPDFDocument != nil {
            showPDFDrawer = true
        }
    }
    
    /// Load sample PDF for testing
    func loadSamplePDF() {
        // Load the Sample-Fillable-PDF.pdf from bundle
        if let url = Bundle.main.url(forResource: "Sample-Fillable-PDF", withExtension: "pdf") {
            loadPDF(from: url)
        } else {
            print("Sample-Fillable-PDF.pdf not found in bundle")
        }
    }
    
    /// Close PDF drawer
    func closePDFDrawer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showPDFDrawer = false
        }
    }
    
    /// Minimize drawer (contract to handle only)
    func minimizeDrawer() {
        if drawerExpanded {
            drawerExpanded = false
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContentView(vm: ViewModel(api: ChatGPTAPI(apiKey: "PROVIDE_API_KEY")))
        }
    }
}

