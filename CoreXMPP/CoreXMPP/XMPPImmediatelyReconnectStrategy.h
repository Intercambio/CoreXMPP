//
//  XMPPImmediatelyReconnectStrategy.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClient.h"
#import "XMPPReconnectStrategy.h"
#import <Foundation/Foundation.h>

@interface XMPPImmediatelyReconnectStrategy : NSObject <XMPPReconnectStrategy>

#pragma mark Life-cycle
- (instancetype)initWithClient:(XMPPClient *)client;

#pragma mark Properties
@property (nonatomic, readonly) XMPPClient *client;

@end
