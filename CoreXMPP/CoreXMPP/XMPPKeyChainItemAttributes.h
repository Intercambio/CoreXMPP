//
//  XMPPKeyChainItemAttributes.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 19.02.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XMPPKeyChainItemAttributes : NSObject

#pragma mark Life-cycle
- (instancetype)initWithOptions:(NSDictionary *)options
                      suspended:(BOOL)suspended;

#pragma mark Attributes
@property (atomic, readonly) BOOL suspended;
@property (atomic, readonly) NSDictionary *options;

@end
