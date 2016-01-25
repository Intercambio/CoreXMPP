//
//  XMPPStreamFeatureStreamManagement.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#import "XMPPError.h"
#import "XMPPStreamFeatureStreamManagement.h"

static DDLogLevel ddLogLevel = DDLogLevelWarning;

@interface XMPPStreamFeatureStreamManagement () {
}
@property (atomic, readwrite) NSUInteger numberOfAcknowledgedStanzas;
@end

@implementation XMPPStreamFeatureStreamManagement

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPStreamFeatureStreamManagement name] namespace:[XMPPStreamFeatureStreamManagement namespace]];
    [self registerStreamFeatureClass:[XMPPStreamFeatureStreamManagement class] forStreamFeatureQName:QName];
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
    return @"sm";
}

+ (NSString *) namespace
{
    return @"urn:xmpp:sm:3";
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
    DDLogInfo(@"Enabling stream management for host '%@'.", hostname);
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"enable"
                                                        namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                           prefix:nil];
    [self.stanzaHandler handleStanza:request.root
                          completion:^(NSError *error){
                          }];
}

#pragma mark Acknowledgement

- (void)requestAcknowledgement
{
    PXDocument *response = [[PXDocument alloc] initWithElementName:@"r"
                                                         namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                            prefix:nil];
    [self.stanzaHandler handleStanza:response.root completion:nil];
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    if ([stanza.namespace isEqualToString:[XMPPStreamFeatureStreamManagement namespace]]) {
        if ([stanza.name isEqualToString:@"enabled"]) {
            [self.delegate streamFeatureDidSucceedNegotiation:self];
        } else if ([stanza.name isEqualToString:@"failed"]) {
            NSError *error = [NSError errorFromElement:stanza];
            [self.delegate streamFeature:self didFailNegotiationWithError:error];
        } else if ([stanza.name isEqualToString:@"r"]) {
            PXDocument *response = [[PXDocument alloc] initWithElementName:@"a"
                                                                 namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                                    prefix:nil];
            [response.root setValue:[@(self.numberOfReceivedStanzas) stringValue] forAttribute:@"h"];
            [self.stanzaHandler handleStanza:response.root completion:nil];
        } else if ([stanza.name isEqualToString:@"a"]) {
            NSString *value = [stanza valueForAttribute:@"h"];
            if (value) {
                NSUInteger h = [value integerValue];
                self.numberOfAcknowledgedStanzas = h;
                if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateStreamManagement)]) {
                    id<XMPPStreamFeatureDelegateStreamManagement> delegate = (id<XMPPStreamFeatureDelegateStreamManagement>)self.delegate;
                    [delegate streamFeature:self didAcknowledgeStanzas:h];
                }
            }
        }
    }

    if (completion) {
        completion(nil);
    }
}

@end
