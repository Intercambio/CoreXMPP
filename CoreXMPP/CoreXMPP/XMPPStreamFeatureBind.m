//
//  XMPPStreamFeatureBind.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPError.h"

#import "XMPPStreamFeatureBind.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPStreamFeatureBindNamespace = @"urn:ietf:params:xml:ns:xmpp-bind";

@interface XMPPStreamFeatureBind () {
    NSString *_requestId;
    NSString *_hostname;
}

@end

@implementation XMPPStreamFeatureBind

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureBind name] namespace:[XMPPStreamFeatureBind namespace]];
    [XMPPClient registerStreamFeatureClass:[XMPPStreamFeatureBind class] forStreamFeatureQName:QName];
}

#pragma mark Logging

+ (DDLogLevel)ddLogLevel
{
    return ddLogLevel;
}

+ (void)ddSetLogLevel:(DDLogLevel)logLevel
{
    ddLogLevel = logLevel;
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return @"bind";
}

+ (NSString *) namespace
{
    return XMPPStreamFeatureBindNamespace;
}

#pragma mark Life-cycle

- (id)initWithConfiguration:(PXDocument *)configuration
{
    self = [super initWithConfiguration:configuration];
    if (self) {
    }
    return self;
}

#pragma mark Feature Properties

- (BOOL)isMandatory
{
    return YES;
}

- (BOOL)needsRestart
{
    return NO;
}

#pragma mark Negotiate Feature

- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options
{
    _hostname = hostname;

    NSString *preferredResourceName = nil;

    // Try to get the preferred resource name via the delegate

    if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateBind)]) {
        id<XMPPStreamFeatureDelegateBind> delegate = (id<XMPPStreamFeatureDelegateBind>)self.delegate;
        if ([delegate respondsToSelector:@selector(resourceNameForStreamFeature:)]) {
            preferredResourceName = [delegate resourceNameForStreamFeature:self];
        }
    }

    _requestId = [[NSUUID UUID] UUIDString];

    PXDocument *request = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

    PXElement *iq = request.root;
    [iq setValue:@"set" forAttribute:@"type"];
    [iq setValue:_requestId forAttribute:@"id"];

    PXElement *bind = [iq addElementWithName:@"bind" namespace:XMPPStreamFeatureBindNamespace content:nil];
    if (preferredResourceName) {
        [bind addElementWithName:@"resource" namespace:XMPPStreamFeatureBindNamespace content:preferredResourceName];
    }

    DDLogInfo(@"Requesting '%@' to bind the client to the resource: %@", _hostname, preferredResourceName);

    [self.stanzaHandler handleStanza:iq
                          completion:^(NSError *error){

                          }];
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    if ([stanza.namespace isEqualToString:@"jabber:client"] &&
        [stanza.name isEqualToString:@"iq"]) {

        NSString *type = [stanza valueForAttribute:@"type"];

        if ([type isEqualToString:@"result"]) {
            [self handleIQResult:stanza completion:completion];
        } else if ([type isEqualToString:@"error"]) {
            [self handleIQError:stanza completion:completion];
        } else {
            if (completion) {
                completion(nil);
            }
        }
    } else {
        if (completion) {
            completion(nil);
        }
    }
}

#pragma mark -

- (void)handleIQResult:(PXElement *)iq completion:(void (^)(NSError *))completion
{
    NSString *responseId = [iq valueForAttribute:@"id"];

    if (responseId && [responseId isEqualToString:_requestId]) {

        PXElement *jidNode = [[iq nodesForXPath:@"./x:bind/x:jid"
                                usingNamespaces:@{ @"x" : XMPPStreamFeatureBindNamespace }] firstObject];

        XMPPJID *JID = [XMPPJID JIDFromString:[jidNode stringValue]];

        if (JID) {

            DDLogError(@"Did bind to '%@'.", [JID stringValue]);

            if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateBind)]) {
                id<XMPPStreamFeatureDelegateBind> delegate = (id<XMPPStreamFeatureDelegateBind>)self.delegate;
                if ([delegate respondsToSelector:@selector(streamFeature:didBindToJID:)]) {
                    [delegate streamFeature:self didBindToJID:JID];
                }
            }
            [self.delegate streamFeatureDidSucceedNegotiation:self];
        } else {

            DDLogError(@"Missing JID in response: %@", iq);

            NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                                 code:XMPPStanzaErrorCodeUndefinedCondition
                                             userInfo:nil];
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
        }
        _requestId = nil;
    }

    if (completion) {
        completion(nil);
    }
}

- (void)handleIQError:(PXElement *)iq completion:(void (^)(NSError *))completion
{
    NSString *responseId = [iq valueForAttribute:@"id"];

    if (responseId && [responseId isEqualToString:_requestId]) {

        NSError *error = [NSError errorFromStanza:iq];

        DDLogInfo(@"Host '%@' did reject to bind to resource with error: %@", _hostname, [error localizedDescription]);

        [self.delegate streamFeature:self didFailNegotiationWithError:error];
        _requestId = nil;
    }

    if (completion) {
        completion(nil);
    }
}

@end
