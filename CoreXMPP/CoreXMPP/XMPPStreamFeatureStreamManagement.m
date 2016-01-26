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
    BOOL _enabled;
    NSUInteger _numberOfReceivedStanzas;
    NSUInteger _numberOfSendStanzas;
    NSUInteger _numberOfAcknowledgedStanzas;
    NSArray *_unacknowledgedStanzas;
}
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
    DDLogInfo(@"Negotiating stream management for host '%@'.", hostname);
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"enable"
                                                        namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                           prefix:nil];
    [self.stanzaHandler handleStanza:request.root
                          completion:^(NSError *error){
                          }];
}

#pragma mark XMPPClientStreamManagement

@synthesize enabled = _enabled;
@synthesize numberOfReceivedStanzas = _numberOfReceivedStanzas;
@synthesize numberOfSendStanzas = _numberOfSendStanzas;
@synthesize numberOfAcknowledgedStanzas = _numberOfAcknowledgedStanzas;

- (NSArray *)unacknowledgedStanzas
{
    return _unacknowledgedStanzas ?: @[];
}

- (void)didSentStanza:(PXElement *)stanza
{
    [self willChangeValueForKey:@"numberOfSendStanzas"];
    [self willChangeValueForKey:@"unacknowledgedStanzas"];

    _numberOfSendStanzas += 1;
    _unacknowledgedStanzas = [_unacknowledgedStanzas arrayByAddingObject:stanza];

    [self didChangeValueForKey:@"unacknowledgedStanzas"];
    [self didChangeValueForKey:@"numberOfSendStanzas"];
}

- (void)didHandleReceviedStanza:(PXElement *)stanza
{
    [self willChangeValueForKey:@"numberOfReceivedStanzas"];

    _numberOfReceivedStanzas += 1;

    [self didChangeValueForKey:@"numberOfReceivedStanzas"];
}

- (void)requestAcknowledgement
{
    PXDocument *response = [[PXDocument alloc] initWithElementName:@"r"
                                                         namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                            prefix:nil];

    [self.stanzaHandler handleStanza:response.root completion:nil];
}

- (void)sendAcknowledgement
{
    PXDocument *response = [[PXDocument alloc] initWithElementName:@"a"
                                                         namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                            prefix:nil];
    [response.root setValue:[@(_numberOfReceivedStanzas) stringValue] forAttribute:@"h"];

    [self.stanzaHandler handleStanza:response.root completion:nil];
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    if ([stanza.namespace isEqualToString:[XMPPStreamFeatureStreamManagement namespace]]) {

        if ([stanza.name isEqualToString:@"enabled"]) {

            _enabled = YES;
            _numberOfSendStanzas = 0;
            _numberOfReceivedStanzas = 0;
            _numberOfAcknowledgedStanzas = 0;
            _unacknowledgedStanzas = @[];

            [self.delegate streamFeatureDidSucceedNegotiation:self];

        } else if ([stanza.name isEqualToString:@"failed"]) {

            _enabled = NO;

            NSError *error = [NSError errorFromElement:stanza];
            [self.delegate streamFeature:self didFailNegotiationWithError:error];

        } else if ([stanza.name isEqualToString:@"r"]) {

            [self sendAcknowledgement];

        } else if ([stanza.name isEqualToString:@"a"]) {

            NSString *value = [stanza valueForAttribute:@"h"];
            if (value) {
                NSUInteger h = [value integerValue];
                [self xmpp_updateWithNumberOfAcknowledgedStanzas:h];
            }
        }
    }

    if (completion) {
        completion(nil);
    }
}

#pragma mark -

- (void)xmpp_updateWithNumberOfAcknowledgedStanzas:(NSUInteger)numberOfAcknowledgedStanzas
{
    if (_numberOfAcknowledgedStanzas > numberOfAcknowledgedStanzas ||
        _numberOfAcknowledgedStanzas + [_unacknowledgedStanzas count] < numberOfAcknowledgedStanzas) {
        // Invalid ACK
    } else {
        NSUInteger diff = numberOfAcknowledgedStanzas - _numberOfAcknowledgedStanzas;
        _unacknowledgedStanzas = [_unacknowledgedStanzas subarrayWithRange:NSMakeRange(diff, [_unacknowledgedStanzas count] - diff)];
        _numberOfAcknowledgedStanzas = numberOfAcknowledgedStanzas;
    }
}

@end
