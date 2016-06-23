//
//  XMPPStreamFeature.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

#import "XMPPStanzaHandler.h"

@class XMPPStreamFeature;

@protocol XMPPStreamFeatureDelegate <NSObject>
- (void)streamFeatureDidSucceedNegotiation:(XMPPStreamFeature *)streamFeature;
- (void)streamFeature:(XMPPStreamFeature *)streamFeature didFailNegotiationWithError:(NSError *)error;
@end

@interface XMPPStreamFeature : NSObject

#pragma mark Registered Stream Features
+ (NSDictionary *)registeredStreamFeatures;
+ (void)registerStreamFeatureClass:(Class)featureClass forStreamFeatureQName:(PXQName *)streamFeatureQName;

#pragma mark Feature Name & Namespace
+ (NSString *)name;
+ (NSString *)namespace;

#pragma mark Life-cycle
+ (instancetype)streamFeatureWithConfiguration:(PXDocument *)configuration;
- (id)initWithConfiguration:(PXDocument *)configuration;

#pragma mark Feature Configuration
@property (nonatomic, readonly) PXDocument *configuration;
@property (nonatomic, readonly, getter=isMandatory) BOOL mandatory;
@property (nonatomic, readonly) BOOL needsRestart;

#pragma mark Operation Queue
@property (nonatomic, strong) dispatch_queue_t queue;

#pragma mark Delegate & Stanza Handler
@property (nonatomic, weak) id<XMPPStreamFeatureDelegate> delegate;
@property (nonatomic, weak) id<XMPPStanzaHandler> stanzaHandler;

#pragma mark Negotiate Feature
- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options;

#pragma mark Handle Document
- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error;

@end
