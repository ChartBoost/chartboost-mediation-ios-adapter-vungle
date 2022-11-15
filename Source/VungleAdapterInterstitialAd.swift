//
//  VungleAdapterInterstitialAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Helium Vungle adapter interstitial ad.
final class VungleAdapterInterstitialAd: VungleAdapterAd, PartnerAd, VungleSDKHBDelegate, VungleSDKDelegate {
    var inlineView: UIView?
    
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        loadCompletion = completion
        
        VungleAdapter.sdk.delegate = self
        VungleAdapter.sdk.sdkHBDelegate = self
        
        if (VungleAdapter.sdk.isAdCached(forPlacementID: request.partnerPlacement, adMarkup: request.adm) == true) {
            log(.loadSucceeded)
            loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
            loadCompletion = nil
            
            return
        }
        
        do {
            try VungleAdapter.sdk.loadPlacement(withID: request.partnerPlacement, adMarkup: request.adm)
        } catch {
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
        }
    }
    
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        showCompletion = completion
        
        /// Vungle's ad playback must be done on the main thread.
        DispatchQueue.main.async {
            do {
                try VungleAdapter.sdk.playAd(viewController, options: [:], placementID: self.request.partnerPlacement)
            } catch {
                self.log(.showFailed(error))
                self.showCompletion?(.failure(error)) ?? self.log(.showResultIgnored)
                self.showCompletion = nil
            }
        }
    }
    
    // MARK: - VungleSDKDelegate
    
    internal func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, error: Error?) {
        /// Banners are shown upon load
        //        if (request.format == .banner) {
        //            do {
        //                try VungleAdapter.sdk.addAdView(to: self.bannerView, withOptions: [:], placementID: request.partnerPlacement)
        //
        //                loadCompletion?(.success([:]))
        //            } catch {
        //                loadCompletion?(.failure(error))
        //            }
        //        } else {
        //            loadCompletion?(isAdPlayable
        //                            ? .success([:])
        //                            : .failure(error(.loadFailure))) ?? log(.loadResultIgnored)
        //        }
        
        loadCompletion?(isAdPlayable
                        ? .success([:])
                        : .failure(error ?? self.error(.loadFailure))) ?? log(.loadResultIgnored)
        
        loadCompletion = nil
    }
    
    internal func vungleWillShowAd(forPlacementID placementID: String?) {
        log(.custom("vungleWillShowAdForPlacementID \(String(describing: placementID))"))
    }
    
    internal func vungleDidShowAd(forPlacementID placementID: String?) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    internal func vungleAdViewed(forPlacement placementID: String) {
        log(.didTrackImpression)
                
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func vungleWillCloseAd(forPlacementID placementID: String) {
        log("vungleWillCloseAdForPlacementID \(placementID)")
    }
    
    internal func vungleDidCloseAd(forPlacementID placementID: String) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    internal func vungleTrackClick(forPlacementID placementID: String?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func vungleWillLeaveApplication(forPlacementID placementID: String?) {
        log("vungleWillLeaveApplicationForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleRewardUser(forPlacementID placementID: String?) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    // MARK: - VungleSDKHBDelegate
    
    internal func vungleAdPlayabilityUpdate(_ isAdPlayable: Bool, placementID: String?, adMarkup: String?, error: Error?) {
        /// Banners are shown upon load
        //        if (request.format == .banner) {
        //            do {
        //                try VungleAdapter.sdk?.addAdView(to: self.bannerView, withOptions: [:], placementID: request.partnerPlacement)
        //
        //                loadCompletion?(.success(partnerAd))
        //            } catch {
        //                loadCompletion?(.failure(error))
        //            }
        //        } else {
        //            loadCompletion?(isAdPlayable ? .success(partnerAd) : .failure(error)) ?? log(.loadResultIgnored)
        //        }
        
        loadCompletion?(isAdPlayable
                        ? .success([:])
                        : .failure(error ?? self.error(.loadFailure))) ?? log(.loadResultIgnored)
        
        loadCompletion = nil
    }
    
    internal func vungleWillShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleWillShowAdForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleDidShowAd(forPlacementID placementID: String?, adMarkup: String?) {
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    internal func vungleAdViewed(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleAdViewedForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleWillCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleWillCloseAdForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleDidCloseAd(forPlacementID placementID: String?, adMarkup: String?) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    internal func vungleTrackClick(forPlacementID placementID: String?, adMarkup: String?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func vungleWillLeaveApplication(forPlacementID placementID: String?, adMarkup: String?) {
        log("vungleWillLeaveApplicationForPlacementID \(String(describing: placementID))")
    }
    
    internal func vungleRewardUser(forPlacementID placementID: String?, adMarkup: String?) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    internal func invalidateObjects(forPlacementID placementID: String?) {
        log("invalidateObjectsForPlacementID \(String(describing: placementID))")
    }
}
