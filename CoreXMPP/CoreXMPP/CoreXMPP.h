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

// XMPP Error
#import <CoreXMPP/XMPPError.h>

// XMPP JID
#import <CoreXMPP/XMPPJID.h>

// Protocols
#import <CoreXMPP/XMPPStanzaHandler.h>

// XMPP Service Manager
#import <CoreXMPP/XMPPServiceManager.h>
#import <CoreXMPP/XMPPAccount.h>

// XMPP Dispatcher
#import <CoreXMPP/XMPPDispatcher.h>

// XMPP Module
#import <CoreXMPP/XMPPModule.h>
#import <CoreXMPP/XMPPPingModule.h>

// XMPP Client
#import <CoreXMPP/XMPPClient.h>

// XMPP Stream
#import <CoreXMPP/XMPPStream.h>
#import <CoreXMPP/XMPPWebsocketStream.h>

// XMPP Stream Feature
#import <CoreXMPP/XMPPStreamFeature.h>
#import <CoreXMPP/XMPPStreamFeatureSASL.h>
#import <CoreXMPP/XMPPStreamFeatureBind.h>
#import <CoreXMPP/XMPPStreamFeatureSession.h>

// SASL Mechanism
#import <CoreXMPP/SASLMechanism.h>
#import <CoreXMPP/SASLMechanismPLAIN.h>
