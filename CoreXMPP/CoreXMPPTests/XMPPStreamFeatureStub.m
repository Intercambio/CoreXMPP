//
//  XMPPStreamFeatureStub.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 11.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeatureStub.h"

@interface XMPPStreamFeatureStub () {
}

@end

@implementation XMPPStreamFeatureStub

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureStub name] namespace:[XMPPStreamFeatureStub namespace]];
    [XMPPClient registerStreamFeatureClass:[XMPPStreamFeatureStub class] forStreamFeatureQName:QName];
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return @"feature";
}

+ (NSString *) namespace
{
    return @"http://example.com/";
}

#pragma mark Feature Properties

- (BOOL)isMandatory
{
    return [[self.configuration.root valueForAttribute:@"mandatory"] boolValue];
}

- (BOOL)needsRestart
{
    return [[self.configuration.root valueForAttribute:@"needsRestart"] boolValue];
    ;
}

#pragma mark Negotiate Feature

- (void)beginNegotiationWithHostname:(NSString *)hostname options:(NSDictionary *)options
{
    id<XMPPStreamFeatureDelegate> delegate = (id<XMPPStreamFeatureDelegate>)self.delegate;

    PXDocument *request = [[PXDocument alloc] initWithElementName:@"begin" namespace:@"http://example.com/" prefix:nil];

    if ([delegate respondsToSelector:@selector(streamFeature:handleElement:)]) {
        [delegate streamFeature:self handleElement:request.root];
    }
}

- (void)handleElement:(PXElement *)element
{
    if ([element.namespace isEqualToString:@"http://example.com/"]) {
        if ([element.name isEqualToString:@"success"]) {
            [self xmpp_handleSuccess];
        } else if ([element.name isEqualToString:@"failure"]) {
            NSError *error = [NSError errorWithDomain:@"XMPPStreamFeatureStub" code:10 userInfo:nil];
            [self xmpp_handleFailureWithError:error];
        }
    }
}

#pragma mark -

- (void)xmpp_handleSuccess
{
    if ([self.delegate respondsToSelector:@selector(streamFeatureDidSucceedNegotiation:)]) {
        [self.delegate streamFeatureDidSucceedNegotiation:self];
    }
}

- (void)xmpp_handleFailureWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(streamFeature:didFailNegotiationWithError:)]) {
        [self.delegate streamFeature:self didFailNegotiationWithError:error];
    }
}

@end
