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

    [self.delegate streamFeature:self handleDocument:request];
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    if ([document.root isKindOfClass:[XMPPIQStanza class]]) {
        XMPPIQStanza *iq = (XMPPIQStanza *)document.root;
        switch (iq.type) {
            case XMPPIQStanzaTypeResult:
                return [self handleIQResult:iq error:error];
            case XMPPIQStanzaTypeError:
                return [self handleIQError:iq error:error];
            default:
                return YES;
        }
    } else {
        return YES;
    }
}

#pragma mark -

- (BOOL)handleIQResult:(XMPPIQStanza *)iq error:(NSError **)error
{
    NSString *responseId = iq.identifier;

    if (responseId && [responseId isEqualToString:_requestId]) {

        DDLogInfo(@"Host '%@' did accept new session.", _hostname);

        [self.delegate streamFeatureDidSucceedNegotiation:self];
        _requestId = nil;
    }

    return YES;
}

- (BOOL)handleIQError:(XMPPIQStanza *)iq error:(NSError **)error
{
    NSString *responseId = iq.identifier;

    if (responseId && [responseId isEqualToString:_requestId]) {
        NSError *error = iq.error;

        DDLogInfo(@"Host '%@' did reject new session with error: %@", _hostname, [error localizedDescription]);

        [self.delegate streamFeature:self didFailNegotiationWithError:error];
        _requestId = nil;
    }

    return YES;
}

@end
