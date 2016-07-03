//
//  XMPPStreamFeatureBind.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

@class XMPPJID;

extern NSString *_Nonnull const XMPPStreamFeatureBindNamespace NS_SWIFT_NAME(StreamFeatureBindNamespace);

NS_SWIFT_NAME(StreamFeatureDelegateBind)
@protocol XMPPStreamFeatureDelegateBind <XMPPStreamFeatureDelegate>
@optional
- (nullable NSString *)resourceNameForStreamFeature:(nonnull XMPPStreamFeature *)streamFeature NS_SWIFT_NAME(resourceNameForStreamFeature(_:));
- (void)streamFeature:(nonnull XMPPStreamFeature *)streamFeature didBindToJID:(nonnull XMPPJID *)JID NS_SWIFT_NAME(streamFeature(_:didBind:));
@end

NS_SWIFT_NAME(StreamFeatureBind)
@interface XMPPStreamFeatureBind : XMPPStreamFeature

@end
