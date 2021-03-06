//
//  XMPPClient.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
//

#import "XMPPClientStreamManagement.h"
#import "XMPPConnection.h"
#import "XMPPRegistrationChallenge.h"
#import "XMPPStream.h"
#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>
#import <SASLKit/SASLKit.h>

@class XMPPClient;
@class XMPPStreamFeature;

extern NSString *_Nonnull const XMPPClientOptionsPreferedSASLMechanismsKey NS_SWIFT_NAME(ClientOptionsPreferedSASLMechanismsKey);
extern NSString *_Nonnull const XMPPClientOptionsResourceKey NS_SWIFT_NAME(ClientOptionsResourceKey);

extern NSString *_Nonnull const XMPPClientDidConnectNotification NS_SWIFT_NAME(ClientDidConnectNotification);
extern NSString *_Nonnull const XMPPClientDidDisconnectNotification NS_SWIFT_NAME(ClientDidDisconnectNotification);
extern NSString *_Nonnull const XMPPClientErrorKey NS_SWIFT_NAME(ClientErrorKey);
extern NSString *_Nonnull const XMPPClientResumedKey NS_SWIFT_NAME(ClientResumedKey);

typedef NS_ENUM(NSUInteger, XMPPClientState) {
    XMPPClientStateDisconnected,
    XMPPClientStateConnecting,
    XMPPClientStateEstablished,
    XMPPClientStateNegotiating,
    XMPPClientStateConnected,
    XMPPClientStateDisconnecting
} NS_SWIFT_NAME(ClientState);

NS_SWIFT_NAME(ClientDelegate)
@protocol XMPPClientDelegate <NSObject>
@optional
- (void)client:(nonnull XMPPClient *)client didChangeState:(XMPPClientState)state NS_SWIFT_NAME(client(_:didChangeState:));
- (void)clientDidConnect:(nonnull XMPPClient *)client resumedStream:(BOOL)resumedStream NS_SWIFT_NAME(clientDidConnect(_:resumedStream:));
- (void)clientDidDisconnect:(nonnull XMPPClient *)client NS_SWIFT_NAME(clientDidDisconnect(_:));
- (void)client:(nonnull XMPPClient *)client didFailWithError:(nonnull NSError *)error NS_SWIFT_NAME(client(_:didFail:));
- (void)client:(nonnull XMPPClient *)client didNegotiateFeature:(nonnull XMPPStreamFeature *)feature NS_SWIFT_NAME(client(_:didNegotiate:));
- (void)client:(nonnull XMPPClient *)client didFailToNegotiateFeature:(nonnull XMPPStreamFeature *)feature withError:(nonnull NSError *)error NS_SWIFT_NAME(client(_:didFailToNegotiate:error:));
- (void)client:(nonnull XMPPClient *)client didReceiveUnsupportedDocument:(nonnull PXDocument *)document NS_SWIFT_NAME(client(_:didReceiveUnsupportedDocument:));
- (void)client:(nonnull XMPPClient *)client didReceiveRegistrationChallenge:(nonnull id<XMPPRegistrationChallenge>)registrationChallenge NS_SWIFT_NAME(client(_:didReceiveRegistrationChallenge:));
- (void)client:(nonnull XMPPClient *)client didRegisterWithUsername:(nullable NSString *)username hostname:(nonnull NSString *)hostname NS_SWIFT_NAME(client(_:didRegisterWithUsername:hostname:));
@end

NS_SWIFT_NAME(Client)
@interface XMPPClient : NSObject <XMPPConnection>

#pragma mark Life-cycle
- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname
                                 options:(nullable NSDictionary *)options;

- (nonnull instancetype)initWithHostname:(nonnull NSString *)hostname
                                 options:(nullable NSDictionary *)options
                                  stream:(nullable XMPPStream *)stream;

#pragma mark Properties
@property (nonatomic, readonly) NSString *_Nonnull hostname;
@property (nonatomic, readonly) NSDictionary *_Nonnull options;
- (void)updateOptions:(nonnull NSDictionary *)options;

#pragma mark Registration
@property (nonatomic, readwrite) BOOL needsRegistration;

#pragma mark Bound JID
@property (nonatomic, readonly) XMPPJID *_Nullable JID;

#pragma mark Delegate & SASL Delegate
@property (nonatomic, weak) id<XMPPClientDelegate> _Nullable delegate;
@property (nonatomic, strong) dispatch_queue_t _Nullable delegateQueue;

@property (nonatomic, weak) id<SASLMechanismDelegate> _Nullable SASLDelegate;
@property (nonatomic, strong) dispatch_queue_t _Nullable SASLDelegateQueue;
@property (nonatomic, strong) id _Nullable SASLContext;

#pragma mark State
@property (nonatomic, readonly) XMPPClientState state;

#pragma mark Manage Client
- (void)connect;
- (void)disconnect;
- (void)suspend;

#pragma mark Acknowledgement
- (void)exchangeAcknowledgement;

#pragma mark Deprecated
@property (nonatomic, readonly) NSUInteger numberOfConnectionAttempts DEPRECATED_ATTRIBUTE;
@property (nonatomic, readonly) NSError *_Nullable recentError DEPRECATED_ATTRIBUTE;

@end
