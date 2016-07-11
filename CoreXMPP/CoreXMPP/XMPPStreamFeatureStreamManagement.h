//
//  XMPPStreamFeatureStreamManagement.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPClientStreamManagement.h"
#import "XMPPStreamFeature.h"

extern NSString *_Nonnull const XMPPStreamFeatureStreamManagementNamespace NS_SWIFT_NAME(StreamFeatureStreamManagementNamespace);

NS_SWIFT_NAME(StreamFeatureStreamManagement)
@interface XMPPStreamFeatureStreamManagement : XMPPStreamFeature <XMPPClientStreamManagement>

@end
