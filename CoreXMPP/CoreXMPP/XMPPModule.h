//
//  XMPPModule.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPRouter;

@interface XMPPModule : NSObject

#pragma mark Life-cycle
- (instancetype)initWithRouter:(XMPPRouter *)router options:(NSDictionary *)options;

#pragma mark Options
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Router
@property (nonatomic, readonly) XMPPRouter *router;

@end
