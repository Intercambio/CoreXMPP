//
//  XMPPStreamFeatureBind.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
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

#import "XMPPError.h"

#import "XMPPStreamFeatureBind.h"

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
    [self registerStreamFeatureClass:[XMPPStreamFeatureBind class] forStreamFeatureQName:QName];
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return @"bind";
}

+ (NSString *)namespace
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

    NSLog(@"Requesting '%@' to bind the client to the resource: %@", _hostname, preferredResourceName);

    [self.delegate streamFeature:self handleDocument:request];
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

        PXElement *jidNode = [[iq nodesForXPath:@"./x:bind/x:jid"
                                usingNamespaces:@{ @"x" : XMPPStreamFeatureBindNamespace }] firstObject];

        XMPPJID *JID = [[XMPPJID alloc] initWithString:[jidNode stringValue]];

        if (JID) {

            NSLog(@"Did bind to '%@'.", [JID stringValue]);

            if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateBind)]) {
                id<XMPPStreamFeatureDelegateBind> delegate = (id<XMPPStreamFeatureDelegateBind>)self.delegate;
                if ([delegate respondsToSelector:@selector(streamFeature:didBindToJID:)]) {
                    [delegate streamFeature:self didBindToJID:JID];
                }
            }
            [self.delegate streamFeatureDidSucceedNegotiation:self];
        } else {

            NSLog(@"Missing JID in response: %@", iq);

            NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                                 code:XMPPStanzaErrorCodeUndefinedCondition
                                             userInfo:nil];
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
        }
        _requestId = nil;
    }

    return YES;
}

- (BOOL)handleIQError:(PXElement *)element error:(NSError **)error
{
    if ([element isKindOfClass:[XMPPIQStanza class]]) {
        XMPPIQStanza *iq = (XMPPIQStanza *)element;
        NSString *responseId = iq.identifier;
        if (responseId && [responseId isEqualToString:_requestId]) {
            NSError *error = iq.error;
            NSLog(@"Host '%@' did reject to bind to resource with error: %@", _hostname, [error localizedDescription]);
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
            _requestId = nil;
        }
    }
    return YES;
}

@end
