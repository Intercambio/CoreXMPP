//
//  NSError+ConnectivityHostname.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "NSError+ConnectivityHostname.h"

@implementation NSError (ConnectivityHostname)

- (NSString *)xmpp_connectivityHostname
{
    if ([self.domain isEqualToString:NSURLErrorDomain]) {
        NSURL *URL = [self.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        return [URL host];
    }
    return nil;
}

@end
