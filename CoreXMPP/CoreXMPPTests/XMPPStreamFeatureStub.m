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
    [self registerStreamFeatureClass:[XMPPStreamFeatureStub class] forStreamFeatureQName:QName];
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return @"feature";
}

+ (NSString *)namespace
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
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"begin"
                                                        namespace:@"http://example.com/"
                                                           prefix:nil];
    [self.stanzaHandler handleStanza:request.root completion:nil];
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    PXElement *stanza = document.root;

    if ([stanza.namespace isEqualToString:@"http://example.com/"]) {
        if ([stanza.name isEqualToString:@"success"]) {
            [self xmpp_handleSuccess];
        } else if ([stanza.name isEqualToString:@"failure"]) {
            NSError *error = [NSError errorWithDomain:@"XMPPStreamFeatureStub" code:10 userInfo:nil];
            [self xmpp_handleFailureWithError:error];
        }
    }

    return YES;
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
