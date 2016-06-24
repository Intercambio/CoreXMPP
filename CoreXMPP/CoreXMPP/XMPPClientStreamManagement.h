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
@property (nonatomic, readonly, getter=isResumable) BOOL resumable;
@property (nonatomic, readonly, getter=isResumed) BOOL resumed;
@property (nonatomic, readonly) NSUInteger numberOfReceivedDocuments;
@property (nonatomic, readonly) NSUInteger numberOfSentDocuments;
@property (nonatomic, readonly) NSUInteger numberOfAcknowledgedDocuments;
@property (nonatomic, readonly) NSArray *unacknowledgedDocuments;

- (void)didSentDocument:(PXDocument *)document acknowledgement:(void (^)(NSError *error))acknowledgement;
- (void)didHandleReceviedDocument:(PXDocument *)document;

- (void)requestAcknowledgement;
- (void)sendAcknowledgement;

- (void)cancelUnacknowledgedDocuments;

@end
