//
//  NSError+ConnectivityErrorType.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "NSError+ConnectivityErrorType.h"
#import "XMPPError.h"

@implementation NSError (ConnectivityErrorType)

- (XMPPConnectivityErrorType)xmpp_ConnectivityErrorType
{
    if ([self.domain isEqualToString:NSPOSIXErrorDomain]) {
        switch (self.code) {
        case 57: // Socket is not connected
                 // This error code indicates, that the socket has been interupted for example due to the background mode. In this case, the client can reconnect directly.
            return XMPPConnectivityErrorTypeNone;
        default:
            break;
        }
    } else if ([self.domain isEqualToString:NSURLErrorDomain]) {
        switch (self.code) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorCannotFindHost:
            return XMPPConnectivityErrorTypeNetworkReachability;

        default:
            break;
        }
    } else if ([self.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork]) {
        switch (self.code) {
        case kCFURLErrorNotConnectedToInternet:
        case kCFURLErrorDNSLookupFailed:
        case kCFURLErrorCannotFindHost:
            return XMPPConnectivityErrorTypeNetworkReachability;

        default:
            break;
        }
    } else if ([self.domain isEqualToString:XMPPStreamFeatureSASLErrorDomain]) {
        switch (self.code) {
        case XMPPStreamFeatureSASLErrorCodeTemporaryAuthFailure:
            return XMPPConnectivityErrorTypeTemporal;
        default:
            return XMPPConnectivityErrorTypePermanent;
        }
    }
    return XMPPConnectivityErrorTypeTemporal;
}

@end
