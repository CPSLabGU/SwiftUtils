/*
 * FileWrapperTests.swift
 * IOTests
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

import Foundation
@testable import SwiftUtils
import Testing

// #if os(Linux) || os(Windows)

/// Test class for ``FileWrapper``.
@Suite(.serialized)
final class FileWrapperTests {

    #if os(Windows)
    /// The path to the package root.
    private let packageRootPath = FileManager.default.currentDirectoryPath
    #else
    /// The path to the package root.
    private let packageRootPath = URL(fileURLWithPath: #file)
        .pathComponents.prefix { $0 != "Tests" }.joined(separator: "/").dropFirst()
    #endif

    /// IO helper.
    let manager = FileManager.default

    /// The path to the `SwiftUtilsTests` folder.
    var testsPath: URL {
        URL(fileURLWithPath: String(packageRootPath), isDirectory: true)
            .appendingPathComponent("Tests/SwiftUtilsTests", isDirectory: true)
    }

    /// The path to the build folder.
    var buildPath: URL {
        testsPath.appendingPathComponent("build", isDirectory: true)
    }

    /// Create build path before every test.
    init() {
        if !manager.fileExists(atPath: buildPath.path) {
            _ = try? manager.createDirectory(at: buildPath, withIntermediateDirectories: true)
        }
    }

    /// Test wrapper can write a single file.
    @Test
    func testWriteFileWrapper() throws {
        let raw = "Hello World!"
        guard let contents = raw.data(using: .utf8) else {
            Issue.record("Failed to create data!")
            return
        }
        let wrapper = FileWrapper(regularFileWithContents: contents)
        #expect(wrapper.isRegularFile)
        #expect(!wrapper.isDirectory)
        #expect(wrapper.filename == nil)
        wrapper.preferredFilename = "FileWrapperTest.txt"
        let path = buildPath.appendingPathComponent("FileWrapperTest.txt", isDirectory: false)
        try wrapper.write(to: path, originalContentsURL: nil)
        #expect(wrapper.filename == nil)
        #expect(wrapper.preferredFilename == "FileWrapperTest.txt")
        #expect(try String(contentsOf: path, encoding: .utf8) == raw)
    }

    /// Test wrapper can write a directory.
    @Test
    func testWriteDirectory() throws {
        let raw = "Subdir Hello World!"
        guard let contents = raw.data(using: .utf8) else {
            Issue.record("Failed to create data!")
            return
        }
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        #expect(wrapper.isDirectory)
        #expect(!wrapper.isRegularFile)
        wrapper.preferredFilename = "testDir"
        let wrapper2 = FileWrapper(regularFileWithContents: contents)
        wrapper2.preferredFilename = "data.txt"
        #expect(wrapper.addFileWrapper(wrapper2) == "data.txt")
        let testDir = buildPath.appendingPathComponent("testDir", isDirectory: true)
        try wrapper.write(to: testDir, originalContentsURL: nil)
        var isDirectory: ObjCBool = false
        #expect(manager.fileExists(atPath: testDir.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        let dataTxt = testDir.appendingPathComponent("data.txt", isDirectory: false)
        #expect(manager.fileExists(atPath: dataTxt.path, isDirectory: &isDirectory))
        #expect(!isDirectory.boolValue)
        let data = try String(contentsOf: dataTxt, encoding: .utf8)
        #expect(data == raw)
    }

    /// Test FileWrapper can overwrite a file.
    @Test
    func testOverwriteFile() throws {
        let newContents = "New Hello World!"
        let contents = Data("Hello World!".utf8)
        guard let newData = newContents.data(using: .utf8) else {
            Issue.record("Failed to create data.")
            return
        }
        let fileName = "FileWrapperTest.txt"
        let wrapper = FileWrapper(regularFileWithContents: contents)
        wrapper.preferredFilename = fileName
        let path = buildPath.appendingPathComponent(fileName, isDirectory: false)
        try wrapper.write(to: path, originalContentsURL: nil)
        let newWrapper = FileWrapper(regularFileWithContents: newData)
        newWrapper.preferredFilename = fileName
        try newWrapper.write(to: path, originalContentsURL: nil)
        guard let readContents = try? String(contentsOf: path, encoding: .utf8) else {
            Issue.record("Failed to read file.")
            return
        }
        #expect(readContents == newContents)
    }

    /// Test FileWrapper successfully overwrite a directory with new data.
    func testOverwriteDirectory() throws {
        let contents = "Subdir Hello World!"
        let contentsData = Data(contents.utf8)
        let testDir = "testDir"
        let dataTxt = "data.txt"
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        wrapper.preferredFilename = testDir
        let wrapper2 = FileWrapper(regularFileWithContents: contentsData)
        wrapper2.preferredFilename = dataTxt
        #expect(wrapper.addFileWrapper(wrapper2) == dataTxt)
        let path = buildPath.appendingPathComponent(testDir, isDirectory: true)
        print(path.path)
        try wrapper.write(to: path, originalContentsURL: nil)
        let dataPath = path.appendingPathComponent(dataTxt, isDirectory: false)
        let originalContents = try String(contentsOf: dataPath, encoding: .utf8)
        #expect(originalContents == contents)
        let newContents = "Subdir Hello World2!"
        let newContentsData = Data(newContents.utf8)
        let wrapperDir = FileWrapper(directoryWithFileWrappers: [:])
        wrapperDir.preferredFilename = testDir
        let dataWrapper = FileWrapper(regularFileWithContents: newContentsData)
        dataWrapper.preferredFilename = dataTxt
        #expect(wrapperDir.addFileWrapper(dataWrapper) == dataTxt)
        #expect(throws: (any Error).self) {
            try wrapperDir.write(to: path, originalContentsURL: nil)
        }
        #expect(!manager.fileExists(atPath: path.path))
    }

    /// Test URL init reads folder contents correctly.
    @Test
    func testURLInitDirectory() throws {
        #expect(
            manager.createFile(
                atPath: buildPath.appendingPathComponent("foo", isDirectory: false).path,
                contents: Data("bar".utf8)
            )
        )
        let wrapper = try FileWrapper(url: buildPath)
        #expect(wrapper.isDirectory)
        #expect(!wrapper.isRegularFile)
        #expect(wrapper.preferredFilename == "build")
        #expect(wrapper.filename == "build")
        guard let fileContents = wrapper.fileWrappers else {
            Issue.record("Failed to get file contents!")
            return
        }
        let data = Data("bar".utf8)
        #expect(fileContents.count == 1)
        guard let file = fileContents["foo"] else {
            Issue.record("Failed to get file!")
            return
        }
        #expect(file.isRegularFile)
        #expect(file.preferredFilename == "foo")
        #expect(file.filename == "foo")
        #expect(file.regularFileContents == data)
    }

    /// Test URL init reads folder contents correctly.
    @Test
    func testURLInitDirectoryNoFileURL() throws {
        let fooPath = buildPath.path + "/foo"
        #expect(manager.createFile(atPath: fooPath, contents: Data("bar".utf8)))
        guard let buildURL = URL(string: buildPath.path) else {
            Issue.record("Failed to create URL.")
            return
        }
        #expect(!buildURL.isFileURL)
        let error = #expect(throws: (NSError).self) { try FileWrapper(url: buildURL) }
        #expect(
            error == CocoaError.error(
                .fileReadUnsupportedScheme,
                userInfo: ["NSURL": buildURL.path],
                url: buildURL
            ) as NSError
        )
    }

    /// Test the `fileName` setter.
    @Test
    func testFileNameSetter() {
        let data = Data("Test".utf8)
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = "File1"
        #expect(wrapper.filename == nil)
        wrapper.filename = "New File"
        #expect(wrapper.preferredFilename == "File1")
        #expect(wrapper.filename == "New File")
    }

    #if !os(macOS)
    /// Test the add file wrapper handles regular files.
    @Test
    func testAddFileWrapperFile() throws {
        let data = Data("Test".utf8)
        let wrapper = FileWrapper(regularFileWithContents: data)
        let wrapper2 = FileWrapper(directoryWithFileWrappers: [:])
        #expect(wrapper.addFileWrapper(wrapper2).isEmpty)
    }
    #endif

    #if !os(macOS)
    /// Test the add file wrapper handles files without names.
    @Test
    func testAddFileWrapperNoPreferred() throws {
        let data = Data("Test".utf8)
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = nil
        let wrapper2 = FileWrapper(directoryWithFileWrappers: [:])
        #expect(wrapper2.addFileWrapper(wrapper).isEmpty)
    }
    #endif

    /// Test that the file is renamed when it overwrites a file with the same name.
    @Test
    func testAddFileWrapperPreferredTaken() throws {
        let data = Data("Test".utf8)
        let data2 = Data("Duplicate".utf8)
        let wrapper = FileWrapper(regularFileWithContents: data)
        #expect(wrapper.regularFileContents != nil)
        wrapper.preferredFilename = "data.txt"
        try wrapper.write(
            to: self.buildPath.appendingPathComponent("data.txt", isDirectory: false),
            originalContentsURL: nil
        )
        let wrapper2 = FileWrapper(directoryWithFileWrappers: ["data.txt": wrapper])
        wrapper2.preferredFilename = "build"
        let wrapper3 = FileWrapper(regularFileWithContents: data2)
        #expect(wrapper3.regularFileContents != nil)
        wrapper3.preferredFilename = "data.txt"
        let key = wrapper2.addFileWrapper(wrapper3)
        #expect(key != "data.txt")
        #expect(wrapper3.preferredFilename == "data.txt")
        #expect(wrapper3.filename == nil)
        try self.manager.removeItem(at: self.buildPath)
        try wrapper2.write(to: self.buildPath, originalContentsURL: nil)
        #expect(wrapper3.filename == nil)
        #expect(
            try String(
                contentsOf: self.buildPath.appendingPathComponent("data.txt", isDirectory: false),
                encoding: .utf8
            ) == "Test"
        )
        #expect(
            try String(
                contentsOf: self.buildPath.appendingPathComponent(key, isDirectory: false),
                encoding: .utf8
            ) == "Duplicate"
        )
        #expect(wrapper.filename == nil)
        #expect(wrapper2.fileWrappers?[key]?.regularFileContents == wrapper3.regularFileContents)
        #expect(wrapper2.fileWrappers?["data.txt"]?.regularFileContents == wrapper.regularFileContents)
    }

    // /// Test FileWrapper from URL throws error when overwriting deleted file.
    // func testWriteFileAfterDeletion() throws {
    //     guard let data = "Test".data(using: .utf8), let data2 = "Duplicate".data(using: .utf8) else {
    //         XCTFail("Failed to create data.")
    //         return
    //     }
    //     let wrapper = FileWrapper(regularFileWithContents: data)
    //     wrapper.preferredFilename = "data.txt"
    //     try wrapper.write(
    //         to: self.buildPath.appendingPathComponent("data.txt", isDirectory: false),
    //         originalContentsURL: nil
    //     )
    //     let wrapper2 = try FileWrapper(url: self.buildPath)
    //     let wrapper3 = FileWrapper(regularFileWithContents: data2)
    //     wrapper3.preferredFilename = "data.txt"
    //     let key = wrapper2.addFileWrapper(wrapper3)
    //     XCTAssertNotEqual(key, "data.txt")
    //     XCTAssertEqual(wrapper3.preferredFilename, "data.txt")
    //     XCTAssertNil(wrapper3.filename)
    //     try self.manager.removeItem(at: self.buildPath)
    //     XCTAssertThrowsError(try wrapper2.write(to: self.buildPath, originalContentsURL: nil)) {
    //         XCTAssertEqual(($0 as NSError).code, CocoaError.fileReadNoSuchFile.rawValue)
    //     }
    // }

    /// Test that an empty folder is written correctly.
    @Test
    func testWriteEmptyFolder() throws {
        let wrapper = FileWrapper(directoryWithFileWrappers: [:])
        wrapper.preferredFilename = "empty"
        let emptyPath = self.buildPath.appendingPathComponent("empty", isDirectory: true)
        try wrapper.write(to: emptyPath, originalContentsURL: nil)
        var isDirectory: ObjCBool = false
        #expect(self.manager.fileExists(atPath: emptyPath.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)
        #expect(
            (try self.manager.contentsOfDirectory(at: emptyPath, includingPropertiesForKeys: nil)).isEmpty
        )
    }

    /// Remove build folder after every test.
    deinit {
        _ = try? manager.removeItem(at: buildPath)
    }

}

// #endif
