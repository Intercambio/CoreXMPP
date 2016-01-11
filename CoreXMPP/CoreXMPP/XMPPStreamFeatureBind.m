//
//  XMPPStreamFeatureBind.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStanza.h"

#import "XMPPStreamFeatureBind.h"

NSString *const XMPPStreamFeatureBindNamespace = @"urn:ietf:params:xml:ns:xmpp-bind";

@interface XMPPStreamFeatureBind () {
    NSString *_requestId;
}

@end

@implementation XMPPStreamFeatureBind

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureBind name] namespace:[XMPPStreamFeatureBind namespace]];
    [XMPPClient registerStreamFeatureClass:[XMPPStreamFeatureBind class] forStreamFeatureQName:QName];
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

        PXElement *jidNode = [[iq nodesForXPath:@"./x:bind/x:jid"
                                usingNamespaces:@{ @"x" : XMPPStreamFeatureBindNamespace }] firstObject];

        NSString *jidString = [jidNode stringValue];

        if (jidString) {
            if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateBind)]) {
                id<XMPPStreamFeatureDelegateBind> delegate = (id<XMPPStreamFeatureDelegateBind>)self.delegate;
                if ([delegate respondsToSelector:@selector(streamFeature:didBindToJID:)]) {
                    [delegate streamFeature:self didBindToJID:jidString];
                }
            }
            [self.delegate streamFeatureDidSucceedNegotiation:self];
        } else {
            NSError *error = [NSError errorWithDomain:XMPPStanzaErrorDomain
                                                 code:XMPPStanzaErrorCodeUndefinedCondition
                                             userInfo:nil];
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
        }
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
