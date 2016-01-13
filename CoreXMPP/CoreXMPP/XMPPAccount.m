//
//  XMPPAccount.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPAccount.h"

@implementation XMPPAccount

- (instancetype)initWithJID:(NSString *)jid
{
    self = [super init];
    if (self) {
        _JID = [jid copy];
    }
    return self;
}

@end
