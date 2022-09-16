//
//  VungleAdapterConfiguration.swift
//  ChartboostHeliumAdapterVungle
//
//  Created by Vu Chau on 9/16/22.
//

import Foundation

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
public class VungleAdapterConfiguration {
    /// Flag that can optionally be set to enable Vungle's mute setting.
    /// Disabled by default.
    public static var muted: Bool = false {
        didSet {
            guard let sdk = VungleAdapter.sdk else {
                print("Unable to set Vungle's mute setting because the SDK is nil.")
                return
            }
            
            sdk.setMuted(muted)
            print("Vungle's ads will be \(muted ? "muted" : "unmuted").")
        }
    }
}
