//
//  XMPPStreamFeatureSession.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPStreamFeatureSession.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

NSString *const XMPPStreamFeatureSessionNamespace = @"urn:ietf:params:xml:ns:xmpp-session";

@interface XMPPStreamFeatureSession () {
    NSString *_requestId;
    NSString *_hostname;
}

@end

@implementation XMPPStreamFeatureSession

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
    return @"session";
}

+ (NSString *)namespace
{
    return XMPPStreamFeatureSessionNamespace;
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

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureSession name] namespace:[XMPPStreamFeatureSession namespace]];
    [self registerStreamFeatureClass:[XMPPStreamFeatureSession class] forStreamFeatureQName:QName];
}

- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options
{
    DDLogInfo(@"Requesting new session for host '%@'.", hostname);

    _hostname = hostname;
    _requestId = [[NSUUID UUID] UUIDString];

    PXDocument *request = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];

    PXElement *iq = request.root;
    [iq setValue:@"set" forAttribute:@"type"];
    [iq setValue:_requestId forAttribute:@"id"];
    [iq addElementWithName:@"session" namespace:XMPPStreamFeatureSessionNamespace content:nil];

    [self.stanzaHandler handleStanza:iq
                          completion:^(NSError *error){

                          }];
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    PXElement *stanza = document.root;

    if ([stanza.namespace isEqualToString:@"jabber:client"] &&
        [stanza.name isEqualToString:@"iq"]) {

        NSString *type = [stanza valueForAttribute:@"type"];

        if ([type isEqualToString:@"result"]) {
            return [self handleIQResult:stanza error:error];
        } else if ([type isEqualToString:@"error"]) {
            return [self handleIQError:stanza error:error];
        } else {
            return YES;
        }
    } else {
        return YES;
    }
}

#pragma mark -

- (BOOL)handleIQResult:(PXElement *)iq error:(NSError **)error
{
    NSString *responseId = [iq valueForAttribute:@"id"];

    if (responseId && [responseId isEqualToString:_requestId]) {

        DDLogInfo(@"Host '%@' did accept new session.", _hostname);

        [self.delegate streamFeatureDidSucceedNegotiation:self];
        _requestId = nil;
    }

    return YES;
}

- (BOOL)handleIQError:(PXElement *)iq error:(NSError **)error
{
    NSString *responseId = [iq valueForAttribute:@"id"];

    if (responseId && [responseId isEqualToString:_requestId]) {
        NSError *error = [NSError errorFromStanza:iq];

        DDLogInfo(@"Host '%@' did reject new session with error: %@", _hostname, [error localizedDescription]);

        [self.delegate streamFeature:self didFailNegotiationWithError:error];
        _requestId = nil;
    }

    return YES;
}

@end
