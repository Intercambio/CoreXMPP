//
//  XMPPAccount.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XMPPAccount : NSObject

- (instancetype)initWithJID:(NSString *)jid;

@property (nonatomic, readonly) NSString *JID;

@property (nonatomic, readwrite) BOOL suspended;
@property (nonatomic, readwrite) BOOL connected;

@end
