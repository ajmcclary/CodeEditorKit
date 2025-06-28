// Sources/CodeEditorPlugin/Extensions/CodeEditorView+EditingActions.swift
import Foundation

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform editing actions for CodeEditorView
@MainActor
extension CodeEditorView {
    /// Perform a cut operation (copy selection and delete it)
    func performCut() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        cut(nil)
        #else
        if let selectedRange = selectedTextRange,
           let selectedText = text(in: selectedRange) {
            UIPasteboard.general.string = selectedText
            deleteBackward()
        }
        #endif
    }
    
    /// Perform a copy operation (copy selection to pasteboard)
    func performCopy() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        copy(nil)
        #else
        if let selectedRange = selectedTextRange,
           let selectedText = text(in: selectedRange) {
            UIPasteboard.general.string = selectedText
        }
        #endif
    }
    
    /// Perform a paste operation (insert pasteboard content at cursor)
    func performPaste() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        paste(nil)
        #else
        if let pasteString = UIPasteboard.general.string {
            insertText(pasteString)
        }
        #endif
    }
    
    /// Select all text in the editor
    func performSelectAll() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        selectAll(nil)
        #else
        selectAll(nil)
        #endif
    }
    
    /// Delete the current selection or character before cursor
    func performDelete() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        deleteBackward(nil)
        #else
        deleteBackward()
        #endif
    }
    
    /// Check if cut operation is available (has selection and is editable)
    var canCut: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return isEditable && selectedRange().length > 0
        #else
        return isEditable && selectedRange.length > 0
        #endif
    }
    
    /// Check if copy operation is available (has selection)
    var canCopy: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return selectedRange().length > 0
        #else
        return selectedRange.length > 0
        #endif
    }
    
    /// Check if paste operation is available (is editable and pasteboard has content)
    var canPaste: Bool {
        guard isEditable else { return false }
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return NSPasteboard.general.string(forType: .string) != nil
        #else
        return UIPasteboard.general.string != nil
        #endif
    }
}
