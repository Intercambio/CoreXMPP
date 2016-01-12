//
//  XMPPStreamFeatureSession.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 12.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeatureSession.h"

NSString *const XMPPStreamFeatureSessionNamespace = @"urn:ietf:params:xml:ns:xmpp-session";

@interface XMPPStreamFeatureSession () {
    NSString *_requestId;
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
    [XMPPClient registerStreamFeatureClass:[XMPPStreamFeatureSession class] forStreamFeatureQName:QName];
}

- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options
{
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
    [iq addElementWithName:@"session" namespace:XMPPStreamFeatureSessionNamespace content:nil];
    
    [self.delegate streamFeature:self handleElement:iq];
}

- (void)handleElement:(PXElement *)element
{
    if ([element.namespace isEqualToString:@"jabber:client"] &&
        [element.name isEqualToString:@"iq"]) {
        
        NSString *type = [element valueForAttribute:@"type"];
        
        if ([type isEqualToString:@"result"]) {
            [self handleIQResult:element];
        } else if ([type isEqualToString:@"error"]) {
            [self handleIQError:element];
        }
    }
}

#pragma mark -

- (void)handleIQResult:(PXElement *)iq
{
    NSString *responseId = [iq valueForAttribute:@"id"];
    
    if (responseId && [responseId isEqualToString:_requestId]) {
        [self.delegate streamFeatureDidSucceedNegotiation:self];
        _requestId = nil;
    }
}

- (void)handleIQError:(PXElement *)iq
{
    NSString *responseId = [iq valueForAttribute:@"id"];
    
    if (responseId && [responseId isEqualToString:_requestId]) {
        NSError *error = [XMPPStanza errorFromStanza:iq];
        [self.delegate streamFeature:self didFailNegotiationWithError:error];
        _requestId = nil;
    }
}

@end
