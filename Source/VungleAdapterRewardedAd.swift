//
//  VungleAdapterRewardedAd.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation
import HeliumSdk

/// Helium Vungle adapter rewarded ad.
final class VungleAdapterRewardedAd: VungleAdapterAd, PartnerAd {
    var inlineView: UIView?
    
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        /// TODO
    }
    
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        /// TODO
    }
}
