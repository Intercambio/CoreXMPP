//
//  XMPPStreamFeatureSession.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
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

#import "XMPPStreamFeatureSession.h"

NSString *const XMPPStreamFeatureSessionNamespace = @"urn:ietf:params:xml:ns:xmpp-session";

@interface XMPPStreamFeatureSession () {
    NSString *_requestId;
    NSString *_hostname;
}

@end

@implementation XMPPStreamFeatureSession

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
    NSLog(@"Requesting new session for host '%@'.", hostname);

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

        NSLog(@"Host '%@' did accept new session.", _hostname);

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

        NSLog(@"Host '%@' did reject new session with error: %@", _hostname, [error localizedDescription]);

        [self.delegate streamFeature:self didFailNegotiationWithError:error];
        _requestId = nil;
    }

    return YES;
}

@end
