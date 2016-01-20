//
//  XMPPIQHandlerProxy.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPIQHandlerProxy.h"

@implementation XMPPIQHandlerProxy

- (void)handleIQRequest:(PXElement *)stanza resultHandler:(id<XMPPIQHandler>)resultHandler
{
    [self.handler handleIQRequest:stanza resultHandler:resultHandler];
}

- (void)handleIQResponse:(PXElement *)stanza
{
    [self.handler handleIQResponse:stanza];
}

@end
