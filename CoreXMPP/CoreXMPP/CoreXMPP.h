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
#import <CoreXMPP/XMPPConnection.h>
#import <CoreXMPP/XMPPStanzaHandler.h>

// XMPP Service Manager
#import <CoreXMPP/XMPPAccount.h>
#import <CoreXMPP/XMPPKeyChainItemAttributes.h>
#import <CoreXMPP/XMPPKeyChainService.h>
#import <CoreXMPP/XMPPServiceManager.h>

// XMPP Dispatcher
#import <CoreXMPP/XMPPDispatcher.h>

// XMPP Client
#import <CoreXMPP/XMPPClient.h>
#import <CoreXMPP/XMPPClientStreamManagement.h>

// XMPP Stream
#import <CoreXMPP/XMPPStream.h>
#import <CoreXMPP/XMPPWebsocketStream.h>

// XMPP Stream Feature
#import <CoreXMPP/XMPPStreamFeature.h>
#import <CoreXMPP/XMPPStreamFeatureBind.h>
#import <CoreXMPP/XMPPStreamFeatureSASL.h>
#import <CoreXMPP/XMPPStreamFeatureSession.h>
#import <CoreXMPP/XMPPStreamFeatureStreamManagement.h>

// SASL Mechanism
#import <CoreXMPP/SASLMechanism.h>
#import <CoreXMPP/SASLMechanismPLAIN.h>
