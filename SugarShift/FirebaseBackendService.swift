import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

enum FirebaseBackendStatus: Equatable {
    case unavailable
    case missingPlist
    case ready
}

enum FirebaseBackendError: LocalizedError {
    case sdkUnavailable
    case missingConfiguration
    case notSignedIn
    case invalidAppleCredential
    case nonceGenerationFailed
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            return "Firebase SDK is not linked."
        case .missingConfiguration:
            return "Add GoogleService-Info.plist to enable Firebase."
        case .notSignedIn:
            return "Sign in with Apple first."
        case .invalidAppleCredential:
            return "Apple did not return a usable sign-in token."
        case .nonceGenerationFailed:
            return "Could not create a secure Apple sign-in nonce."
        case .decodeFailed:
            return "Could not read the saved cloud progress."
        }
    }
}

/// Firebase-backed player account sync. StoreKit remains the purchase gate;
/// Firebase stores the player's merged progress and delivery ledger so a
/// signed-in player can move to another device without losing consumables.
final class FirebaseBackendService: NSObject {
    static let shared = FirebaseBackendService()

    private let region = "europe-west1"
    private var statusStorage: FirebaseBackendStatus = .unavailable
    private var syncWorkItem: DispatchWorkItem?
    private var currentNonce: String?
    private weak var presentationAnchor: ASPresentationAnchor?
    private var signInCompletion: ((Result<Void, Error>) -> Void)?
    private var didConfigureDefaultApp = false
    private var progressSyncSuspendedUntil: Date?
    private var lastProgressSyncFailureLogAt: Date?

    #if canImport(FirebaseAuth)
    private var authHandle: AuthStateDidChangeListenerHandle?
    #endif

    private override init() {
        super.init()
    }

    var status: FirebaseBackendStatus { statusStorage }

    var isReady: Bool {
        statusStorage == .ready
    }

    var isSignedIn: Bool {
        #if canImport(FirebaseAuth)
        return isReady && Auth.auth().currentUser != nil
        #else
        return false
        #endif
    }

    var accountTitle: String {
        "Apple Account"
    }

    var accountSubtitle: String {
        #if canImport(FirebaseAuth)
        if !isReady {
            return statusStorage == .missingPlist ? String(localized: "Firebase setup needed") : String(localized: "Firebase SDK missing")
        }
        if let user = Auth.auth().currentUser {
            if let email = user.email, !email.isEmpty { return email }
            return "Signed in"
        }
        return "Sign in to sync progress"
        #else
        return "Firebase SDK missing"
        #endif
    }

    var accountButtonTitle: String {
        isSignedIn ? String(localized: "Sync") : String(localized: "Sign In")
    }

    var accountActionEnabled: Bool {
        isReady
    }

    func configureIfAvailable() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth)
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            statusStorage = .missingPlist
            return
        }

        if !didConfigureDefaultApp {
            FirebaseApp.configure()
            didConfigureDefaultApp = true
        }
        statusStorage = .ready

        if authHandle == nil {
            authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let self, user != nil else { return }
                self.pullProgressFromBackend { _ in
                    self.scheduleProgressSync()
                }
            }
        }
        #else
        statusStorage = .unavailable
        #endif
    }

    func scheduleProgressSync() {
        guard isSignedIn, canAttemptAutomaticProgressSync() else { return }
        syncWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pushProgressToBackend(automatic: true, completion: nil)
        }
        syncWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    func syncNow(completion: @escaping (Result<Void, Error>) -> Void) {
        guard isReady else {
            completion(.failure(FirebaseBackendError.missingConfiguration))
            return
        }
        guard isSignedIn else {
            completion(.failure(FirebaseBackendError.notSignedIn))
            return
        }
        progressSyncSuspendedUntil = nil

        pullProgressFromBackend { [weak self] pullResult in
            guard let self else { return completion(pullResult) }
            switch pullResult {
            case .success:
                self.pushProgressToBackend(automatic: false, completion: completion)
            case .failure:
                self.pushProgressToBackend(automatic: false, completion: completion)
            }
        }
    }

    func signInWithApple(presentationAnchor: ASPresentationAnchor?,
                         completion: @escaping (Result<Void, Error>) -> Void) {
        guard isReady else {
            completion(.failure(FirebaseBackendError.missingConfiguration))
            return
        }

        #if canImport(FirebaseAuth)
        guard let nonce = randomNonceString() else {
            completion(.failure(FirebaseBackendError.nonceGenerationFailed))
            return
        }

        currentNonce = nonce
        self.presentationAnchor = presentationAnchor
        signInCompletion = completion

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        #else
        completion(.failure(FirebaseBackendError.sdkUnavailable))
        #endif
    }

    func signOut() {
        guard isReady else { return }
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
        } catch {
            Analytics.track("firebase_sign_out_failed", properties: ["error": "\(error)"])
        }
        #endif
    }

    func recordStoreKitDelivery(transactionID: String, productID: String, coins: Int) {
        guard isSignedIn else { return }
        #if canImport(FirebaseAuth) && canImport(FirebaseFunctions)
        guard let user = Auth.auth().currentUser else { return }
        user.getIDTokenForcingRefresh(false) { [weak self] token, tokenError in
            guard let self else { return }
            if let tokenError {
                Analytics.track("firebase_storekit_delivery_failed",
                                properties: ["error": self.trimmedErrorDescription(tokenError),
                                             "product": productID])
                return
            }

            var payload: [String: Any] = [
                "transactionID": transactionID,
                "productID": productID,
                "coins": coins,
                "clientUpdatedAt": Date().timeIntervalSince1970
            ]
            if let token {
                payload["authIDToken"] = token
            }

            Functions.functions(region: self.region)
                .httpsCallable("recordStoreKitDelivery")
                .call(payload) { result, error in
                    if let error {
                        Analytics.track("firebase_storekit_delivery_failed",
                                        properties: ["error": self.trimmedErrorDescription(error),
                                                     "product": productID])
                        return
                    }
                    if let data = result?.data as? [String: Any],
                       let alreadyRecorded = data["alreadyRecorded"] as? Bool,
                       alreadyRecorded {
                        Analytics.track("firebase_storekit_delivery_duplicate",
                                        properties: ["product": productID,
                                                     "transaction": transactionID])
                    }
                }
        }
        #endif
    }

    func pullProgressFromBackend(completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard isSignedIn else {
            completion?(.failure(FirebaseBackendError.notSignedIn))
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseFunctions)
        guard let user = Auth.auth().currentUser else {
            completion?(.failure(FirebaseBackendError.notSignedIn))
            return
        }

        user.getIDTokenForcingRefresh(false) { [weak self] token, tokenError in
            guard let self else { return }
            if let tokenError {
                Analytics.track("firebase_progress_pull_failed",
                                properties: ["error": self.trimmedErrorDescription(tokenError)])
                completion?(.failure(tokenError))
                return
            }

            self.callPullProgress(user: user,
                                  authIDToken: token,
                                  retriedAfterAuthFailure: false,
                                  completion: completion)
        }
        #else
        completion?(.failure(FirebaseBackendError.sdkUnavailable))
        #endif
    }

    private func pushProgressToBackend(automatic: Bool,
                                       completion: ((Result<Void, Error>) -> Void)?) {
        guard isSignedIn else {
            completion?(.failure(FirebaseBackendError.notSignedIn))
            return
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseFunctions)
        guard let user = Auth.auth().currentUser else {
            completion?(.failure(FirebaseBackendError.notSignedIn))
            return
        }

        do {
            let state = try Self.encodeBackendState(Persistence.exportBackendState())
            user.getIDTokenForcingRefresh(false) { [weak self] token, tokenError in
                guard let self else { return }
                if let tokenError {
                    self.handleProgressPushFailure(tokenError, automatic: automatic)
                    completion?(.failure(tokenError))
                    return
                }

                self.callSyncProgress(state: state,
                                      user: user,
                                      authIDToken: token,
                                      automatic: automatic,
                                      retriedAfterAuthFailure: false,
                                      completion: completion)
            }
        } catch {
            completion?(.failure(error))
        }
        #else
        completion?(.failure(FirebaseBackendError.sdkUnavailable))
        #endif
    }

    private func callSyncProgress(state: [String: Any],
                                  user: User,
                                  authIDToken: String?,
                                  automatic: Bool,
                                  retriedAfterAuthFailure: Bool,
                                  completion: ((Result<Void, Error>) -> Void)?) {
        var payload: [String: Any] = ["state": state]
        if let authIDToken {
            payload["authIDToken"] = authIDToken
        }

        Functions.functions(region: region)
            .httpsCallable("syncProgress")
            .call(payload) { [weak self] _, error in
                guard let self else { return }
                if let error {
                    let failureCategory = self.progressPushFailureCategory(error)
                    if !retriedAfterAuthFailure,
                       failureCategory == "unauthenticated" {
                        user.getIDTokenForcingRefresh(true) { [weak self] refreshedToken, refreshError in
                            guard let self else { return }
                            if let refreshError {
                                self.handleProgressPushFailure(refreshError, automatic: automatic)
                                completion?(.failure(refreshError))
                                return
                            }

                            self.callSyncProgress(state: state,
                                                  user: user,
                                                  authIDToken: refreshedToken,
                                                  automatic: automatic,
                                                  retriedAfterAuthFailure: true,
                                                  completion: completion)
                        }
                        return
                    }

                    if retriedAfterAuthFailure, failureCategory == "unauthenticated" {
                        self.clearRejectedFirebaseSession()
                    }
                    self.handleProgressPushFailure(error, automatic: automatic)
                    completion?(.failure(error))
                    return
                }
                completion?(.success(()))
            }
    }

    private func callPullProgress(user: User,
                                  authIDToken: String?,
                                  retriedAfterAuthFailure: Bool,
                                  completion: ((Result<Void, Error>) -> Void)?) {
        var payload: [String: Any] = [:]
        if let authIDToken {
            payload["authIDToken"] = authIDToken
        }

        Functions.functions(region: region)
            .httpsCallable("pullProgress")
            .call(payload) { [weak self] result, error in
                guard let self else { return }
                if let error {
                    let failureCategory = self.progressPushFailureCategory(error)
                    if !retriedAfterAuthFailure,
                       failureCategory == "unauthenticated" {
                        user.getIDTokenForcingRefresh(true) { [weak self] refreshedToken, refreshError in
                            guard let self else { return }
                            if let refreshError {
                                Analytics.track("firebase_progress_pull_failed",
                                                properties: ["error": self.trimmedErrorDescription(refreshError)])
                                completion?(.failure(refreshError))
                                return
                            }

                            self.callPullProgress(user: user,
                                                  authIDToken: refreshedToken,
                                                  retriedAfterAuthFailure: true,
                                                  completion: completion)
                        }
                        return
                    }

                    if retriedAfterAuthFailure, failureCategory == "unauthenticated" {
                        self.clearRejectedFirebaseSession()
                    }
                    Analytics.track("firebase_progress_pull_failed",
                                    properties: ["error": self.trimmedErrorDescription(error)])
                    completion?(.failure(error))
                    return
                }

                guard let response = result?.data as? [String: Any],
                      let data = response["state"] as? [String: Any],
                      !data.isEmpty else {
                    completion?(.success(()))
                    return
                }

                do {
                    let state = try Self.decodeBackendState(from: data)
                    Persistence.applyBackendState(state)
                    completion?(.success(()))
                } catch {
                    Analytics.track("firebase_progress_decode_failed",
                                    properties: ["error": "\(error)"])
                    completion?(.failure(error))
                }
            }
    }

    private func clearRejectedFirebaseSession() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            Analytics.track("firebase_session_cleared_after_auth_rejection")
        } catch {
            Analytics.track("firebase_sign_out_failed", properties: ["error": "\(error)"])
        }
        #endif
    }

    private func canAttemptAutomaticProgressSync() -> Bool {
        guard let suspendedUntil = progressSyncSuspendedUntil else { return true }
        if suspendedUntil > Date() { return false }
        progressSyncSuspendedUntil = nil
        return true
    }

    private func handleProgressPushFailure(_ error: Error, automatic: Bool) {
        let category = progressPushFailureCategory(error)
        if automatic {
            let cooldown: TimeInterval
            switch category {
            case "unauthenticated":
                cooldown = 300
            case "network":
                cooldown = 60
            default:
                cooldown = 30
            }
            progressSyncSuspendedUntil = Date().addingTimeInterval(cooldown)
        }

        guard shouldLogProgressPushFailure(automatic: automatic) else { return }
        Analytics.track("firebase_progress_push_failed",
                        properties: ["category": category,
                                     "error": trimmedErrorDescription(error)])
    }

    private func shouldLogProgressPushFailure(automatic: Bool) -> Bool {
        if !automatic { return true }
        let now = Date()
        if let last = lastProgressSyncFailureLogAt,
           now.timeIntervalSince(last) < 60 {
            return false
        }
        lastProgressSyncFailureLogAt = now
        return true
    }

    private func progressPushFailureCategory(_ error: Error) -> String {
        let text = "\(error)".lowercased()
        if text.contains("unauthenticated") { return "unauthenticated" }
        if text.contains("network")
            || text.contains("unavailable")
            || text.contains("not connected")
            || text.contains("offline")
            || text.contains("no network route") {
            return "network"
        }
        return "other"
    }

    private func trimmedErrorDescription(_ error: Error) -> String {
        let raw = "\(error)"
        if raw.count <= 260 { return raw }
        return String(raw.prefix(260))
    }

    private static func encodeBackendState(_ state: Persistence.BackendState) throws -> [String: Any] {
        let data = try JSONEncoder().encode(state)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FirebaseBackendError.decodeFailed
        }
        return object
    }

    private static func decodeBackendState(from data: [String: Any]) throws -> Persistence.BackendState {
        // Remote progress is client-authored except for separate StoreKit ledger
        // calls, so do not trust cloud economy values even if older documents
        // still contain them. Start from local defaults for required fields and
        // overlay only client-safe progress state from the backend.
        let allowedKeys: Set<String> = [
            "schemaVersion",
            "clientUpdatedAt",
            "currentLevel",
            "totalScore",
            "dailyRewardDate",
            "dailyAdBonusDate",
            "dailyStreak",
            "unlockedThemes",
            "deliveredStoreKitTransactionIDs",
            "stars",
            "claimedRewards",
            "claimedThreeStarRewards",
            "claimedEventRewards",
            "claimedBossRewards",
            "medals",
            "ratings",
            "storeKitCoinCredits"
        ]
        var cleaned = try encodeBackendState(Persistence.exportBackendState())
        for (key, value) in data where allowedKeys.contains(key) {
            cleaned[key] = value
        }
        guard JSONSerialization.isValidJSONObject(cleaned) else {
            throw FirebaseBackendError.decodeFailed
        }
        let json = try JSONSerialization.data(withJSONObject: cleaned)
        return try JSONDecoder().decode(Persistence.BackendState.self, from: json)
    }

    private func completeSignIn(_ result: Result<Void, Error>) {
        let completion = signInCompletion
        signInCompletion = nil
        currentNonce = nil
        presentationAnchor = nil
        completion?(result)
    }

    private func randomNonceString(length: Int = 32) -> String? {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else { return nil }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}

extension FirebaseBackendService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        #if canImport(FirebaseAuth)
        guard let nonce = currentNonce,
              let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleIDCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            completeSignIn(.failure(FirebaseBackendError.invalidAppleCredential))
            return
        }

        let credential = OAuthProvider.appleCredential(withIDToken: idToken,
                                                       rawNonce: nonce,
                                                       fullName: appleIDCredential.fullName)
        Auth.auth().signIn(with: credential) { [weak self] _, error in
            guard let self else { return }
            if let error {
                Analytics.track("firebase_apple_sign_in_failed",
                                properties: ["error": "\(error)"])
                self.completeSignIn(.failure(error))
                return
            }

            Analytics.track("firebase_apple_sign_in_succeeded")
            self.pullProgressFromBackend { _ in
                self.scheduleProgressSync()
                self.completeSignIn(.success(()))
            }
        }
        #else
        completeSignIn(.failure(FirebaseBackendError.sdkUnavailable))
        #endif
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        Analytics.track("firebase_apple_sign_in_cancelled_or_failed",
                        properties: ["error": "\(error)"])
        completeSignIn(.failure(error))
    }
}

extension FirebaseBackendService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
