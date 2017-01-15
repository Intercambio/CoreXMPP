//
//  XMPPAccountConnectivity.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 01.07.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

@import Foundation;
@import XMPPFoundation;

extern NSString *_Nonnull const XMPPAccountConnectivityDidChangeNotification NS_SWIFT_NAME(AccountConnectivityDidChange);

typedef NS_ENUM(NSUInteger, XMPPAccountConnectionState) {
    XMPPAccountConnectionStateDisconnected,
    XMPPAccountConnectionStateConnecting,
    XMPPAccountConnectionStateConnected,
    XMPPAccountConnectionStateDisconnecting
} NS_SWIFT_NAME(AccountConnectionState);

#define XMPPAccountConnectivityState XMPPAccountConnectionState
#define XMPPAccountConnectivityStateDisconnected XMPPAccountConnectionStateDisconnected
#define XMPPAccountConnectivityStateConnecting XMPPAccountConnectionStateConnecting
#define XMPPAccountConnectivityStateConnected XMPPAccountConnectionStateConnected
#define XMPPAccountConnectivityStateDisconnecting XMPPAccountConnectionStateDisconnecting

NS_SWIFT_NAME(AccountInfo)
@protocol XMPPAccountInfo <NSObject>
@property (nonatomic, readonly) XMPPAccountConnectionState connectionState;
@property (nonatomic, readonly) NSError *_Nullable recentError;
@property (nonatomic, readonly) NSDate *_Nullable nextConnectionAttempt;
@end

NS_SWIFT_NAME(AccountConnectivity)
@protocol XMPPAccountConnectivity <XMPPAccountInfo>
@property (nonatomic, readonly) XMPPJID *_Nonnull account;
@property (nonatomic, readonly) XMPPAccountConnectivityState state DEPRECATED_ATTRIBUTE;
- (void)connect;
@end
