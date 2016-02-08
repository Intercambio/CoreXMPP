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

@interface XMPPStreamFeatureStreamManagement_Stanza : NSObject
@property (nonatomic, strong) PXElement *stanza;
@property (nonatomic, strong) void (^acknowledgement)(NSError *error);
@end

#pragma mark -

static DDLogLevel ddLogLevel = DDLogLevelWarning;

@interface XMPPStreamFeatureStreamManagement () {
    BOOL _enabled;
    BOOL _resumable;
    BOOL _resumed;
    NSString *_id;
    NSUInteger _numberOfReceivedStanzas;
    NSUInteger _numberOfSentStanzas;
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

    if (_id && _resumable) {
        [self xmpp_resume];
    } else {
        [self xmpp_enable];
    }
}

#pragma mark XMPPClientStreamManagement

@synthesize enabled = _enabled;
@synthesize resumable = _resumable;
@synthesize resumed = _resumed;
@synthesize numberOfReceivedStanzas = _numberOfReceivedStanzas;
@synthesize numberOfSentStanzas = _numberOfSentStanzas;
@synthesize numberOfAcknowledgedStanzas = _numberOfAcknowledgedStanzas;

- (NSArray *)unacknowledgedStanzas
{
    NSMutableArray *unacknowledgedStanzas = [[NSMutableArray alloc] init];
    if (_unacknowledgedStanzas) {
        for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in _unacknowledgedStanzas) {
            [unacknowledgedStanzas addObject:wrapper.stanza];
        }
    }
    return unacknowledgedStanzas;
}

- (void)didSentStanza:(PXElement *)stanza acknowledgement:(void (^)(NSError *error))acknowledgement;
{
    [self willChangeValueForKey:@"numberOfSentStanzas"];
    [self willChangeValueForKey:@"unacknowledgedStanzas"];

    XMPPStreamFeatureStreamManagement_Stanza *wrapper = [[XMPPStreamFeatureStreamManagement_Stanza alloc] init];
    wrapper.stanza = stanza;
    wrapper.acknowledgement = acknowledgement;

    _numberOfSentStanzas += 1;
    _unacknowledgedStanzas = [_unacknowledgedStanzas arrayByAddingObject:wrapper];

    [self didChangeValueForKey:@"unacknowledgedStanzas"];
    [self didChangeValueForKey:@"numberOfSentStanzas"];

    if (wrapper.acknowledgement) {
        [self requestAcknowledgement];
    }
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

    [self.stanzaHandler handleStanza:response.root
                          completion:^(NSError *error) {
                              if (error) {
                                  DDLogError(@"Failed to request ack with error: %@", [error localizedDescription]);
                              }
                          }];
}

- (void)sendAcknowledgement
{
    PXDocument *response = [[PXDocument alloc] initWithElementName:@"a"
                                                         namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                            prefix:nil];
    [response.root setValue:[@(_numberOfReceivedStanzas) stringValue] forAttribute:@"h"];

    [self.stanzaHandler handleStanza:response.root
                          completion:^(NSError *error) {
                              if (error) {
                                  DDLogError(@"Failed to send ack with error: %@", [error localizedDescription]);
                              }
                          }];
}

- (void)cancelUnacknowledgedStanzas
{
    if ([_unacknowledgedStanzas count] > 0) {
        DDLogInfo(@"Canceling (%ld) unacknowledged stanzas.", (unsigned long)[_unacknowledgedStanzas count]);
        NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                             code:XMPPDispatcherErrorCodeNotConnected
                                         userInfo:nil];
        for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in _unacknowledgedStanzas) {
            if (wrapper.acknowledgement) {
                wrapper.acknowledgement(error);
            }
        }
        _unacknowledgedStanzas = @[];
    }
}

#pragma mark XMPPStanzaHandler

- (void)handleStanza:(PXElement *)stanza completion:(void (^)(NSError *))completion
{
    if ([stanza.namespace isEqualToString:[XMPPStreamFeatureStreamManagement namespace]]) {

        if ([stanza.name isEqualToString:@"enabled"]) {

            _id = [stanza valueForAttribute:@"id"];
            _resumable = [[stanza valueForAttribute:@"resume"] boolValue];

            _enabled = YES;
            _resumed = NO;
            _numberOfSentStanzas = 0;
            _numberOfReceivedStanzas = 0;
            _numberOfAcknowledgedStanzas = 0;
            _unacknowledgedStanzas = @[];

            [self.delegate streamFeatureDidSucceedNegotiation:self];

        } else if ([stanza.name isEqualToString:@"resumed"]) {

            NSString *previd = [stanza valueForAttribute:@"previd"];
            if ([previd isEqualToString:_id]) {

                _resumed = YES;

                NSString *value = [stanza valueForAttribute:@"h"];
                if (value) {
                    NSUInteger h = [value integerValue];
                    [self xmpp_updateWithNumberOfAcknowledgedStanzas:h];
                    [self xmpp_resendPendingStanzas];
                }
                [self.delegate streamFeatureDidSucceedNegotiation:self];
            } else {
                NSString *errorMessage = [NSString stringWithFormat:@"Failed to resume stream. Server responded with previd == '%@', but the previd should be '%@'.", previd, _id];
                NSError *error = [NSError errorWithDomain:XMPPErrorDomain
                                                     code:XMPPErrorCodeInvalidState
                                                 userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
                [self.delegate streamFeature:self didFailNegotiationWithError:error];
            }

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

- (void)xmpp_enable
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"enable"
                                                        namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                           prefix:nil];
    [request.root setValue:@"true" forAttribute:@"resume"];

    _resumed = NO;

    [self.stanzaHandler handleStanza:request.root
                          completion:^(NSError *error) {
                              if (error) {
                                  DDLogError(@"Failed to enable stream management with error: %@", [error localizedDescription]);
                              }
                          }];
}

- (void)xmpp_resume
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"resume"
                                                        namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                           prefix:nil];
    [request.root setValue:_id forAttribute:@"previd"];
    [request.root setValue:[@(_numberOfReceivedStanzas) stringValue] forAttribute:@"h"];

    _resumed = NO;

    [self.stanzaHandler handleStanza:request.root
                          completion:^(NSError *error) {
                              if (error) {
                                  DDLogError(@"Failed to send resume with error: %@", [error localizedDescription]);
                              }
                          }];
}

- (void)xmpp_updateWithNumberOfAcknowledgedStanzas:(NSUInteger)numberOfAcknowledgedStanzas
{
    if (_numberOfAcknowledgedStanzas > numberOfAcknowledgedStanzas ||
        _numberOfSentStanzas < numberOfAcknowledgedStanzas) {

        DDLogWarn(@"Received invalid ack (%ld). Stream has sent (%ld) stanzas and (%ld) have already been acknowledged.",
                  (unsigned long)numberOfAcknowledgedStanzas,
                  (unsigned long)_numberOfSentStanzas,
                  (unsigned long)_numberOfAcknowledgedStanzas);

    } else {
        NSUInteger diff = numberOfAcknowledgedStanzas - _numberOfAcknowledgedStanzas;

        if (diff > 0) {
            NSArray *acknowledgedStanzas = [_unacknowledgedStanzas subarrayWithRange:NSMakeRange(0, diff)];
            for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in acknowledgedStanzas) {
                if (wrapper.acknowledgement) {
                    wrapper.acknowledgement(nil);
                }
            }

            _unacknowledgedStanzas = [_unacknowledgedStanzas subarrayWithRange:NSMakeRange(diff, [_unacknowledgedStanzas count] - diff)];
            _numberOfAcknowledgedStanzas = numberOfAcknowledgedStanzas;

            DDLogInfo(@"Acknowledged (%ld) of (%ld) stanzas.", (unsigned long)_numberOfAcknowledgedStanzas, (unsigned long)_numberOfSentStanzas);
        }
    }
}

- (void)xmpp_resendPendingStanzas
{
    if ([_unacknowledgedStanzas count] > 0) {
        DDLogInfo(@"Resending (%ld) unacknowledged stanzas.", (unsigned long)[_unacknowledgedStanzas count]);
        for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in _unacknowledgedStanzas) {
            [self.stanzaHandler handleStanza:wrapper.stanza
                                  completion:^(NSError *error) {
                                      if (error) {
                                          DDLogError(@"Failed to resend pending stanza with error: %@", [error localizedDescription]);
                                      }
                                  }];
        }
    }
}

@end

#pragma mark -

@implementation XMPPStreamFeatureStreamManagement_Stanza
@end
