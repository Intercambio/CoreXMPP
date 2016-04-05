//
//  XMPPStreamFeatureStreamManagement.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientStreamManagement.h"
#import "XMPPStreamFeature.h"

@protocol XMPPStreamFeatureDelegateStreamManagement <XMPPStreamFeatureDelegate>
@optional
- (id<XMPPClientStreamManagement>)previousStreamManagementForStreamFeature:(XMPPStreamFeature *)streamFeature;
@end

@interface XMPPStreamFeatureStreamManagement : XMPPStreamFeature <XMPPClientStreamManagement>

@end
