//
//  XMPPStreamFeature.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeature.h"
#import "XMPPError.h"
#import "XMPPJID.h"

@interface XMPPStreamFeature () {
    NSMapTable *_responseHandlers;
}

@end

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
        _responseHandlers = [NSMapTable strongToStrongObjectsMapTable];
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
    if ([document.root isEqual:PXQN(@"jabber:client", @"iq")]) {
        NSString *type = [document.root valueForAttribute:@"type"];
        if ([type isEqualToString:@"result"] ||
            [type isEqualToString:@"error"]) {
            NSString *requestID = [document.root valueForAttribute:@"id"];
            if (requestID) {
                void (^completion)(PXDocument *response, NSError *error) = [_responseHandlers objectForKey:requestID];
                if (completion) {
                    [_responseHandlers removeObjectForKey:requestID];

                    if ([type isEqualToString:@"error"]) {
                        NSError *error = [NSError errorFromStanza:document.root];
                        completion(nil, error);
                    } else {
                        completion(document, nil);
                    }
                }
            }
        }
    }
    return YES;
}

#pragma mark -

- (void)sendIQRequest:(PXDocument *)document
              timeout:(NSTimeInterval)timeout
           completion:(void (^)(PXDocument *response, NSError *error))completion
{
    NSString *type = [document.root valueForAttribute:@"type"];
    if ([document.root isEqual:PXQN(@"jabber:client", @"iq")] && ([type isEqualToString:@"get"] || [type isEqualToString:@"set"])) {

        NSString *requestId = [document.root valueForAttribute:@"id"];
        if (requestId == nil) {
            requestId = [[NSUUID UUID] UUIDString];
            [document.root setValue:requestId forAttribute:@"id"];
        }

        if (completion) {
            [_responseHandlers setObject:completion forKey:requestId];
        }

        NSTimeInterval defaultTimeout = 60.0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout ?: defaultTimeout) * NSEC_PER_SEC)), self.queue, ^{
            void (^completion)(PXElement *response, NSError *error) = [_responseHandlers objectForKey:requestId];
            if (completion) {
                [_responseHandlers removeObjectForKey:requestId];
                NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                     code:XMPPDispatcherErrorCodeTimeout
                                                 userInfo:nil];
                completion(nil, error);
            }
        });

        [self.delegate streamFeature:self handleDocument:document];

    } else {
        if (completion) {
            NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                                 code:XMPPDispatcherErrorCodeInvalidStanza
                                             userInfo:nil];
            completion(nil, error);
        }
    }
}

@end
