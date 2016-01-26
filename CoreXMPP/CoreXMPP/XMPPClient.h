//
//  XMPPClient.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

#import "XMPPDispatcher.h"
#import "XMPPClientStreamManagement.h"

extern NSString *const XMPPClientOptionsStreamKey;
extern NSString *const XMPPClientOptionsPreferedSASLMechanismsKey;
extern NSString *const XMPPClientOptionsResourceKey;

typedef NS_ENUM(NSUInteger, XMPPClientState) {
    XMPPClientStateDisconnected,
    XMPPClientStateConnecting,
    XMPPClientStateConnected,
    XMPPClientStateNegotiating,
    XMPPClientStateEstablished,
    XMPPClientStateDisconnecting
};

@class XMPPClient;
@class XMPPStreamFeature;
@protocol SASLMechanismDelegate;

@protocol XMPPClientDelegate <NSObject>
@optional
- (void)clientDidConnect:(XMPPClient *)client;
- (void)clientDidDisconnect:(XMPPClient *)client;
- (void)client:(XMPPClient *)client didNegotiateFeature:(XMPPStreamFeature *)feature;
- (void)client:(XMPPClient *)client didFailToNegotiateFeature:(XMPPStreamFeature *)feature withError:(NSError *)error;
- (void)client:(XMPPClient *)client didFailWithError:(NSError *)error;
- (void)client:(XMPPClient *)client didReceiveUnsupportedElement:(PXElement *)element;
@end

@interface XMPPClient : NSObject <XMPPConnection>

#pragma mark Life-cycle
- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPClientDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;

@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;
@property (nonatomic, strong) dispatch_queue_t SASLDelegateQueue;
@property (nonatomic, strong) id SASLContext;

#pragma mark Properties
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Stream Features
@property (nonatomic, readonly) NSArray *negotiatedFeatures;

#pragma mark Stream Management
@property (nonatomic, readonly) id<XMPPClientStreamManagement> streamManagement;

#pragma mark State
@property (nonatomic, readonly) XMPPClientState state;

#pragma mark Manage Client
- (void)connect;
- (void)disconnect;

@end
