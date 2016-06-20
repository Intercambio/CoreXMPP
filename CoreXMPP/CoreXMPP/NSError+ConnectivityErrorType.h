//
//  NSError+ConnectivityErrorType.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, XMPPConnectivityErrorType) {
    XMPPConnectivityErrorTypeNone,
    XMPPConnectivityErrorTypeTemporal,
    XMPPConnectivityErrorTypeNetworkReachability,
    XMPPConnectivityErrorTypePermanent
};

@interface NSError (ConnectivityErrorType)

- (XMPPConnectivityErrorType)xmpp_ConnectivityErrorType;

@end
