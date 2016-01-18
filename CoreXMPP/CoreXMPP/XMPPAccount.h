//
//  XMPPAccount.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XMPPServiceManager;

@interface XMPPAccount : NSObject

@property (nonatomic, readonly) NSString *JID;
@property (nonatomic, readonly, weak) XMPPServiceManager *serviceManger;

@property (nonatomic, readonly) BOOL suspended;
@property (nonatomic, readonly) BOOL connected;

@end
