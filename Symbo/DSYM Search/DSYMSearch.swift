//
//  DSYMSearch.swift
//  MacSymbolicator
//

import Foundation

struct SearchResult {
    let path: String
    let matchedUUID: String
}

class DSYMSearch {
    typealias LogHandler = (String) -> Void
    typealias ProgressHandler = (Float) -> Void
    typealias Callback = (_ finished: Bool, _ results: [SearchResult]?) -> Void

    private static let spotlightSearch = SpotlightSearch()

    enum SearchLocation: CaseIterable {
        case spotlight
        case nonRecursive
        case recursive
    }

    static func search(
        forUUIDs uuids: [String],
        reportFileDirectory: String,
        logHandler: @escaping LogHandler,
        progressHandler: @escaping ProgressHandler,
        callback: @escaping Callback
    ) {
        let searchGroup = DispatchGroup()
        let searchQueue = DispatchQueue(label: "com.macsymbolicator.dsymsearch", attributes: .concurrent)

        var results: [SearchLocation: [SearchResult]] = [:]
        var errors: [SearchLocation: Error] = [:]

        let totalLocations = SearchLocation.allCases.count
        var completedLocations = 0

        for location in SearchLocation.allCases {
            searchGroup.enter()
            searchQueue.async {
                self.searchLocation(
                    location,
                    forUUIDs: uuids,
                    reportFileDirectory: reportFileDirectory,
                    logHandler: logHandler
                ) { locationResults, error in
                    if let error = error {
                        errors[location] = error
                    } else if let locationResults = locationResults {
                        results[location] = locationResults
                    }

                    searchQueue.async {
                        completedLocations += 1
                        let progress = Float(completedLocations) / Float(totalLocations)
                        progressHandler(progress)
                    }

                    searchGroup.leave()
                }
            }
        }

        // Timeout for the entire search process
        let timeoutSeconds: Double = 300 // 5 minutes
        let timeoutWorkItem = DispatchWorkItem {
            logHandler("DSYMSearch timed out after \(Int(timeoutSeconds)) seconds.")
            searchGroup.leave() // Force the group to finish
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)

        searchGroup.notify(queue: .main) {
            timeoutWorkItem.cancel() // Cancel the timeout if all searches complete in time

            let allResults = results.values.flatMap { $0 }
            let allErrors = errors.values

            if !allErrors.isEmpty {
                logHandler("Errors occurred during DSYMSearch: \(allErrors)")
            }

            callback(errors.isEmpty, allResults)
        }
    }

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
            searchNonRecursive(forUUIDs: uuids,
                               inDirectory: reportFileDirectory,
                               logHandler: logHandler,
                               completion: completion)
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
                completion(nil, NSError(domain: "DSYMSearch",
                                        code: 1,
                                        userInfo: [NSLocalizedDescriptionKey: "Spotlight query failed"]))
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
        let results = FileSearch
            .nonRecursive
            .in(directory: directory)
            .with(logHandler: logHandler)
            .search(fileExtension: "dsym").sorted().matching(uuids: uuids)

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
        let results = FileSearch
            .recursive
            .in(directory: searchDirectory)
            .with(logHandler: logHandler)
            .search(fileExtension: "dsym").sorted().matching(uuids: uuids)

        logHandler("Recursive search completed. Found \(results.count) results.")
        completion(results, nil)
    }
}
