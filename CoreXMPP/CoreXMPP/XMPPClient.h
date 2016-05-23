//
//  XMPPClient.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>
#import <SASLKit/SASLKit.h>

#import "XMPPClientStreamManagement.h"
#import "XMPPConnection.h"
#import "XMPPStream.h"

extern NSString *const XMPPClientOptionsPreferedSASLMechanismsKey;
extern NSString *const XMPPClientOptionsResourceKey;

extern NSString *const XMPPClientDidConnectNotification;
extern NSString *const XMPPClientDidDisconnectNotification;
extern NSString *const XMPPClientErrorKey;
extern NSString *const XMPPClientResumedKey;

typedef NS_ENUM(NSUInteger, XMPPClientState) {
    XMPPClientStateDisconnected,
    XMPPClientStateConnecting,
    XMPPClientStateEstablished,
    XMPPClientStateNegotiating,
    XMPPClientStateConnected,
    XMPPClientStateDisconnecting
};

@class XMPPClient;
@class XMPPStreamFeature;

@protocol XMPPClientDelegate <NSObject>
@optional
- (void)client:(XMPPClient *)client didChangeState:(XMPPClientState)state;
- (void)clientDidConnect:(XMPPClient *)client resumedStream:(BOOL)resumedStream;
- (void)clientDidDisconnect:(XMPPClient *)client;
- (void)client:(XMPPClient *)client didFailWithError:(NSError *)error;
- (void)client:(XMPPClient *)client didNegotiateFeature:(XMPPStreamFeature *)feature;
- (void)client:(XMPPClient *)client didFailToNegotiateFeature:(XMPPStreamFeature *)feature withError:(NSError *)error;
- (void)client:(XMPPClient *)client didReceiveUnsupportedElement:(PXElement *)element;
@end

@interface XMPPClient : NSObject <XMPPConnection>

#pragma mark Life-cycle
- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options;

- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options
                          stream:(XMPPStream *)stream;

#pragma mark Properties
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readwrite) NSDictionary *options;

#pragma mark Bound JID
@property (nonatomic, readonly) XMPPJID *JID;

#pragma mark Delegate & SASL Delegate
@property (nonatomic, weak) id<XMPPClientDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;

@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;
@property (nonatomic, strong) dispatch_queue_t SASLDelegateQueue;
@property (nonatomic, strong) id SASLContext;

#pragma mark State
@property (nonatomic, readonly) XMPPClientState state;
@property (nonatomic, readonly) NSUInteger numberOfConnectionAttempts;
@property (nonatomic, readonly) NSError *recentError;

#pragma mark Manage Client
- (void)connect;
- (void)disconnect;
- (void)suspend;

#pragma mark Acknowledgement
- (void)exchangeAcknowledgement;

@end
