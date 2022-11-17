//
//  VungleAdapterFullscreenAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk
import VungleSDK

/// Helium Vungle fullscreen ad adapter.
final class VungleAdapterFullscreenAd: VungleAdapterAd, PartnerAd, VungleRouterDelegate {
    var inlineView: UIView?
    
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        VungleRouter.requestAd(request: request, delegate: self, bannerSize: nil)
    }
    
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        showCompletion = completion
        VungleRouter.showFullscreenAd(viewController: viewController, request: request)
    }
    
    func vungleAdDidLoad() {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        
        loadCompletion = nil
    }
    
    func vungleAdDidFailToLoad(error: Error?) {
        if let error = error {
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        }
        
        loadCompletion = nil
    }
    
    func vungleAdWillShow(placementID: String?) {
        log(.custom("vungleWillShowAd for placement \(String(describing: placementID))"))
    }
    
    func vungleAdDidShow() {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        
        showCompletion = nil
    }
    
    func vungleAdDidFailToShow(error: Error?) {
        if let error = error {
            log(.showFailed(error))
            showCompletion?(.failure(error)) ?? log(.showResultIgnored)
        }
        
        showCompletion = nil
    }
    
    func vungleAdViewed() {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleAdDidClick() {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleAdWillLeaveApplication(placementID: String?) {
        log(.custom("vungleWillLeaveApplication for placement \(String(describing: placementID))"))
    }
    
    func vungleAdDidReward() {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func vungleAdWillClose(placementID: String?) {
        log(.custom("vungleWillCloseAd for placement \(String(describing: placementID))"))
    }
    
    func vungleAdDidClose() {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
