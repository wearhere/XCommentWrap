//
//  SourceEditorCommand.swift
//  XCommentWrap-extension
//
//  Created by Mike Ash on 7/22/17.
//

import Foundation
import XcodeKit

import Swift

let lineRegex = try! NSRegularExpression(pattern: "^([ \t]*[/*]+[ \t]*)(.*)$", options: [])

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
            guard parsedLines.count == lines.count else {
                // The user selected both comment lines and code lines here,
                // or maybe even _just_ code lines. Rather than truncate and/or
                // split the range we're formatting, it's simpler to abort.
                return completionHandler(nil)
            }
            
            // Now we have the lines representing the user's initial selection.
            // Expand this to the end of their current paragraph in their
            // current comment block so that when we wrap a line at the start
            // of the paragraph, we'll "backfill" the new line from the rest
            // of the paragraph.
            var nextLine = NSMaxRange(lineRange);
            while nextLine < buffer.lines.count - 1 {
                guard let parsedComment = parse(line: buffer.lines[nextLine] as! String) else {
                    // We've reached the end of the comment block altogether.
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
            
            let commonLeading = parsedLines[0].0
            
            let fullText = parsedLines.map({ $1 }).joined(separator: " ")
            let wrappedLines = wrap(string: fullText, to: 80 - commonLeading.count)
            
            let finalLines = wrappedLines.map({ commonLeading + $0 })
            
            buffer.lines.replaceObjects(in: lineRange, withObjectsFrom: finalLines)
        }
        
        completionHandler(nil)
    }
    
    /// Split a string into two parts: indentation plus comment indicator, and actual comment text.
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

