//
//  XMPPIQHandlerProxy.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPDispatcher.h"

@interface XMPPIQHandlerProxy : NSObject <XMPPIQHandler>

@property (nonatomic, strong) id<XMPPIQHandler> handler;
@property (nonatomic, strong) id context;

@end
