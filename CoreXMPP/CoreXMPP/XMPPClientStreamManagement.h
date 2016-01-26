//
//  XMPPClientStreamManagement.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol XMPPClientStreamManagement <NSObject>

@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) NSUInteger numberOfReceivedStanzas;
@property (nonatomic, readonly) NSUInteger numberOfSentStanzas;
@property (nonatomic, readonly) NSUInteger numberOfAcknowledgedStanzas;
@property (nonatomic, readonly) NSArray *unacknowledgedStanzas;

- (void)didSentStanza:(PXElement *)stanza acknowledgement:(void (^)(NSError *error))acknowledgement;
- (void)didHandleReceviedStanza:(PXElement *)stanza;

- (void)requestAcknowledgement;
- (void)sendAcknowledgement;

@end
