//
//  DSYMSearch.swift
//  MacSymbolicator
//

import Foundation
// swiftlint:disable line_length

struct SearchResult {
    let path: String
    let matchedUUID: String
}

class DSYMSearch {
    // MARK: - Type Aliases
    typealias LogHandler = (String) -> Void
    typealias ProgressHandler = (Float) -> Void
    typealias Callback = (Bool, [SearchResult]?) -> Void

    // MARK: - Private Properties
    private static let spotlightSearch = SpotlightSearch()
    private static let searchQueue = DispatchQueue(label: "com.symbo.dsymsearch", attributes: .concurrent)

    // MARK: - Enums
    enum SearchLocation: CaseIterable {
        case spotlight, nonRecursive, recursive
    }

    // MARK: - Public Methods
    static func search(
        forUUIDs uuids: [String],
        reportFileDirectory: String,
        logHandler: @escaping LogHandler,
        progressHandler: @escaping ProgressHandler,
        callback: @escaping Callback
    ) {
        let searchGroup = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "com.symbo.searchresults")
        var results: [SearchLocation: [SearchResult]] = [:]
        var errors: [SearchLocation: Error] = [:]

        let timeoutWorkItem = setupSearchTimeout(searchGroup: searchGroup, logHandler: logHandler)

        for location in SearchLocation.allCases {
            searchGroup.enter()
            searchQueue.async {
                searchLocation(
                    location,
                    forUUIDs: uuids,
                    reportFileDirectory: reportFileDirectory,
                    logHandler: logHandler
                ) { locationResults, error in
                    resultsQueue.async {
                        if let error = error {
                            errors[location] = error
                        } else if let locationResults = locationResults {
                            results[location] = locationResults
                        }

                        updateProgress(results: results, errors: errors, progressHandler: progressHandler)
                        searchGroup.leave()
                    }
                }
            }
        }

        searchGroup.notify(queue: .main) {
            timeoutWorkItem.cancel()
            let allResults = results.values.flatMap { $0 }
            callback(errors.isEmpty, allResults)
        }
    }

    // MARK: - Private Helper Methods
    private static func updateProgress(results: [SearchLocation: [SearchResult]], errors: [SearchLocation: Error], progressHandler: @escaping ProgressHandler) {
        let progress = Float(results.count + errors.count) / Float(SearchLocation.allCases.count)
        DispatchQueue.main.async {
            progressHandler(progress)
        }
    }

    private static func setupSearchTimeout(searchGroup: DispatchGroup, logHandler: @escaping LogHandler) -> DispatchWorkItem {
        let timeoutSeconds: Double = 300 // 5 minutes
        let timeoutWorkItem = DispatchWorkItem {
            logHandler("DSYMSearch timed out after \(Int(timeoutSeconds)) seconds.")
            searchGroup.notify(queue: .main) {
                logHandler("Search completed or timed out.")
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)

        return timeoutWorkItem
    }

    // MARK: - Search Methods
    private static func searchLocation(
        _ location: SearchLocation,
        forUUIDs uuids: [String],
        reportFileDirectory: String,
        logHandler: @escaping LogHandler,
        completion: @escaping ([SearchResult]?, Error?) -> Void
    ) {
        switch location {
        case .spotlight:
            searchSpotlight(forUUIDs: uuids, logHandler: logHandler, completion: completion)
        case .nonRecursive:
            searchNonRecursive(forUUIDs: uuids, inDirectory: reportFileDirectory, logHandler: logHandler, completion: completion)
        case .recursive:
            searchRecursive(forUUIDs: uuids, logHandler: logHandler, completion: completion)
        }
    }

    private static func searchSpotlight(
        forUUIDs uuids: [String],
        logHandler: @escaping LogHandler,
        completion: @escaping ([SearchResult]?, Error?) -> Void
    ) {
        logHandler("Searching Spotlight for UUIDs: \(uuids)")
        spotlightSearch.search(forUUIDs: uuids) { results in
            if let results = results {
                logHandler("Spotlight search completed. Found \(results.count) results.")
                completion(results, nil)
            } else {
                logHandler("Spotlight query could not be started.")
                completion(nil, NSError(domain: "DSYMSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: "Spotlight query failed"]))
            }
        }
    }

    private static func searchNonRecursive(
        forUUIDs uuids: [String],
        inDirectory directory: String,
        logHandler: @escaping LogHandler,
        completion: @escaping ([SearchResult]?, Error?) -> Void
    ) {
        logHandler("Non-recursive file search starting at \(directory) for UUIDs: \(uuids)")
        let results = performFileSearch(forUUIDs: uuids, inDirectory: directory, recursive: false, logHandler: logHandler)
        logHandler("Non-recursive search completed. Found \(results.count) results.")
        completion(results, nil)
    }

    private static func searchRecursive(
        forUUIDs uuids: [String],
        logHandler: @escaping LogHandler,
        completion: @escaping ([SearchResult]?, Error?) -> Void
    ) {
        let searchDirectory = "~/Library/Developer/Xcode/Archives/"
        logHandler("Recursive file search starting at \(searchDirectory) for UUIDs: \(uuids)")
        let results = performFileSearch(forUUIDs: uuids, inDirectory: searchDirectory, recursive: true, logHandler: logHandler)
        logHandler("Recursive search completed. Found \(results.count) results.")
        completion(results, nil)
    }

    private static func performFileSearch(forUUIDs uuids: [String], inDirectory directory: String, recursive: Bool, logHandler: @escaping LogHandler) -> [SearchResult] {
        let fileSearch = recursive ? FileSearch.recursive : FileSearch.nonRecursive
        return fileSearch
            .in(directory: directory)
            .with(logHandler: logHandler)
            .search(fileExtension: "dsym")
            .sorted()
            .matching(uuids: uuids)
    }
}
// swiftlint:enable line_length
