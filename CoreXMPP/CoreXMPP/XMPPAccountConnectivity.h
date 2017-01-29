//
//  XMPPAccountConnectivity.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 01.07.16.
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
