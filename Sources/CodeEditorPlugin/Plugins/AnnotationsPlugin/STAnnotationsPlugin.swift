#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif
import SwiftUI

// Module imports removed - functionality consolidated into CodeEditorPlugin

// // MARK: - This plugin system is being removed - kept for reference during refactor
//
// public class STAnnotationsPlugin: STPlugin {
//
//    /// Data Source
//    private weak var dataSource: STAnnotationsDataSource?
//    private var reloadDataHandler: (() -> Void)?
//
//    // Annotations surface view. Add annotations to this view.
//    private var annotationsContentView: STAnnotationsContentView!
//
//    public init(dataSource: STAnnotationsDataSource) {
//        self.dataSource = dataSource
//    }
//
//    public func setUp(context: any Context) {
//        self.annotationsContentView = STAnnotationsContentView(frame: context.textView.frame)
//        annotationsContentView.translatesAutoresizingMaskIntoConstraints = false
//        context.textView.addSubview(annotationsContentView)
//
//        NSLayoutConstraint.activate([
//            annotationsContentView.topAnchor.constraint(equalTo: context.textView.topAnchor),
//            annotationsContentView.widthAnchor.constraint(equalTo: context.textView.widthAnchor),
//            annotationsContentView.heightAnchor.constraint(equalTo: context.textView.heightAnchor)
//        ])
//
//        context.events.onDidChangeText { [weak self] affectedRange, replacementString in
//            self?.didChangeText(context: context, in: affectedRange, replacementString: replacementString)
//        }
//
//        context.events.onDidLayoutViewport { [weak self] range in
//            guard let self else { return }
//            didLayoutViewport(context: context, range)
//        }
//
//        reloadDataHandler = {
//            context.coordinator.layoutAnnotationViewsIfNeeded()
//        }
//    }
//
//    private func didChangeText(context: any Context, in affectedRange: NSTextRange, replacementString: String?) {
//
//        guard let replacementString else {
//            return
//        }
//
//        // Adjust annotation location based on the edit
//        // The annotation location have to update its absolut position
//        // to accomodate insert/delete change in the document, to visually
//        // stay in the same place
//        let affectedCount = context.textView.textContentManager.offset(from: affectedRange.location, to: affectedRange.endLocation)
//        let replacementCount = replacementString.utf16.count
//        let deltaCount = replacementCount - affectedCount
//
//        for var annotation in dataSource?.textViewAnnotations ?? [] where context.textView.textContentManager.offset(from: affectedRange.endLocation, to: annotation.location) >= 0 {
//            annotation.location = context.textView.textContentManager.location(annotation.location, offsetBy: deltaCount) ?? annotation.location
//        }
//
//        // Because annotation location position changed
//        // we need to reposition all views that may be
//        // affected by the text change
//        context.coordinator.layoutAnnotationViewsIfNeeded()
//    }
//
//    private func didLayoutViewport(context: any Context, _ range: NSTextRange?) {
//        context.coordinator.layoutAnnotationViewsIfNeeded()
//    }
//
//    public func makeCoordinator(context: CoordinatorContext) -> Coordinator {
//        Coordinator(parent: self, context: context)
//    }
//
//    /// Reloads the rows and sections of the table view.
//    ///
//    /// Performs the layout for annotation views.
//    public func reloadAnnotations() {
//        reloadDataHandler?()
//    }
// }
//
// extension STAnnotationsPlugin {
//
//    public class Coordinator {
//        private let parent: STAnnotationsPlugin
//        private let context: CoordinatorContext
//
//        init(parent: STAnnotationsPlugin, context: CoordinatorContext) {
//            self.context = context
//            self.parent = parent
//        }
//
//        @MainActor
//        func layoutAnnotationViewsIfNeeded() {
//            guard let dataSource = parent.dataSource else {
//                return
//            }
//
//            // Add views for annotations
//            var annotationViews: [PlatformView] = []
//            let textLayoutManager = context.textView.textLayoutManager
//            for annotation in dataSource.textViewAnnotations {
//                textLayoutManager.ensureLayout(for: NSTextRange(location: annotation.location))
//                if let textLayoutFragment = textLayoutManager.textLayoutFragment(for: annotation.location),
//                    let textLineFragment = textLayoutFragment.textLineFragment(at: annotation.location) {
//
//                    var lineFragmentFrame = textLayoutFragment.layoutFragmentFrame
//                    lineFragmentFrame.size.height = textLineFragment.typographicBounds.height
//
//                    let rightPadding: CGFloat = 24
//
//                    // Calculate proposed annotation view frame
//                    let x = context.textView.contentFrame.origin.x + lineFragmentFrame.maxX + 2 + rightPadding
//                    let proposedFrame = CGRect(
//                        x: x,
//                        y: context.textView.contentFrame.origin.y + lineFragmentFrame.origin.y + textLineFragment.typographicBounds.minY,
//                        width: context.textView.frame.maxX - x,
//                        height: lineFragmentFrame.height
//                    ).pixelAligned
//
//                    if let annotationView = dataSource.textView(context.textView, viewForLineAnnotation: annotation, textLineFragment: textLineFragment, proposedViewFrame: proposedFrame) {
//                        annotationViews.append(annotationView)
//                    }
//                }
//            }
//
//            for subview in parent.annotationsContentView.subviews {
//                subview.removeFromSuperview()
//            }
//            for view in annotationViews {
//                parent.annotationsContentView.addSubview(view)
//            }
//        }
//    }
//
// }
//
// // CGRect extension moved to CGRect+Extensions.swift
