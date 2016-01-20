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
- (instancetype)init;

#pragma mark Router
@property (nonatomic, weak) XMPPRouter *router;

@end
