/*
 * FileWrapper.swift 
 * IO 
 *
 * Created by Morgan McColl on 03/10/2021.
 * Copyright © 2021 Morgan McColl. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * 3. All advertising materials mentioning features or use of this
 *    software must display the following acknowledgement:
 *
 *        This product includes software developed by Morgan McColl.
 *
 * 4. Neither the name of the author nor the names of contributors
 *    may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * -----------------------------------------------------------------------
 * This program is free software; you can redistribute it and/or
 * modify it under the above terms or under the terms of the GNU
 * General Public License as published by the Free Software Foundation;
 * either version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see http://www.gnu.org/licenses/
 * or write to the Free Software Foundation, Inc., 51 Franklin Street,
 * Fifth Floor, Boston, MA  02110-1301, USA.
 *
 */

#if (os(Linux) || os(Windows)) && canImport(Foundation)

import Foundation

open class FileWrapper {

    public struct WritingOptions: OptionSet {

        public static var atomic: FileWrapper.WritingOptions = FileWrapper.WritingOptions(rawValue: 1)

        public static var withNameUpdating: FileWrapper.WritingOptions = FileWrapper.WritingOptions(
            rawValue: 2
        )

        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

    }

    public struct ReadingOptions: OptionSet {

        public static var immediate: FileWrapper.ReadingOptions = FileWrapper.ReadingOptions(rawValue: 1)

        public static var withoutMapping: FileWrapper.ReadingOptions = FileWrapper.ReadingOptions(rawValue: 2)

        public var rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }

    public var filename: String?

    public var preferredFilename: String?

    public var regularFileContents: Data?

    public var fileWrappers: [String: FileWrapper]?

    private let manager = FileManager.default

    public var isRegularFile: Bool {
        fileWrappers == nil && regularFileContents != nil
    }

    public var isDirectory: Bool {
        !isRegularFile
    }

    private var name: String {
        if let name = filename {
            return name
        }
        if let preferred = preferredFilename {
            filename = preferred
            return preferred
        }
        filename = UUID().uuidString
        return filename!
    }

    public init(regularFileWithContents: Data) {
        self.regularFileContents = regularFileWithContents
    }

    public init(directoryWithFileWrappers: [String: FileWrapper]) {
        self.fileWrappers = directoryWithFileWrappers
    }

    public init(url: URL, options: FileWrapper.ReadingOptions = []) throws {
        self.preferredFilename = url.lastPathComponent
        self.filename = url.lastPathComponent
        guard url.isFileURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSURLErrorUnsupportedURL, userInfo: [
                "NSURL": url.path
            ])
        }
        guard url.hasDirectoryPath else {
            let data = try Data(contentsOf: url, options: Data.ReadingOptions(rawValue: options.rawValue))
            self.regularFileContents = data
            return
        }
        let manager = FileManager()
        let urls = try manager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        self.fileWrappers = Dictionary(uniqueKeysWithValues: try urls.map {
            let wrapper = try FileWrapper(url: $0)
            guard let fileName = wrapper.preferredFilename else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileNoSuchFile.rawValue)
            }
            return (fileName, wrapper)
        })
    }

    public func addFileWrapper(_ child: FileWrapper) -> String {
        guard var wrappers = fileWrappers else {
            return ""
        }
        if let childName = child.preferredFilename {
            if wrappers[childName] == nil {
                wrappers[childName] = child
                fileWrappers = wrappers
                return childName
            }
        }
        var newName = UUID().uuidString
        repeat {
            newName = UUID().uuidString
        } while (wrappers[newName] != nil)
        wrappers[newName] = child
        child.preferredFilename = newName
        fileWrappers = wrappers
        return newName
    }

    open func write(
        to path: URL, options: FileWrapper.WritingOptions = [], originalContentsURL: URL?
    ) throws {
        guard !isRegularFile else {
            guard path.isFileURL, let contents = regularFileContents else {
                throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileReadUnsupportedScheme.rawValue)
            }
            if manager.fileExists(atPath: path.path) {
                guard (try? manager.removeItem(at: path)) != nil else {
                    throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileNoSuchFile.rawValue)
                }
            }
            try contents.write(to: path, options: Data.WritingOptions(rawValue: options.rawValue))
            return
        }
        guard path.hasDirectoryPath else {
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteFileExists.rawValue)
        }
        guard !manager.fileExists(atPath: path.path) else {
            _ = try? manager.removeItem(at: path)
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: CocoaError.fileNoSuchFile.rawValue,
                userInfo: ["NSFilePath": path.path, "NSUnderlyingError": POSIXError.EBADF]
            )
        }
        try manager.createDirectory(at: path, withIntermediateDirectories: false)
        guard let wrappers = fileWrappers else {
            return
        }
        try wrappers.sorted { $0.0 < $1.0 }.forEach { _, wrapper throws in
            try wrapper.write(
                to: path.appendingPathComponent(wrapper.name, isDirectory: wrapper.isDirectory),
                options: options,
                originalContentsURL: originalContentsURL?.appendingPathComponent(
                    wrapper.name, isDirectory: wrapper.isDirectory
                )
            )
        }
    }

}

#endif
