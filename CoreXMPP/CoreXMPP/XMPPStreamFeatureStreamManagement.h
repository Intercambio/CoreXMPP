//
//  XMPPStreamFeatureStreamManagement.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeature.h"

@protocol XMPPStreamFeatureDelegateStreamManagement <XMPPStreamFeatureDelegate>
- (void)streamFeature:(XMPPStreamFeature *)streamFeature didAcknowledgeStanzas:(NSUInteger)numberOfAcknowledgedStanzas;
@end

@interface XMPPStreamFeatureStreamManagement : XMPPStreamFeature

#pragma mark Acknowledgement
@property (atomic, readwrite) NSUInteger numberOfReceivedStanzas;
@property (atomic, readonly) NSUInteger numberOfAcknowledgedStanzas;
- (void)requestAcknowledgement;

@end
