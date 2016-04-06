//
//  XMPPModule.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 19.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPServiceManager;
@class XMPPDispatcher;
@class XMPPAccount;

@interface XMPPModule : NSObject

- (instancetype)initWithServiceManager:(XMPPServiceManager *)serviceManager
                            dispatcher:(XMPPDispatcher *)dispatcher
                               options:(NSDictionary *)options;

@property (nonatomic, weak, readonly) XMPPServiceManager *serviceManager;
@property (nonatomic, weak, readonly) XMPPDispatcher *dispatcher;
@property (nonatomic, readonly) NSDictionary *options;

- (void)loadModuleWithCompletion:(void (^)(BOOL success, NSError *error))completion;

@end
