//
//  CoreXMPP.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 30.10.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

@import Foundation;

//! Project version number for CoreXMPP.
FOUNDATION_EXPORT double CoreXMPPVersionNumber;

//! Project version string for CoreXMPP.
FOUNDATION_EXPORT const unsigned char CoreXMPPVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <CoreXMPP/PublicHeader.h>

// XMPP Stream
#import <CoreXMPP/XMPPStream.h>
#import <CoreXMPP/XMPPWebsocketStream.h>

// XMPP Stream Feature
#import <CoreXMPP/XMPPStreamFeature.h>
#import <CoreXMPP/XMPPStreamFeatureSASL.h>

// SASL Mechanism
#import <CoreXMPP/SASLMechanism.h>
#import <CoreXMPP/SASLMechanismPLAIN.h>
