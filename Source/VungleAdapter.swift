// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleSDK

/// The Chartboost Mediation Vungle adapter.
final class VungleAdapter: PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = VungleSDKVersion
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.6.12.3.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "vungle"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Vungle"
        
    /// The completion handler to notify Chartboost Mediation of partner setup completion result.
    private var setUpCompletion: ((Error?) -> Void)?
    
    /// Ad storage managed by Chartboost Mediation SDK.
    let storage: PartnerAdapterStorage
    
    /// A router that forwards Vungle delegate calls to the corresponding `PartnerAd` instances.
    private var router: VungleAdapterRouter?
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
        self.storage = storage
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        // Get credentials, fail early if they are unavailable
        guard let appId = configuration.credentials[.appIDKey] as? String, !appId.isEmpty else {
            let error = self.error(.initializationFailureInvalidCredentials, description: "Missing \(String.appIDKey)")
            self.log(.setUpFailed(error))
            completion(error)
            return
        }
        
        // Vungle provides one single delegate for all ads.
        // VungleAdapterRouter implements these delegate protocols and forwards calls to the corresponding partner ad instances.
        let router = VungleAdapterRouter(adapter: self)
        self.router = router    // keep the router instance alive
        VungleSDK.shared().delegate = router
        VungleSDK.shared().sdkHBDelegate = router
        
        // Disable banner auto-refresh for all Vungle ads. Auto-refresh is handled by Chartboost Mediation.
        VungleSDK.shared().disableBannerRefresh()
        
        setUpCompletion = completion
        
        // Initialize Vungle
        do {
            try VungleSDK.shared().start(withAppId: appId)
        } catch {
            vungleSDKFailedToInitializeWithError(error)
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        log(.fetchBidderInfoStarted(request))
        if let token = VungleSDK.shared().currentSuperToken(forPlacementID: nil, forSize: 0) as String? {
            log(.fetchBidderInfoSucceeded(request))
            completion(["bid_token": token])
        } else {
            log(.fetchBidderInfoFailed(request, error: error(.prebidFailureUnknown, description: "VungleSDK currentSuperToken() returned nil")))
            completion(nil)
        }
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        // See https://support.vungle.com/hc/en-us/articles/360048572411
        if applies == true, status != .unknown {
            let gdprStatus: VungleConsentStatus = status == .granted ? .accepted : .denied
            VungleSDK.shared().update(gdprStatus, consentMessageVersion: "")
            log(.privacyUpdated(setting: "updateConsentStatus", value: gdprStatus.rawValue))
        }
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        // See https://support.vungle.com/hc/en-us/articles/360048572411
        let ccpaStatus: VungleCCPAStatus = hasGivenConsent ? .accepted : .denied
        VungleSDK.shared().update(ccpaStatus)
        log(.privacyUpdated(setting: "updateCCPAStatus", value: ccpaStatus.rawValue))
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // See https://support.vungle.com/hc/en-us/articles/360048572411
        VungleSDK.shared().updateCOPPAStatus(isChildDirected)
        log(.privacyUpdated(setting: "updateCOPPAStatus", value: isChildDirected))
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        guard let router = router else {
            throw error(.loadFailurePartnerNotInitialized, description: "router was nil on makeAd()")
        }
        // Vungle does not support multiple loads for the same placement (they will result in only one ad loaded).
        guard !storage.ads.contains(where: { $0.request.partnerPlacement == request.partnerPlacement }) else {
            log("Failed to load ad for already loading placement \(request.partnerPlacement)")
            throw error(.loadFailureLoadInProgress)
        }
        switch request.format {
        case .interstitial, .rewarded:
            return VungleAdapterFullscreenAd(adapter: self, router: router, request: request, delegate: delegate)
        case .banner:
            return VungleAdapterBannerAd(adapter: self, router: router, request: request, delegate: delegate)
        default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
    
    /// Maps a partner setup error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a setup completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapSetUpError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let errorCode = UInt32(exactly: (error as NSError).code) else {
            return nil
        }

        let vungleErrorCode = VungleSDKErrorCode(rawValue: errorCode)

        switch vungleErrorCode {
        case VungleSDKErrorNoAppID:
            return .initializationFailureInvalidCredentials
        case VungleSDKErrorInvalidiOSVersion:
            return .initializationFailureOSVersionNotSupported
        case VungleSDKErrorSDKAlreadyInitializing:
            return .initializationFailureAborted
        default:
            return nil
        }
    }
    
    /// Maps a partner load error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a load completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapLoadError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let errorCode = UInt32(exactly: (error as NSError).code) else {
            return nil
        }

        let vungleErrorCode = VungleSDKErrorCode(rawValue: errorCode)

        switch vungleErrorCode {
        case VungleSDKErrorInvalidAdTypeForFeedBasedAdExperience:
            return .loadFailureMismatchedAdFormat
        case VungleSDKErrorNoAppID:
            return .loadFailureInvalidCredentials
        case VungleSDKErrorFlexFeedContainerViewSizeError:
            return .loadFailureInvalidBannerSize
        case VungleSDKErrorFlexFeedContainerViewSizeRatioError:
            return .loadFailureInvalidBannerSize
        case InvalidPlacementsArray:
            return .loadFailureInvalidPartnerPlacement
        case VungleSDKErrorInvalidiOSVersion:
            return .loadFailureOSVersionNotSupported
        case VungleSDKErrorTopMostViewControllerMismatch:
            return .loadFailureViewControllerNotFound
        case VungleSDKErrorUnknownPlacementID:
            return .loadFailureInvalidPartnerPlacement
        case VungleSDKErrorSDKNotInitialized:
            return .loadFailurePartnerNotInitialized
        case VungleSDKErrorSleepingPlacement:
            return .loadFailureRateLimited
        case VungleSDKErrorNoAdsAvailable:
            return .loadFailureNoFill
        case VungleSDKErrorNotEnoughFileSystemSize:
            return .loadFailureOutOfStorage
        case VungleDiscSpaceProviderErrorNoFileSystemAttributes:
            return .loadFailureOutOfStorage
        case VungleSDKErrorUnknownBannerSize:
            return .loadFailureInvalidBannerSize
        case VungleSDKResetPlacementForDifferentAdSize:
            return .loadFailureMismatchedAdFormat
        case VungleSDKErrorInvalidAdTypeForNativeAdExperience:
            return .loadFailureMismatchedAdFormat
        case VungleSDKErrorMissingAdMarkupForPlacement:
            return .loadFailureInvalidAdMarkup
        case VungleSDKErrorInvalidAdMarkupForPlacement:
            return .loadFailureInvalidAdMarkup
        case VungleSDKErrorIllegalAdRequest:
            return .loadFailureInvalidAdRequest
        default:
            return nil
        }
    }
    
    /// Maps a partner show error to a Chartboost Mediation error code.
    /// Chartboost Mediation SDK calls this method when a show completion is called with a partner error.
    ///
    /// A default implementation is provided that returns `nil`.
    /// Only implement if the partner SDK provides its own list of error codes that can be mapped to Chartboost Mediation's.
    /// If some case cannot be mapped return `nil` to let Chartboost Mediation choose a default error code.
    func mapShowError(_ error: Error) -> ChartboostMediationError.Code? {
        guard let errorCode = UInt32(exactly: (error as NSError).code) else {
            return nil
        }

        let vungleErrorCode = VungleSDKErrorCode(rawValue: errorCode)
        
        switch vungleErrorCode {
        case VungleSDKErrorCannotPlayAdAlreadyPlaying:
            return .showFailureShowInProgress
        case VungleSDKErrorCannotPlayAdWaiting:
            return .showFailureUnknown
        case VungleSDKErrorFlexFeedContainerViewSizeError:
            return .showFailureInvalidBannerSize
        case VungleSDKErrorFlexFeedContainerViewSizeRatioError:
            return .showFailureInvalidBannerSize
        case InvalidPlacementsArray:
            return .showFailureInvalidPartnerPlacement
        case VungleSDKErrorTopMostViewControllerMismatch:
            return .showFailureViewControllerNotFound
        case VungleSDKErrorUnknownPlacementID:
            return .showFailureInvalidPartnerPlacement
        case VungleSDKErrorSDKNotInitialized:
            return .showFailureNotInitialized
        case VungleSDKErrorNoAdsAvailable:
            return .showFailureNoFill
        case VungleSDKErrorUnknownBannerSize:
            return .showFailureInvalidBannerSize
        default:
            return nil
        }
    }
}

// MARK: - VungleSDKDelegate

extension VungleAdapter {
    
    /// VungleSDK initialization success forwarded by router.
    func vungleSDKDidInitialize() {
        log(.setUpSucceded)
        setUpCompletion?(nil)
        setUpCompletion = nil
    }
    
    /// VungleSDK initialization failure forwarded by router.
    func vungleSDKFailedToInitializeWithError(_ partnerError: Error) {
        log(.setUpFailed(partnerError))
        setUpCompletion?(partnerError)
        setUpCompletion = nil
    }
}

private extension String {
    /// Vungle app key credentials key
    static let appIDKey = "vungle_app_id"
}
