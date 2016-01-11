//
//  XMPPStreamFeatureBind.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CoreXMPP/CoreXMPP.h>

extern NSString *const XMPPStreamFeatureBindNamespace;

@protocol XMPPStreamFeatureDelegateBind <XMPPStreamFeatureDelegate>
@optional
- (NSString *)resourceNameForStreamFeature:(XMPPStreamFeature *)streamFeature;
- (void)streamFeature:(XMPPStreamFeature *)streamFeature didBindToJID:(NSString *)jid;
@end

@interface XMPPStreamFeatureBind : XMPPStreamFeature

@end
