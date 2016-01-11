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

@protocol XMPPStreamFeatureDelegate <NSObject>
- (void)streamFeatureDidSucceedNegotiation:(XMPPStreamFeature *)streamFeature;
- (void)streamFeature:(XMPPStreamFeature *)streamFeature didFailNegotiationWithError:(NSError *)error;
- (void)streamFeature:(XMPPStreamFeature *)streamFeature handleElement:(PXElement *)element;
@end

@interface XMPPStreamFeature : NSObject

#pragma mark Feature Name & Namespace
+ (NSString *)name;
+ (NSString *) namespace;

#pragma mark Life-cycle
- (id)initWithConfiguration:(PXDocument *)configuration;

#pragma mark Feature Configuration
@property (nonatomic, readonly) PXDocument *configuration;

#pragma mark Operation Queue
@property (nonatomic, strong) dispatch_queue_t queue;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPStreamFeatureDelegate> delegate;

#pragma mark Feature Properties
@property (nonatomic, readonly, getter=isMandatory) BOOL mandatory;
@property (nonatomic, readonly) BOOL needsRestart;

#pragma mark Negotiate Feature
- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options;
- (void)handleElement:(PXElement *)element;

@end
