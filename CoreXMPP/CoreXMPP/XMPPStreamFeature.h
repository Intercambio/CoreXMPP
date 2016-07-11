//
//  XMPPStreamFeature.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
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
