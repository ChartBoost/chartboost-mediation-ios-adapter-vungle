// Copyright 2022-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import VungleAdsSDK

/// The Chartboost Mediation Vungle adapter.
final class VungleAdapter: PartnerAdapter {
    /// The adapter configuration type that contains adapter and partner info.
    /// It may also be used to expose custom partner SDK options to the publisher.
    var configuration: PartnerAdapterConfiguration.Type { VungleAdapterConfiguration.self }

    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)
        
        // Get credentials, fail early if they are unavailable
        guard let appID = configuration.credentials[.appIDKey] as? String, !appID.isEmpty else {
            let error = self.error(.initializationFailureInvalidCredentials, description: "Missing \(String.appIDKey)")
            self.log(.setUpFailed(error))
            completion(.failure(error))
            return
        }
        
        // Apply initial consents
        setConsents(configuration.consents, modifiedKeys: Set(configuration.consents.keys))
        // Apply saved COPPA setting before init, as suggested in documentation
        // https://support.vungle.com/hc/en-us/articles/360048572411#recommendations-for-using-vungle-s-coppa-compliance-tools-0-6
        setIsUserUnderage(configuration.isUserUnderage)

        // Initialize Vungle
        VungleAds.initWithAppId(appID) { [weak self] initError in
            guard let self = self else { return }
            if VungleAds.isInitialized() {
                self.log(.setUpSucceded)
                completion(.success([:]))
            } else {
                let error = initError ?? self.error(.initializationFailureUnknown)
                self.log(.setUpFailed(error))
                completion(.failure(error))
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String : String], Error>) -> Void) {
        log(.fetchBidderInfoStarted(request))
        let bidToken = VungleAds.getBiddingToken()
        log(.fetchBidderInfoSucceeded(request))
        completion(.success(["bid_token": bidToken]))
    }
    
    /// Indicates that the user consent has changed.
    /// - parameter consents: The new consents value, including both modified and unmodified consents.
    /// - parameter modifiedKeys: A set containing all the keys that changed.
    func setConsents(_ consents: [ConsentKey: ConsentValue], modifiedKeys: Set<ConsentKey>) {
        // GDPR
        // See https://support.vungle.com/hc/en-us/articles/360048572411
        // Ignore if the consent status has been directly set by publisher via the configuration class.
        if !VungleAdapterConfiguration.isGDPRStatusOverriden
            && (modifiedKeys.contains(configuration.partnerID) || modifiedKeys.contains(ConsentKeys.gdprConsentGiven))
        {
            let consent = consents[configuration.partnerID] ?? consents[ConsentKeys.gdprConsentGiven]
            switch consent {
            case ConsentValues.granted:
                VunglePrivacySettings.setGDPRStatus(true)
                log(.privacyUpdated(setting: "GDPR Status", value: true))
            case ConsentValues.denied:
                VunglePrivacySettings.setGDPRStatus(false)
                log(.privacyUpdated(setting: "GDPR Status", value: false))
            default:
                break   // do nothing
            }
        }

        // CCPA
        // See https://support.vungle.com/hc/en-us/articles/360048572411
        // Ignore if the consent status has been directly set by publisher via the configuration class.
        if !VungleAdapterConfiguration.isCCPAStatusOverriden && modifiedKeys.contains(ConsentKeys.ccpaOptIn) {
            switch consents[ConsentKeys.ccpaOptIn] {
            case ConsentValues.granted:
                VunglePrivacySettings.setCCPAStatus(true)
                log(.privacyUpdated(setting: "CCPA Status", value: true))
            case ConsentValues.denied:
                VunglePrivacySettings.setCCPAStatus(false)
                log(.privacyUpdated(setting: "CCPA Status", value: false))
            default:
                break   // do nothing
            }
        }
    }

    /// Indicates that the user is underage signal has changed.
    /// - parameter isUserUnderage: `true` if the user is underage as determined by the publisher, `false` otherwise.
    func setIsUserUnderage(_ isUserUnderage: Bool) {
        // See https://support.vungle.com/hc/en-us/articles/360048572411
        VunglePrivacySettings.setCOPPAStatus(isUserUnderage)
        log(.privacyUpdated(setting: "COPPA Status", value: isUserUnderage))
    }

    /// Creates a new banner ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeBannerAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerBannerAd {
        // This partner supports multiple loads for the same partner placement.
        VungleAdapterBannerAd(adapter: self, request: request, delegate: delegate)
    }

    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeFullscreenAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerFullscreenAd {
        // This partner supports multiple loads for the same partner placement.
        switch request.format {
        case PartnerAdFormats.interstitial:
            return VungleAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
        case PartnerAdFormats.rewarded, PartnerAdFormats.rewardedInterstitial:
            return VungleAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
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

        switch errorCode {
        case 2: // The app ID fails SDK validation; for example, an empty string.
            return .initializationFailureInvalidCredentials
        case 3: // The SDK was already initializing when another call is made.
            return .initializationSkipped
        case 4: // The SDK was already successfully initialized when another call is made.
            return .initializationSkipped
        case 6: // This error is returned if any public API is called before initialization when initialization is required.
            return .initializationFailureUnknown
        case 101: // Server error getting a response from an API call. Message contains the URL.
            return .initializationFailureServerError
        case 102: // Server didn't send any data in the API call. Message contains the URL.
            return .initializationFailureServerError
        case 103: // SDK failed to decode the response into the expected object. Message contains the URL.
            return .initializationFailureInvalidAppConfig
        case 104: // The status code from an API call (to endpoints such as config, ads, etc.) returned something outside of the 2xx range. Message contains the URL.
            return .initializationFailureNetworkingError
        case 105: // The template URL is nil, empty, or invalid. Message contains the URL.
            return .initializationFailureNetworkingError
        case 106: // Failed to create a URL object to the targeted endpoint. Message contains the URL.
            return .initializationFailureNetworkingError
        case 109: // Failed to unarchive the template file.
            return .initializationFailureUnknown
        case 111: // The URL from the cacheable replacements is invalid. Message contains the URL.
            return .initializationFailureNetworkingError
        case 112: // The asset failed to download or Apple didn't return the temporary location to us. Message contains the URL.
            return .initializationFailureNetworkingError
        case 113: // Apple returned an unexpected response object or failed to load the downloaded data.
            return .initializationFailureNetworkingError
        case 122: // The ads endpoint doesn't exist in the config response body.
            return .initializationFailureNetworkingError
        case 123: // The RI (Incentivized Reporting) endpoint is missing from the config response body. This endpoint is used in conjunction with rewarded (incentivized) ads.
            return .initializationFailureInvalidAppConfig
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

        switch errorCode {
        case 6: // This error is returned if any public API is called before initialization when initialization is required.
            return .loadFailureUnknown
        case 7: // There was an error in retrieving webView user agent.
            return .loadFailureUnknown
        case 101: // Server error getting a response from an API call. Message contains the URL.
            return .loadFailureServerError
        case 102: // Server didn't send any data in the API call. Message contains the URL.
            return .loadFailureServerError
        case 103: // SDK failed to decode the response into the expected object. Message contains the URL.
            return .loadFailureInvalidAdMarkup
        case 104: // The status code from an API call (to endpoints such as config, ads, etc.) returned something outside of the 2xx range. Message contains the URL.
            return .loadFailureNetworkingError
        case 105: // The template URL is nil, empty, or invalid. Message contains the URL.
            return .loadFailureNetworkingError
        case 106: // Failed to create a URL object to the targeted endpoint. Message contains the URL.
            return .loadFailureNetworkingError
        case 109: // Failed to unarchive the template file.
            return .loadFailureUnknown
        case 111: // The URL from the cacheable replacements is invalid. Message contains the URL.
            return .loadFailureNetworkingError
        case 112: // The asset failed to download or Apple didn't return the temporary location to us. Message contains the URL.
            return .loadFailureNetworkingError
        case 113: // Apple returned an unexpected response object or failed to load the downloaded data.
            return .initializationFailureNetworkingError
        case 114: // Failed to save the downloaded asset to disk.
            return .loadFailureOutOfStorage
        case 115: // The index.html doesn't exist or there's a problem with the event ID to lookup the HTML file.
            return .loadFailureInvalidPartnerPlacement
        case 117: // The status code from the asset download didn't return 200. Message contains the URL.
            return .loadFailureNetworkingError
        case 122: // The ads endpoint doesn't exist in the config response body.
            return .loadFailureNetworkingError
        case 126: // During ad loading, an asset failed to download due to insufficient space available on the user’s device.
            return .loadFailureOutOfStorage
        case 127: // During ad loading, an asset failed to download because the space required to download and cache the asset exceeded the maximum space available.
            return .loadFailureOutOfStorage
        case 130: // MRAID JavaScript file download failed.
            return .loadFailureNetworkingError
        case 131: // Failed to save MRAID JavaScript files to disk.
                  // In Vungle iOS SDK v.7.0.0, the SDK will attempt to download and write these files to disk during the next initialization.
                  // In iOS SDK v.7.0.1, the SDK will attempt to download and write these files to disk on the next ad load request.
            return .loadFailureOutOfStorage
        case 200: // The event ID in the ads response is invalid or the local URL can't be created from it.
            return .loadFailureInvalidAdMarkup
        // For 202 - 204, the closest error type might be "loadFailureLoadInProgress" but that might also be confusing.
        // Maybe loadFailureUnknown would be better for 202 and 204?
        case 202: // The load() API was called when the ad was already marked as completed.
            return .loadFailureLoadInProgress
        case 203: // The load() API was called for a currently loading ad object.
            return .loadFailureLoadInProgress
        case 204: // The load() API was called when the ad object had already loaded successfully.
            return .loadFailureLoadInProgress
        case 205: // The load() API, playAd()/ API, or canPlayAd() API was called for an already playing ad object.
            return .loadFailureShowInProgress
        case 206: // The load() API was called on a failed ad object.
            return .loadFailureUnknown
        case 208: // The bid payload doesn't contain a valid ads response.
            return .loadFailureInvalidAdMarkup
        case 209: // Mediation has participated in an auction and provided the SDK with a bid payload that it cannot parse into a JSON ad object.
            return .loadFailureInvalidAdMarkup
        case 212: // The platform returned a sleeping response. Based on the code included in the response, wait before requesting another ad.
            return .loadFailureRateLimited
        case 213: // Mediation has participated in an auction and provided the SDK with a bid payload from which it cannot decode the ad unit.
            return .loadFailureInvalidAdMarkup
        case 214: // Failed to unzip the ad from the bid payload.
            return .loadFailureInvalidBidResponse
        case 215: // Ad metadata not found in response.
            return .loadFailureUnknown  // Would .loadFailureMismatchedAdParams be a better choice here?
        case 216: // The ad response uses a template type that is not valid for the instance that will present the ad.
            return .loadFailureMismatchedAdFormat
        case 217: // Timeout error for /ads request.
            return .loadFailureTimeout
        case 218: // MRAID JS file not available
            return .loadFailureUnknown
        case 219: // MRAID JavaScript copy to ad directory failed.
            return .loadFailureOutOfStorage
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

        switch errorCode {
        case 6: // This error is returned if any public API is called before initialization when initialization is required.
            return .showFailureUnknown
        case 7: // There was an error in retrieving webView user agent.
            return .showFailureUnknown
        case 109: // Failed to unarchive the template file.
            return .showFailureUnknown
        case 200: // The event ID in the ads response is invalid or the local URL can't be created from it.
            return .showFailureMediaBroken
        case 205: // The load() API, playAd()/ API, or canPlayAd() API was called for an already playing ad object.
            return .showFailureShowInProgress
        case 210: // The load() API was not called before the playAd() API, or the ad didn't complete loading.
            return .showFailureAdNotReady
        case 218: // MRAID JS file not available
            return .showFailureUnknown
        case 302: // The user’s App Tracking Transparency (ATT) selection has been updated.
                  // Previously cached ads are no longer valid. Please request a new ad.
            return .showFailureAdExpired
        case 304: // The ads response expired. This error occurs immediately when the timer detects that it has expired.
            return .showFailureAdExpired
        case 305: // Failed to load the index HTML.
            return .showFailureMediaBroken
        case 307: // The ads response expired. This error occurs if you call play on an expired ad object.
            return .showFailureAdExpired
        case 400: // You have attempted to call play on a full screen ad object with another already playing.
            return .showFailureShowInProgress
        case 500: // A different size container was supplied for the banner.
            return .showFailureInvalidBannerSize
        case 600: // Critical native ad assets are missing.
            return .showFailureMediaBroken
        default:
            return nil
        }
    }
}

private extension String {
    /// Vungle app key credentials key
    static let appIDKey = "vungle_app_id"
}
