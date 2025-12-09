//
//  PDFDrawerComponents.swift
//  XCAChatGPT
//
//  Created by Kiro on 09/12/25.
//  Consolidated PDF Drawer Components
//

import SwiftUI
import PDFKit

// MARK: - RightSideDrawerView

struct RightSideDrawerView<Content: View>: View {
    
    @State private var currentOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @Binding var isExpanded: Bool
    
    let content: Content
    let handleWidth: CGFloat = 30  // Width of just the handle
    
    init(isExpanded: Binding<Bool> = .constant(false), @ViewBuilder content: () -> Content) {
        self._isExpanded = isExpanded
        self.content = content()
        _currentOffset = State(initialValue: 0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let drawerWidth = screenWidth - 40  // Almost full width, leaving small margin
            
            // Two snap points:
            // 1. Full width (expanded) - offset = 0
            // 2. Handle only (minimized) - offset = drawerWidth - handleWidth
            let minimizedOffset = drawerWidth - handleWidth
            
            HStack(spacing: 0) {
                handleView
                    .frame(width: handleWidth)
                    .zIndex(1)
                
                content
                    .frame(width: drawerWidth - handleWidth)
            }
            .frame(width: drawerWidth, height: geometry.size.height)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .bottomLeft])
            .shadow(color: Color.black.opacity(0.2), radius: 15, x: -5, y: 0)
            .offset(x: screenWidth - drawerWidth + currentOffset + dragOffset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragOffset) { value, state, _ in
                        // Smooth drag following finger
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        
                        // CRITICAL: Update currentOffset FIRST to prevent jump
                        // This ensures when dragOffset resets to 0, we're at the right position
                        let finalPosition = currentOffset + translation
                        currentOffset = finalPosition
                        
                        // Now determine target snap point
                        let targetOffset = snapToNearestPoint(
                            currentOffset: finalPosition,
                            velocity: velocity,
                            minimizedOffset: minimizedOffset
                        )
                        
                        // Animate from current position to snap point
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            currentOffset = targetOffset
                        }
                    }
            )
            .onAppear {
                // Start minimized (handle only visible)
                if currentOffset == 0 {
                    currentOffset = minimizedOffset
                }
            }
            .onChange(of: isExpanded) { newValue in
                // Sync with external binding
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    currentOffset = newValue ? 0 : minimizedOffset
                }
            }
            .onChange(of: currentOffset) { newValue in
                // Update binding when drawer position changes
                let midPoint = minimizedOffset / 2
                let expanded = newValue < midPoint
                if isExpanded != expanded {
                    isExpanded = expanded
                }
            }
        }
    }
    
    private var handleView: some View {
        GeometryReader { geo in
            let screenWidth = geo.size.width
            let drawerWidth = screenWidth - 40
            let minimizedOffset = drawerWidth - handleWidth
            
            VStack(spacing: 8) {
                Spacer()
                
                // Visual indicator
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 4, height: 20)
                    
                    Image(systemName: currentOffset > minimizedOffset / 2 ? "chevron.left" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 4, height: 20)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(Color(UIColor.systemBackground).opacity(0.95))
            .onTapGesture {
                toggleDrawer(minimizedOffset: minimizedOffset)
            }
        }
    }
    
    private func toggleDrawer(minimizedOffset: CGFloat) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            // Toggle using binding state for consistency
            isExpanded.toggle()
        }
    }
    
    func isExpanded(minimizedOffset: CGFloat) -> Bool {
        let midPoint = minimizedOffset / 2
        return currentOffset < midPoint
    }
    
    private func snapToNearestPoint(
        currentOffset: CGFloat,
        velocity: CGFloat,
        minimizedOffset: CGFloat
    ) -> CGFloat {
        // Two snap points: 0 (full width) and minimizedOffset (handle only)
        let fullWidthPoint: CGFloat = 0
        let minimizedPoint: CGFloat = minimizedOffset
        
        let midPoint = minimizedOffset / 2
        
        // Strong velocity determines direction
        if abs(velocity) > 50 {
            if velocity < 0 {
                // Swiping left (expanding) - go to full width
                return fullWidthPoint
            } else {
                // Swiping right (minimizing) - go to handle only
                return minimizedPoint
            }
        }
        
        // Snap based on position relative to midpoint
        if currentOffset < midPoint {
            return fullWidthPoint
        } else {
            return minimizedPoint
        }
    }
}

// MARK: - PDFViewWrapper

struct PDFViewWrapper: UIViewRepresentable {
    
    let pdfDocument: PDFDocument?
    @Binding var currentPage: Int
    
    init(pdfDocument: PDFDocument?, currentPage: Binding<Int> = .constant(0)) {
        self.pdfDocument = pdfDocument
        self._currentPage = currentPage
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = UIColor.systemGray6
        pdfView.isUserInteractionEnabled = true
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
        pdfView.document = pdfDocument
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== pdfDocument {
            pdfView.document = pdfDocument
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: PDFViewWrapper
        
        init(_ parent: PDFViewWrapper) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }
            let pageIndex = document.index(for: currentPage)
            parent.currentPage = pageIndex
        }
    }
    
    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }
}

// MARK: - PDFDrawerContainer

struct PDFDrawerContainer: View {
    
    let pdfDocument: PDFDocument?
    @State private var currentPage: Int = 0
    @State private var showPageInfo: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            if let pdfDocument = pdfDocument {
                PDFViewWrapper(pdfDocument: pdfDocument, currentPage: $currentPage)
                    .edgesIgnoringSafeArea(.all)
                
                if showPageInfo && pdfDocument.pageCount > 0 {
                    pageInfoView(pageCount: pdfDocument.pageCount)
                        .transition(.opacity)
                }
            } else {
                placeholderView
            }
        }
        .onChange(of: currentPage) { _ in
            withAnimation {
                showPageInfo = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showPageInfo = false
                }
            }
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No PDF Loaded")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Load a PDF document to view it here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGray6))
    }
    
    private func pageInfoView(pageCount: Int) -> some View {
        HStack {
            Spacer()
            Text("Page \(currentPage + 1) of \(pageCount)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(8)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
