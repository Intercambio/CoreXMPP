//
//  XMPPClient.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 06.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

extern NSString *const XMPPClientStreamErrorDomain;

typedef NS_ENUM(NSInteger, XMPPClientStreamErrorCode) {
    XMPPClientStreamErrorCodeBadFormat,
    XMPPClientStreamErrorCodeBadNamespacePrefix,
    XMPPClientStreamErrorCodeConflict,
    XMPPClientStreamErrorCodeConnectionTimeout,
    XMPPClientStreamErrorCodeHostGone,
    XMPPClientStreamErrorCodeHostUnknown,
    XMPPClientStreamErrorCodeImproperAddressing,
    XMPPClientStreamErrorCodeInternalServerError,
    XMPPClientStreamErrorCodeInvalidFrom,
    XMPPClientStreamErrorCodeInvalidNamespace,
    XMPPClientStreamErrorCodeInvalidXML,
    XMPPClientStreamErrorCodeNotAuthorized,
    XMPPClientStreamErrorCodeNotWellFormed,
    XMPPClientStreamErrorCodePolicyViolation,
    XMPPClientStreamErrorCodeRemoteConnectionFailed,
    XMPPClientStreamErrorCodeReset,
    XMPPClientStreamErrorCodeResourceConstraint,
    XMPPClientStreamErrorCodeRestrictedXML,
    XMPPClientStreamErrorCodeSeeOtherHost,
    XMPPClientStreamErrorCodeSystemShutdown,
    XMPPClientStreamErrorCodeUndefinedCondition,
    XMPPClientStreamErrorCodeUnsupportedEncoding,
    XMPPClientStreamErrorCodeUnsupportedFeature,
    XMPPClientStreamErrorCodeUnsupportedStanzaType,
    XMPPClientStreamErrorCodeUnsupportedVersion
};

extern NSString *const XMPPClientStreamErrorXMLDocumentKey;

extern NSString *const XMPPClientOptionsStreamKey;
extern NSString *const XMPPClientOptionsPreferedSASLMechanismsKey;

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
- (void)client:(XMPPClient *)client didReceiveStanza:(PXElement *)stanza;
- (void)client:(XMPPClient *)client didReceiveUnsupportedElement:(PXElement *)element;
@end

@interface XMPPClient : NSObject

#pragma mark Registered Stream Features
+ (NSDictionary *)registeredStreamFeatures;
+ (void)registerStreamFeatureClass:(Class)featureClass forStreamFeatureQName:(PXQName *)streamFeatureQName;

#pragma mark Stream Errors
+ (NSError *)streamErrorFromElement:(PXElement *)element;

#pragma mark Life-cycle
- (instancetype)initWithHostname:(NSString *)hostname
                         options:(NSDictionary *)options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPClientDelegate> delegate;
@property (nonatomic, weak) id<SASLMechanismDelegate> SASLDelegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;

#pragma mark Properties
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Stream Features
@property (nonatomic, readonly) NSArray *negotiatedFeatures;

#pragma mark State
@property (nonatomic, readonly) XMPPClientState state;

#pragma mark Manage Client
- (void)connect;
- (void)disconnect;

#pragma mark Sending Stanza
- (void)sendStanza:(PXElement *)stanza;

@end
