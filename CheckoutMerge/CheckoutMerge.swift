//
//  CheckoutMerge.swift
//  CheckoutMerge
//
//  Created by Dhyan Thacker on 6/21/25.
//

import Foundation
import ArgumentParser

@main
struct CheckoutMerge: ParsableCommand {
    @Argument(help: "Branch to merge to")
    var mergeBranch: String
    
    @Argument(help: "Branch to merge from, default is current branch")
    var mergeFromBranch: String!
    
    @Option(name: .shortAndLong, help: "Git repository root directory, if not provided, defaults to current directory")
    var repo: String?
    
    mutating func run() throws {
        if let repo {
            FileManager.default.changeCurrentDirectoryPath(repo)
        }
        if mergeFromBranch == nil {
            mergeFromBranch = try getCurrentBranch(in: FileManager.default.currentDirectoryPath)
        }
        let env = ProcessInfo.processInfo.environment
        if env["CHECKOUTMERGE_SKIPCONFIRM"] != "1" {
            print("This will merge \(mergeFromBranch!) into \(mergeBranch). Continue? (y/n)")
            print("Note: To disable this prompt, set CHECKOUTMERGE_SKIPCONFIRM = 1.")
            guard let input = readLine(), input.lowercased() == "y" else {
                print("Merge cancelled.")
                return
            }
        } else {
            print("Merging \(mergeFromBranch!) into \(mergeBranch)...")
        }
        try runGitCommand(args: ["checkout", mergeBranch], in: FileManager.default.currentDirectoryPath)
        print("Checked out \(mergeBranch). Initiating merge...")
        try runGitCommand(args: ["merge", mergeFromBranch], in: FileManager.default.currentDirectoryPath)
        print("Merge completed. Delete original branch? (y/n)")
        if let input = readLine(), input.lowercased() == "y" {
            print("This is permanent. ARE YOU SURE?")
            if let input = readLine(), input.lowercased() == "y" {
                try runGitCommand(args: ["branch", "-D", mergeFromBranch], in: FileManager.default.currentDirectoryPath)
            }
        }
    }
    
    func runGitCommand(args: [String], in directory: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardError = pipe
        
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw RuntimeError("Git command failed: git \(args.joined(separator: " "))\n\(errorMessage)")
        }
    }
    
    func getCurrentBranch(in directory: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw RuntimeError("Failed to get current branch:\n\(errorMessage)")
        }

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty else {
            throw RuntimeError("Could not parse current branch name")
        }
        return output
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }

    init(_ message: String) {
        self.message = message
    }
}
