//
//  XMPPStreamFeatureBind.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2015, 2016, 2017 Tobias Kräntzer. 
//
//  This file is part of CoreXMPP.
//
//  CoreXMPP is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option)
//  any later version.
//
//  CoreXMPP is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with
//  CoreXMPP. If not, see <http://www.gnu.org/licenses/>.
//
//  Linking this library statically or dynamically with other modules is making
//  a combined work based on this library. Thus, the terms and conditions of the
//  GNU General Public License cover the whole combination.
//
//  As a special exception, the copyright holders of this library give you
//  permission to link this library with independent modules to produce an
//  executable, regardless of the license terms of these independent modules,
//  and to copy and distribute the resulting executable under terms of your
//  choice, provided that you also meet, for each linked independent module, the
//  terms and conditions of the license of that module. An independent module is
//  a module which is not derived from or based on this library. If you modify
//  this library, you must extend this exception to your version of the library.
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
