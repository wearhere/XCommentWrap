//
//  SourceEditorCommand.swift
//  XCommentWrap-extension
//
//  Created by Mike Ash on 7/22/17.
//

import Foundation
import XcodeKit

import Swift

let lineRegex = try! NSRegularExpression(pattern: "^([ \t]*[/*]*[ \t]*)(.*)$", options: [])
let multiLineOpeningRegex = try! NSRegularExpression(pattern: "/\\*(?!.*\\*/)", options: [])
// Multi-line comments can nest, but we're going to ignore that and say that the
// first "*/" we find closes the comment.
let multiLineClosingRegex = try! NSRegularExpression(pattern: "\\*/", options: [])

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        let buffer = invocation.buffer
        
        for selection in buffer.selections {
            let selection = selection as! XCSourceTextRange
            let startLine = selection.start.line
            let endLine = selection.end.line
            var lineRange = NSRange(location: startLine, length: endLine - startLine + 1)
            
            if selection.end.column == 0 && endLine > startLine {
                lineRange.length -= 1
            }
            
            let lines = buffer.lines.subarray(with: lineRange) as! [String]
            
            var parsedLines = lines.compactMap(parse)
            guard !parsedLines.isEmpty else {
                return completionHandler(nil)
            }
            
            let leadings = Set(parsedLines.map({ $0.0 }))
            guard leadings.count == 1 else {
                // The user either selected both comment lines and code lines,
                // or comments of different styles (single-line, multi-line).
                // This might be unintentional, and handling it would be more
                // complex, so abort.
                //
                // Note that this means that if the user wants to wrap a
                // multi-line comment, their text can't be on the same line as
                // the opening and/or closing of the comment and they need to
                // select only the middle lines. This is documented in the
                // README.
                return completionHandler(nil)
            }
            
            let commonLeading = leadings.first!
            if commonLeading.trimmingCharacters(in: .whitespaces).count == 0 {
                guard rangeIsWithinMultiLineComment(lineRange, in: buffer.lines as! [String]) else {
                    // This must be code. Abort.
                    return completionHandler(nil)
                }
            }
            
            // Now we have the lines representing the user's initial selection.
            // Expand this to the end of their current paragraph in their
            // current comment block so that when we wrap a line at the start
            // of the paragraph, we'll "backfill" the new line from the rest
            // of the paragraph.
            var nextLine = NSMaxRange(lineRange)
            while nextLine < buffer.lines.count - 1 {
                guard let parsedComment = parse(line: buffer.lines[nextLine] as! String) else {
                    // Unknown condition, abort.
                    break
                }
                guard parsedComment.0 == commonLeading else {
                    // We've reached the end of the comment block.
                    break
                }
                guard !parsedComment.1.isEmpty else {
                    // We've reached the break between paragraphs.
                    break
                }
                parsedLines.append(parsedComment)
                lineRange.length += 1
                nextLine += 1
            }
            
            // Now go through and wrap all the lines in the selection, while
            // preserving paragraph breaks in the selection.
            var wrappedLines = Array<String>()
            var paragraphLines = Array<String>()
            func flushParagraphLines() {
                let wrappedParagraphLines = wrapLines(paragraphLines, to: 80 - commonLeading.count)
                wrappedLines.append(contentsOf: wrappedParagraphLines)
                paragraphLines = []
            }
            while parsedLines.count > 0 {
                let line = parsedLines.removeFirst().1
                if line.isEmpty {
                    // This is a paragraph break.
                    flushParagraphLines()
                    wrappedLines.append(line)
                } else {
                    paragraphLines.append(line)
                }
            }
            flushParagraphLines()
            
            let finalLines = wrappedLines.map({ commonLeading + $0 })
            
            buffer.lines.replaceObjects(in: lineRange, withObjectsFrom: finalLines)
        }
        
        completionHandler(nil)
    }
    
    /// Split a string into two parts: indentation plus optional comment indicator, and actual comment text.
    func parse(line: String) -> (String, String)? {
        let nsline = line as NSString
        
        let matchOpt = lineRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: nsline.length))
        guard let match = matchOpt else {
            return nil
        }
        
        let leadingRange = match.range(at: 1)
        let remainingRange = match.range(at: 2)
        return (nsline.substring(with: leadingRange), nsline.substring(with: remainingRange))
    }
    
    func rangeIsWithinMultiLineComment(_ range: NSRange, in lines: [String]) -> Bool {
        var openingFound = false, closingFound = false
        
        var previousLine = range.location - 1
        while previousLine > -1 {
            let line = lines[previousLine]
            if multiLineOpeningRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) != nil {
                openingFound = true
                break
            }
            previousLine -= 1
        }
        
        var nextLine = NSMaxRange(range)
        while nextLine < lines.count {
            let line = lines[nextLine]
            if multiLineClosingRegex.firstMatch(in: line, options: [], range: NSRange(location: 0, length: line.count)) != nil {
                closingFound = true
                break
            }
            nextLine += 1
        }
        
        return openingFound && closingFound
    }
 
    /// Wrap an array of lines.
    ///
    /// - Parameter lines: The lines to wrap.
    /// - Parameter width: The width to which to wrap.
    /// - Returns: An array of lines.
    func wrapLines(_ lines: [String], to width: Int) -> [String] {
        let fullText = lines.joined(separator: " ")
        return wrap(string: fullText, to: width)
    }
    
    /// Wrap a string into individual lines.
    ///
    /// - Parameter string: The string to wrap.
    /// - Parameter width: The width to which to wrap.
    /// - Returns: An array of lines.
    func wrap(string: String, to width: Int) -> [String] {
        var result: [String] = []
        var remainder: Substring? = Substring(string)
        while let s = remainder {
            let (line, more) = wrapOneLine(string: s, to: width)
            result.append(String(line))
            remainder = more
        }
        return result
    }
    
    /// Wrap a string into one line plus an optional remainder.
    ///
    /// - Parameter string: The string to wrap.
    /// - Parameter width: The width to which to wrap.
    /// - Returns: A tuple consisting of the first line and the rest of the string, or
    /// nil if the string is short enough to fit onto one line.
    func wrapOneLine(string: Substring, to width: Int) -> (Substring, Substring?) {
        var cursor = string.startIndex
        var lastSpaceIndex: Substring.Index?
        for _ in 0 ..< width {
            if cursor == string.endIndex {
                return (string, nil)
            }
            if string[cursor] == " " {
                lastSpaceIndex = cursor
            }
            
            cursor = string.index(after: cursor)
        }
        
        if let index = lastSpaceIndex {
            let plusOne = string.index(after: index)
            return (string[..<index], string[plusOne...])
        } else {
            return (string[..<cursor], string[cursor...])
        }
    }
}

