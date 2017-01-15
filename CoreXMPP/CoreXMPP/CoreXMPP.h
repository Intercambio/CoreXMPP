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

#import <CoreXMPP/XMPPAccountConnectivity.h>
#import <CoreXMPP/XMPPAccountManager.h>
#import <CoreXMPP/XMPPClient.h>
#import <CoreXMPP/XMPPClientFactory.h>
#import <CoreXMPP/XMPPClientStreamManagement.h>
#import <CoreXMPP/XMPPConnection.h>
#import <CoreXMPP/XMPPDataForm.h>
#import <CoreXMPP/XMPPDataFormField.h>
#import <CoreXMPP/XMPPDataFormOption.h>
#import <CoreXMPP/XMPPDispatcherImpl.h>
#import <CoreXMPP/XMPPDocumentHandler.h>
#import <CoreXMPP/XMPPError.h>
#import <CoreXMPP/XMPPJID.h>
#import <CoreXMPP/XMPPReconnectStrategy.h>
#import <CoreXMPP/XMPPRegistrationChallenge.h>
#import <CoreXMPP/XMPPStream.h>
#import <CoreXMPP/XMPPStreamFeature.h>
#import <CoreXMPP/XMPPWebsocketStream.h>
