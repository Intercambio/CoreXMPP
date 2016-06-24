//
//  XMPPStreamFeature.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeature.h"

@implementation XMPPStreamFeature

#pragma mark Registered Stream Features

+ (NSMutableDictionary *)xmpp_registeredStreamFeatures
{
    static NSMutableDictionary *registeredStreamFeatures;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registeredStreamFeatures = [[NSMutableDictionary alloc] init];
    });
    return registeredStreamFeatures;
}

+ (NSDictionary *)registeredStreamFeatures
{
    return [self xmpp_registeredStreamFeatures];
}

+ (void)registerStreamFeatureClass:(Class)featureClass forStreamFeatureQName:(PXQName *)streamFeatureQName
{
    NSParameterAssert(featureClass);
    NSParameterAssert(streamFeatureQName);

    NSMutableDictionary *registeredStreamFeatures = [self xmpp_registeredStreamFeatures];
    [registeredStreamFeatures setObject:featureClass forKey:streamFeatureQName];
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return nil;
}

+ (NSString *)namespace
{
    return nil;
}

#pragma mark Life-cycle

+ (instancetype)streamFeatureWithConfiguration:(PXDocument *)configuration
{
    Class featureClass = [[[self class] registeredStreamFeatures] objectForKey:configuration.root.qualifiedName];
    if (featureClass) {
        XMPPStreamFeature *feature = (XMPPStreamFeature *)[[featureClass alloc] initWithConfiguration:configuration];
        return feature;
    } else {
        return nil;
    }
}

- (id)initWithConfiguration:(PXDocument *)configuration
{
    self = [super init];
    if (self) {
        _configuration = configuration;
    }
    return self;
}

#pragma mark Feature Properties

- (BOOL)isMandatory
{
    return NO;
}

- (BOOL)needsRestart
{
    return NO;
}

#pragma mark Negotiate Feature

- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options
{
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    return YES;
}

@end
