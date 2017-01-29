//
//  XMPPStreamFeature.m
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

@import Foundation;
@import XMPPFoundation;

#import "XMPPStreamFeature.h"
#import "XMPPDispatcherImpl.h"
#import "XMPPError.h"

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
    return @"";
}

+ (NSString *)namespace
{
    return @"";
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
    if ([document.root isKindOfClass:[XMPPIQStanza class]]) {
        XMPPIQStanza *stanza = (XMPPIQStanza *)document.root;

        if (stanza.type == XMPPIQStanzaTypeResult ||
            stanza.type == XMPPIQStanzaTypeError) {
            NSString *requestID = stanza.identifier;
            if (requestID) {
                void (^completion)(PXDocument *response, NSError *error) = [_responseHandlers objectForKey:requestID];
                if (completion) {
                    [_responseHandlers removeObjectForKey:requestID];

                    if (stanza.type == XMPPIQStanzaTypeError) {
                        NSError *error = stanza.error;
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout ?: defaultTimeout) * NSEC_PER_SEC)), self.queue ?: dispatch_get_main_queue(), ^{
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
