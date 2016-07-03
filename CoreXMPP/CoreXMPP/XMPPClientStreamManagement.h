//
//  XMPPClientStreamManagement.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

NS_SWIFT_NAME(ClientStreamManagement)
@protocol XMPPClientStreamManagement <NSObject>

@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, getter=isResumable) BOOL resumable;
@property (nonatomic, readonly, getter=isResumed) BOOL resumed;
@property (nonatomic, readonly) NSUInteger numberOfReceivedDocuments;
@property (nonatomic, readonly) NSUInteger numberOfSentDocuments;
@property (nonatomic, readonly) NSUInteger numberOfAcknowledgedDocuments;
@property (nonatomic, readonly) NSArray *_Nonnull unacknowledgedDocuments;

- (void)didSentDocument:(nonnull PXDocument *)document acknowledgement:(nonnull void (^)(NSError *_Nullable error))acknowledgement NS_SWIFT_NAME(didSent(_:acknowledgement:));
- (void)didHandleReceviedDocument:(nonnull PXDocument *)document NS_SWIFT_NAME(didReceive(_:));

- (void)requestAcknowledgement;
- (void)sendAcknowledgement;

- (void)cancelUnacknowledgedDocuments;

@end
