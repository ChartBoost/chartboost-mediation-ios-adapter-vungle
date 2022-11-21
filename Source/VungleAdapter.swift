//
//  VungleAdapter.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// The Helium Vungle adapter.
final class VungleAdapter: PartnerAdapter {
    
    /// The version of the partner SDK.
    let partnerSDKVersion = VungleSDKVersion
    
    /// The version of the adapter.
    /// It should have 6 digits separated by periods, where the first digit is Helium SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `"<Helium major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>"`.
    let adapterVersion = "4.6.11.0.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "vungle"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Vungle"
        
    /// The completion handler to notify Helium of partner setup completion result.
    private var setUpCompletion: ((Error?) -> Void)?
    
    /// Ad storage managed by Helium SDK.
    let storage: PartnerAdapterStorage
    
    /// A router that forwards Vungle delegate calls to the corresponding `PartnerAd` instances.
    private var router: VungleAdapterRouter?
    
    /// The designated initializer for the adapter.
    /// Helium SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Helium SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
        self.storage = storage
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)
        
        guard let appId = configuration.credentials[.appIDKey] as? String, !appId.isEmpty else {
            let error = self.error(.missingSetUpParameter(key: .appIDKey))
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
        
        setUpCompletion = completion
        
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
        completion(nil)
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Helium SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Helium SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        switch request.format {
        case .interstitial, .rewarded:
            return VungleAdapterFullscreenAd(adapter: self, request: request, delegate: delegate)
        case .banner:
            return VungleAdapterBannerAd(adapter: self, request: request, delegate: delegate)
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
        let error = error(.setUpFailure, error: partnerError)
        log(.setUpFailed(error))
        setUpCompletion?(error)
        setUpCompletion = nil
    }
}

private extension String {
    /// Vungle app key credentials key
    static let appIDKey = "vungle_app_id"
}
