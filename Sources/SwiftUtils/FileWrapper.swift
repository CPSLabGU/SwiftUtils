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

/// A representation of a node (a file, directory, or symbolic link) in the file system.
/// 
/// The FileWrapper class provides access to the attributes and contents of file system nodes. A file system
/// node is a file, directory, or symbolic link. Instances of this class are known as file wrappers.
/// File wrappers represent a file system node as an object that can be displayed as an image (and possibly
/// edited in place), saved to the file system, or transmitted to another application.
/// 
/// There are three types of file wrappers:
/// - **Regular-file file wrapper**: Represents a regular file.
/// - **Directory file wrapper**: Represents a directory.
/// - **Symbolic-link file wrapper**: Represents a symbolic link.
/// A file wrapper has these attributes:
/// - **Filename.**: The name of the file system node the file wrapper represents.
/// - **file-system attributes.** See ``Foundation.FileManager`` for information on the contents of the
/// `attributes` dictionary.
/// - **Regular-file contents.** Applicable only to regular-file file wrappers.
/// - **File wrappers.** Applicable only to directory file wrappers.
/// - **Destination node.** Applicable only to symbolic-link file wrappers.
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

    /// The filename of the file wrapper object
    public var filename: String?

    /// The preferred filename for the file wrapper object.
    public var preferredFilename: String?

    /// The contents of the file-system node associated with a regular-file file wrapper.
    public var regularFileContents: Data?

    /// The file wrappers contained by a directory file wrapper.
    public var fileWrappers: [String: FileWrapper]?

    private let manager = FileManager.default

    /// This property contains a boolean value that indicates whether the file wrapper object is a
    /// regular-file.
    public var isRegularFile: Bool {
        fileWrappers == nil && regularFileContents != nil
    }

    /// This property contains a boolean value indicating whether the file wrapper is a directory file
    /// wrapper.
    public var isDirectory: Bool {
        !isRegularFile
    }

    /// A name helper.
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

    /// Initializes the receiver as a regular-file file wrapper.
    /// 
    /// After initialization, the file wrapper is not associated with a file-system node until you save it
    /// using ``write(to:options:originalContentsURL:)``. The receiver is initialized with open permissions:
    /// anyone can read, write, or modify the directory on disk. If any file wrapper in the directory doesn’t
    /// have a preferred filename, its preferred name is automatically set to its corresponding key in the
    /// childrenByPreferredName dictionary.
    /// 
    /// After initialization, the file wrapper is not associated with a file-system node until you save it
    /// using ``write(to:options:originalContentsURL:)``. The file wrapper is initialized with open
    /// permissions: anyone can write to or read the file wrapper.
    /// - Parameter regularFileWithContents: Contents of the file.
    /// - Returns: Initialized regular-file file wrapper containing contents.
    public init(regularFileWithContents: Data) {
        self.regularFileContents = regularFileWithContents
    }

    /// Initializes the receiver as a directory file wrapper, with a given file-wrapper list.
    /// - Parameter directoryWithFileWrappers: Key-value dictionary of file wrappers with which to initialize
    ///                                        the receiver. The dictionary must contain entries whose values
    ///                                        are the file wrappers that are to become children and whose
    ///                                        keys are filenames. See Accessing File Wrapper Identities in
    ///                                        File System Programming Guide for more information about the
    ///                                        file-wrapper list structure.
    /// - Returns: Initialized file wrapper for fileWrappers.
    public init(directoryWithFileWrappers: [String: FileWrapper]) {
        self.fileWrappers = directoryWithFileWrappers
    }

    /// Initializes a file wrapper instance whose kind is determined by the type of file-system node located
    /// by the URL.
    /// 
    /// If url is a directory, this method recursively creates file wrappers for each node within that
    /// directory. Use the `fileWrappers` property to get the file wrappers of the nodes contained by the
    /// directory.
    /// - Parameters:
    ///     - url: URL of the file-system node the file wrapper is to represent.
    ///     - options: Option flags for reading the node located at `url`. See ``FileWrapper.ReadingOptions``
    ///                for possible values.
    /// - Returns: File wrapper for the file-system node at url. May be a directory, file, or symbolic link,
    ///            depending on what is located at the URL. Returns false (0) if reading is not successful.
    public init(url: URL, options: FileWrapper.ReadingOptions = []) throws {
        self.preferredFilename = url.lastPathComponent
        self.filename = url.lastPathComponent
        guard url.isFileURL else {
            throw CocoaError.error(
                .fileReadUnsupportedScheme, userInfo: ["NSURL": url.path], url: url
            )
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

    /// Adds a child file wrapper to the receiver, which must be a directory file wrapper.
    /// 
    /// Use this method to add an existing file wrapper as a child of a directory file wrapper. If the file
    /// wrapper does not have a preferred filename, set the ``preferredFilename`` property to give it one
    /// before calling ``addFileWrapper(_:)``. To create a new file wrapper and add it to a directory, use the
    /// ``addRegularFile(withContents:preferredFilename:)`` method.
    /// - Parameter child: File wrapper to add to the directory.
    /// - Returns: Dictionary key used to store fileWrapper in the directory’s list of file wrappers. The
    ///            dictionary key is a unique filename, which is the same as the passed-in file wrapper's
    ///            preferred filename unless that name is already in use as a key in the directory’s
    ///            dictionary of children. See Accessing File Wrapper Identities in File System Programming
    ///            Guide for more information about the file-wrapper list structure.
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

    /// Recursively writes the entire contents of a file wrapper to a given file-system URL.
    /// - Parameters:
    ///   - path: URL of the file-system node to which the file wrapper’s contents are written.
    ///   - options: 
    ///   - originalContentsURL: 
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
