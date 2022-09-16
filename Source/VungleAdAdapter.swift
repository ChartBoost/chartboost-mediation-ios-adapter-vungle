//
//  VungleAdAdapter.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK
import UIKit

final class VungleAdAdapter: NSObject, PartnerLogger, PartnerErrorFactory, VungleSDKDelegate, VungleSDKHBDelegate {
    /// The current adapter instance
    let adapter: PartnerAdapter
    
    /// The current PartnerAdLoadRequest containing data relevant to the curent ad request
    let request: PartnerAdLoadRequest
    
    /// A PartnerAd object with a placeholder (nil) ad object.
    lazy var partnerAd = PartnerAd(ad: nil, details: [:], request: request)
    
    /// The partner ad delegate to send ad life-cycle events to.
    weak var partnerAdDelegate: PartnerAdDelegate?
    
    /// A UIView to hold the Vungle banner ad.
    lazy var bannerView = UIView(frame: getFrameSize(size: getVungleBannerSize(size: self.request.size)))
    
    /// The completion handler to notify Helium of ad load completion result.
    var loadCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    /// The completion handler to notify Helium of ad show completion result.
    var showCompletion: ((Result<PartnerAd, Error>) -> Void)?
    
    /// Create a new instance of the adapter.
    /// - Parameters:
    ///   - adapter: The current adapter instance
    ///   - request: The current AdLoadRequest containing data relevant to the curent ad request
    ///   - partnerAdDelegate: The partner ad delegate to notify Helium of ad lifecycle events.
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, partnerAdDelegate: PartnerAdDelegate) {
        self.adapter = adapter
        self.request = request
        self.partnerAdDelegate = partnerAdDelegate
        
        super.init()
    }
    
    /// Attempt to load an ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad load completion result.
    func load(viewController: UIViewController?, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        loadCompletion = { [weak self] result in
            if let self = self {
                do {
                    self.log(.loadSucceeded(try result.get()))
                    try VungleAdapter.sdk?.addAdView(to: <#T##UIView#>, withOptions: [:], placementID: self.request.partnerPlacement, adMarkup: self.request.adm)
                } catch {
                    self.log(.loadFailed(self.request, error: error))
                }
            }
            
            self?.loadCompletion = nil
            completion(result)
        }
        
        VungleAdapter.sdk?.delegate = self
        VungleAdapter.sdk?.sdkHBDelegate = self
        
        switch request.format {
        case .banner:
            loadBannerAd(viewController: viewController, request: request)
        case .interstitial, .rewarded:
            loadFullscreenAd(request: request)
        }
    }
    
    /// Attempt to show the currently loaded ad.
    /// - Parameters:
    ///   - viewController: The ViewController for ad presentation purposes.
    ///   - completion: The completion handler to notify Helium of ad show completion result.
    func show(viewController: UIViewController, completion: @escaping (Result<PartnerAd, Error>) -> Void) {
        showCompletion = { [weak self] result in
            if let self = self {
                do {
                    self.log(.showSucceeded(try result.get()))
                } catch {
                    self.log(.showFailed(self.partnerAd, error: error))
                }
            }
            
            self?.showCompletion = nil
            completion(result)
        }
        
        switch request.format {
        case .banner:
            /// Banner does not have a separate show mechanism
            log(.showSucceeded(partnerAd))
            completion(.success(partnerAd))
        case .interstitial, .rewarded:
            showFullscreenAd(viewController: viewController)
        }
    }
    
    // MARK: - VungleSDKDelegate
    
    func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?) {
        /// Banners are shown upon load
        if (request.format == .banner) {
            do {
                try VungleAdapter.sdk?.addAdView(to: self.bannerView, withOptions: [:], placementID: request.partnerPlacement)
                
                loadCompletion?(.success(partnerAd))
            } catch {
                loadCompletion?(.failure(error))
            }
        } else {
            loadCompletion?(isAdPlayable
                            ? .success(partnerAd)
                            : .failure(error(.loadFailure(request)))) ?? log(.loadResultIgnored)
        }
        
        loadCompletion = nil
    }
    
    private func vungleWillShowAdForPlacementID(placementID: String) {
        log("vungleWillShowAdForPlacementID \(placementID)")
    }
    
    private func vungleDidShowAdForPlacementID(placementID: String) {
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    private func vungleAdViewedForPlacement(placementID: String) {
        log(.didTrackImpression(partnerAd))
        partnerAdDelegate?.didTrackImpression(partnerAd) ?? log(.delegateUnavailable)
    }
    
    private func vungleWillCloseAdForPlacementID(placementID: String) {
        log("vungleWillCloseAdForPlacementID \(placementID)")
    }
    
    private func vungleDidCloseAdForPlacementID(placementID: String) {
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil) ?? log(.delegateUnavailable)
    }
    
    private func vungleTrackClickForPlacementID(placementID: String) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }
    
    private func vungleWillLeaveApplicationForPlacementID(placementID: String) {
        log("vungleWillLeaveApplicationForPlacementID \(placementID)")
    }
    
    private func vungleRewardUserForPlacementID(placementID: String) {
        let reward = Reward(amount: 1, label: "")
        
        log(.didReward(partnerAd, reward: reward))
        partnerAdDelegate?.didReward(partnerAd, reward: reward) ?? log(.delegateUnavailable)
    }
    
    private func vungleAdPlayabilityUpdate(isAdPlayable: Bool, placementID: String, adMarkup: String, error: NSError) {
        /// Banners are shown upon load
        if (request.format == .banner) {
            do {
                try VungleAdapter.sdk?.addAdView(to: self.bannerView, withOptions: [:], placementID: request.partnerPlacement)
                
                loadCompletion?(.success(partnerAd))
            } catch {
                loadCompletion?(.failure(error))
            }
        } else {
            loadCompletion?(isAdPlayable ? .success(partnerAd) : .failure(error)) ?? log(.loadResultIgnored)
        }
        
        loadCompletion = nil
    }
    
    private func vungleWillShowAdForPlacementID(placementID: String, adMarkup: String) {
        log("vungleWillShowAdForPlacementID \(placementID)")
    }
    
    private func vungleDidShowAdForPlacementID(placementID: String, adMarkup: String) {
        showCompletion?(.success(partnerAd)) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    private func vungleAdViewedForPlacementID(placementID: String, adMarkup: String) {
        log("vungleAdViewedForPlacementID \(placementID)")
    }
    
    private func vungleWillCloseAdForPlacementID(placementID: String, adMarkup: String) {
        log("vungleWillCloseAdForPlacementID \(placementID)")
    }
    
    private func vungleDidCloseAdForPlacementID(placementID: String, adMarkup: String) {
        log(.didDismiss(partnerAd, error: nil))
        partnerAdDelegate?.didDismiss(partnerAd, error: nil) ?? log(.delegateUnavailable)
    }
    
    private func vungleTrackClickForPlacementID(placementID: String, adMarkup: String) {
        log(.didClick(partnerAd, error: nil))
        partnerAdDelegate?.didClick(partnerAd) ?? log(.delegateUnavailable)
    }
    
    private func vungleWillLeaveApplicationForPlacementID(placementID: String, adMarkup: String) {
        log("vungleWillLeaveApplicationForPlacementID \(placementID)")
    }
    
    private func vungleRewardUserForPlacementID(placementID: String, adMarkup: String) {
        let reward = Reward(amount: 1, label: "")
        
        log(.didReward(partnerAd, reward: reward))
        partnerAdDelegate?.didReward(partnerAd, reward: reward) ?? log(.delegateUnavailable)
    }
    
    private func invalidateObjectsForPlacementID(placementID: String) {
        log("invalidateObjectsForPlacementID \(placementID)")
    }
}
