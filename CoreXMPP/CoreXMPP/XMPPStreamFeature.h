//
//  XMPPStreamFeature.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
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

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

@class XMPPStreamFeature;

NS_SWIFT_NAME(StreamFeatureDelegate)
@protocol XMPPStreamFeatureDelegate <NSObject>
- (void)streamFeature:(nonnull XMPPStreamFeature *)streamFeature handleDocument:(nonnull PXDocument *)document NS_SWIFT_NAME(streamFeature(_:handle:));
- (void)streamFeatureDidSucceedNegotiation:(nonnull XMPPStreamFeature *)streamFeature NS_SWIFT_NAME(streamFeatureDidSucceedNegotiation(_:));
- (void)streamFeature:(nonnull XMPPStreamFeature *)streamFeature didFailNegotiationWithError:(nonnull NSError *)error NS_SWIFT_NAME(streamFeature(_:didFail:));
@end

NS_SWIFT_NAME(StreamFeature)
@interface XMPPStreamFeature : NSObject

#pragma mark Registered Stream Features
+ (nonnull NSDictionary<PXQName *, Class> *)registeredStreamFeatures;
+ (void)registerStreamFeatureClass:(nonnull Class)featureClass forStreamFeatureQName:(nonnull PXQName *)streamFeatureQName;

#pragma mark Feature Name & Namespace
+ (nonnull NSString *)name;
+ (nonnull NSString *)namespace;

#pragma mark Life-cycle
+ (nullable instancetype)streamFeatureWithConfiguration:(nonnull PXDocument *)configuration;
- (nonnull instancetype)initWithConfiguration:(nonnull PXDocument *)configuration;

#pragma mark Feature Configuration
@property (nonatomic, readonly) PXDocument *_Nonnull configuration;
@property (nonatomic, readonly, getter=isMandatory) BOOL mandatory;
@property (nonatomic, readonly) BOOL needsRestart;

#pragma mark Operation Queue
@property (nonatomic, strong) dispatch_queue_t _Nullable queue;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPStreamFeatureDelegate> _Nullable delegate;

#pragma mark Negotiate Feature
- (void)beginNegotiationWithHostname:(nonnull NSString *)hostname options:(nullable NSDictionary *)options NS_SWIFT_NAME(beginNegotiation(hostname:options:));

#pragma mark Handle Document
- (BOOL)handleDocument:(nonnull PXDocument *)document error:(NSError *__autoreleasing __nullable *__nullable)error NS_SWIFT_NAME(handle(_:));

#pragma mark -
- (void)sendIQRequest:(nonnull PXDocument *)document
              timeout:(NSTimeInterval)timeout
           completion:(nonnull void (^)(PXDocument *_Nullable response, NSError *_Nullable error))completion NS_SWIFT_NAME(sendIQRequest(_:timeout:completion:));

@end
