//
//  XMPPModule.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPModule.h"

@implementation XMPPModule

- (instancetype)initWithServiceManager:(XMPPServiceManager *)serviceManager
                            dispatcher:(XMPPDispatcher *)dispatcher
                               options:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _serviceManager = serviceManager;
        _dispatcher = dispatcher;
        _options = options;
    }
    return self;
}

- (void)loadModuleWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    if (completion) {
        completion(YES, nil);
    }
}

@end
