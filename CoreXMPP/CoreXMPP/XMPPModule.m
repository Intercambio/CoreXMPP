//
//  XMPPModule.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPModule.h"

@implementation XMPPModule

#pragma mark Life-cycle

- (instancetype)initWithRouter:(XMPPRouter *)router options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _router = router;
        _options = options;
    }
    return self;
}

@end
