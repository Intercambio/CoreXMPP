//
//  XMPPKeyChainItemAttributes.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 19.02.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPKeyChainItemAttributes.h"

@implementation XMPPKeyChainItemAttributes

#pragma mark Life-cycle

- (instancetype)initWithOptions:(NSDictionary *)options
                      suspended:(BOOL)suspended
{
    self = [super init];
    if (self) {
        _options = options;
        _suspended = suspended;
    }
    return self;
}

@end
