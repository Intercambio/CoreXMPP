//
//  XMPPClientFactoryImpl.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 23.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientFactory.h"
#import <Foundation/Foundation.h>

@interface XMPPClientFactoryImpl : NSObject <XMPPClientFactory>

@property (nonatomic, assign) NSTimeInterval minReconnectTimeInterval; // default 1.0
@property (nonatomic, assign) NSTimeInterval maxReconnectTimeInterval; // default 60.0

@end
