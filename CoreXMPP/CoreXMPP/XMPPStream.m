//
//  XMPPStream.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStream.h"

@implementation XMPPStream

#pragma mark Life-cycle

- (instancetype)initWithHostname:(NSString *)hostname
                        language:(NSString *)language
                         options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _hostname = [hostname copy];
        _language = [language copy];
        _options = [options copy];
    }
    return self;
}

#pragma mark Managing Stream

- (void)open
{
}

- (void)close
{
}

- (void)sendElement:(PXElement *)element
{
}

@end
