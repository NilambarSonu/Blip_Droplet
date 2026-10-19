//
//  BlipServicesAdapter.swift
//  BlipDroplet
//
//  Isolated adapter for the proven macOS Services ("Blip…") handoff mechanism.
//  In Phase 3A, live dispatch is strictly compiled out.
//

import Foundation

public enum BlipAdapterError: Error, Equatable, Sendable {
    case dispatchDisabledInPhase3A
    case blipNotInstalled
    case serviceHandoffFailed
    case invalidFileURL
}

public final class BlipServicesAdapter: Sendable {
    public static let shared = BlipServicesAdapter()

    /// Compile-time safety gate: In Phase 3A, this is FALSE.
    #if BLIP_DISPATCH_ENABLED
    public static let isDispatchCompiledIn: Bool = true
    #else
    public static let isDispatchCompiledIn: Bool = false
    #endif

    public static let serviceName: String = "Blip…"
    public static let blipBundleIdentifier: String = "net.blip.macos"
    public static let blipApplicationPath: String = "/Applications/Blip.app"

    public init() {}

    /// Checks if official Blip is installed on this Mac
    public func isBlipInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: Self.blipApplicationPath)
    }

    /// Requests handoff of a staged file to official Blip.
    /// In Phase 3A, live dispatch is completely compiled out to prevent accidental transmission.
    public func requestHandoff(
        for fileURL: URL,
        completion: @escaping @Sendable (Result<Bool, BlipAdapterError>) -> Void
    ) {
        guard fileURL.isFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            completion(.failure(.invalidFileURL))
            return
        }

        #if BLIP_DISPATCH_ENABLED
        // Real implementation guarded by build define
        Task { @MainActor in
            guard isBlipInstalled() else {
                completion(.failure(.blipNotInstalled))
                return
            }
            // In a future live dispatch phase with explicit authorization:
            // let pboard = NSPasteboard.withUniqueName()
            // pboard.writeObjects([fileURL as NSURL])
            // let success = NSPerformService(Self.serviceName, pboard)
            // completion(success ? .success(true) : .failure(.serviceHandoffFailed))
        }
        #else
        // Phase 3A Mandatory Safe Refusal
        completion(.failure(.dispatchDisabledInPhase3A))
        #endif
    }
}
