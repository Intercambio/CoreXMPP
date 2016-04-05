//
//  XMPPPingModule.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPDispatcher.h"
#import "XMPPModule.h"

@class XMPPJID;

@interface XMPPPingModule : XMPPModule <XMPPIQHandler>

+ (void)sendPingUsingIQHandler:(id<XMPPIQHandler>)IQHandler
                            to:(XMPPJID *)to
                          from:(XMPPJID *)from
                       timeout:(NSTimeInterval)timeout
             completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

- (void)sendPingTo:(XMPPJID *)to
                 from:(XMPPJID *)from
              timeout:(NSTimeInterval)timeout
    completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

@end
