//
//  XMPPAccountConnectivity.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 01.07.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPJID.h"
#import <Foundation/Foundation.h>

extern NSString *_Nonnull const XMPPAccountConnectivityDidChangeNotification NS_SWIFT_NAME(AccountConnectivityDidChange);

typedef NS_ENUM(NSUInteger, XMPPAccountConnectivityState) {
    XMPPAccountConnectivityStateDisconnected,
    XMPPAccountConnectivityStateConnecting,
    XMPPAccountConnectivityStateConnected,
    XMPPAccountConnectivityStateDisconnecting
} NS_SWIFT_NAME(AccountConnectivityState);

NS_SWIFT_NAME(AccountConnectivity)
@protocol XMPPAccountConnectivity <NSObject>
@property (nonatomic, readonly) XMPPJID *_Nonnull account;
@property (nonatomic, readonly) XMPPAccountConnectivityState state;
@property (nonatomic, readonly) NSError *_Nullable recentError;
@property (nonatomic, readonly) NSDate *_Nullable nextConnectionAttempt;
- (void)connect;
@end
