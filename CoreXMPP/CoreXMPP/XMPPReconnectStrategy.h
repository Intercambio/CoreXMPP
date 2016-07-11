//
//  XMPPReconnectStrategy.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_SWIFT_NAME(ReconnectStrategy)
@protocol XMPPReconnectStrategy <NSObject>

@property (nonatomic, readonly) NSDate *_Nullable nextConnectionAttempt;

- (void)start;
- (void)stop;

@end
