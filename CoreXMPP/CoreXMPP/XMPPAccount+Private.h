//
//  XMPPAccount+Private.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPServiceManager.h"
#import "XMPPAccount.h"

@interface XMPPAccount (Private)

- (instancetype)initWithJID:(NSString *)JID
             serviceManager:(XMPPServiceManager *)serviceManager;

@property (nonatomic, readwrite) BOOL suspended;
@property (nonatomic, readwrite) BOOL connected;

@end
