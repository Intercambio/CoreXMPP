//
//  XMPPStreamFeatureStreamManagement.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <PureXML/PureXML.h>

#import "XMPPError.h"
#import "XMPPStreamFeatureStreamManagement.h"

@interface XMPPStreamFeatureStreamManagement_Stanza : NSObject
@property (nonatomic, strong) PXDocument *document;
@property (nonatomic, strong) void (^acknowledgement)(NSError *error);
@end

#pragma mark -

static DDLogLevel ddLogLevel = DDLogLevelWarning;

@interface XMPPStreamFeatureStreamManagement () {
    BOOL _enabled;
    BOOL _resumable;
    BOOL _resumed;
    NSString *_id;
    NSUInteger _numberOfReceivedDocuments;
    NSUInteger _numberOfSentDocuments;
    NSUInteger _numberOfAcknowledgedDocuments;
    NSArray *_unacknowledgedDocuments;
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

+ (NSString *)namespace
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
@synthesize numberOfReceivedDocuments = _numberOfReceivedDocuments;
@synthesize numberOfSentDocuments = _numberOfSentDocuments;
@synthesize numberOfAcknowledgedDocuments = _numberOfAcknowledgedDocuments;

- (NSArray *)unacknowledgedDocuments
{
    NSMutableArray *unacknowledgedDocuments = [[NSMutableArray alloc] init];
    if (_unacknowledgedDocuments) {
        for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in _unacknowledgedDocuments) {
            [unacknowledgedDocuments addObject:wrapper.document];
        }
    }
    return unacknowledgedDocuments;
}

- (void)didSentDocument:(PXDocument *)document acknowledgement:(void (^)(NSError *error))acknowledgement;
{
    [self willChangeValueForKey:@"numberOfSentDocuments"];
    [self willChangeValueForKey:@"unacknowledgedDocuments"];

    XMPPStreamFeatureStreamManagement_Stanza *wrapper = [[XMPPStreamFeatureStreamManagement_Stanza alloc] init];
    wrapper.document = document;
    wrapper.acknowledgement = acknowledgement;

    _numberOfSentDocuments += 1;
    _unacknowledgedDocuments = [_unacknowledgedDocuments arrayByAddingObject:wrapper];

    [self didChangeValueForKey:@"unacknowledgedDocuments"];
    [self didChangeValueForKey:@"numberOfSentDocuments"];

    if (wrapper.acknowledgement) {
        [self requestAcknowledgement];
    }
}

- (void)didHandleReceviedDocument:(PXDocument *)document
{
    [self willChangeValueForKey:@"numberOfReceivedDocuments"];

    _numberOfReceivedDocuments += 1;

    [self didChangeValueForKey:@"numberOfReceivedDocuments"];
}

- (void)requestAcknowledgement
{
    PXDocument *response = [[PXDocument alloc] initWithElementName:@"r"
                                                         namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                            prefix:nil];
    [self.delegate streamFeature:self handleDocument:response];
}

- (void)sendAcknowledgement
{
    PXDocument *response = [[PXDocument alloc] initWithElementName:@"a"
                                                         namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                            prefix:nil];
    [response.root setValue:[@(_numberOfReceivedDocuments) stringValue] forAttribute:@"h"];
    [self.delegate streamFeature:self handleDocument:response];
}

- (void)cancelUnacknowledgedDocuments
{
    if ([_unacknowledgedDocuments count] > 0) {
        DDLogInfo(@"Canceling (%ld) unacknowledged stanzas.", (unsigned long)[_unacknowledgedDocuments count]);
        NSError *error = [NSError errorWithDomain:XMPPDispatcherErrorDomain
                                             code:XMPPDispatcherErrorCodeNotConnected
                                         userInfo:nil];
        for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in _unacknowledgedDocuments) {
            if (wrapper.acknowledgement) {
                wrapper.acknowledgement(error);
            }
        }
        _unacknowledgedDocuments = @[];
    }
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    PXElement *stanza = document.root;

    if ([stanza.namespace isEqualToString:[XMPPStreamFeatureStreamManagement namespace]]) {

        if ([stanza.name isEqualToString:@"enabled"]) {

            _id = [stanza valueForAttribute:@"id"];
            _resumable = [[stanza valueForAttribute:@"resume"] boolValue];

            _enabled = YES;
            _resumed = NO;
            _numberOfSentDocuments = 0;
            _numberOfReceivedDocuments = 0;
            _numberOfAcknowledgedDocuments = 0;
            _unacknowledgedDocuments = @[];

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

    return YES;
}

#pragma mark -

- (void)xmpp_enable
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"enable"
                                                        namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                           prefix:nil];
    [request.root setValue:@"true" forAttribute:@"resume"];

    _resumed = NO;
    [self.delegate streamFeature:self handleDocument:request];
}

- (void)xmpp_resume
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"resume"
                                                        namespace:[XMPPStreamFeatureStreamManagement namespace]
                                                           prefix:nil];
    [request.root setValue:_id forAttribute:@"previd"];
    [request.root setValue:[@(_numberOfReceivedDocuments) stringValue] forAttribute:@"h"];

    _resumed = NO;
    [self.delegate streamFeature:self handleDocument:request];
}

- (void)xmpp_updateWithNumberOfAcknowledgedStanzas:(NSUInteger)numberOfAcknowledgedStanzas
{
    if (_numberOfAcknowledgedDocuments > numberOfAcknowledgedStanzas ||
        _numberOfSentDocuments < numberOfAcknowledgedStanzas) {

        DDLogWarn(@"Received invalid ack (%ld). Stream has sent (%ld) stanzas and (%ld) have already been acknowledged.",
                  (unsigned long)numberOfAcknowledgedStanzas,
                  (unsigned long)_numberOfSentDocuments,
                  (unsigned long)_numberOfAcknowledgedDocuments);

    } else {
        NSUInteger diff = numberOfAcknowledgedStanzas - _numberOfAcknowledgedDocuments;

        if (diff > 0) {
            NSArray *acknowledgedStanzas = [_unacknowledgedDocuments subarrayWithRange:NSMakeRange(0, diff)];
            for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in acknowledgedStanzas) {
                if (wrapper.acknowledgement) {
                    wrapper.acknowledgement(nil);
                }
            }

            _unacknowledgedDocuments = [_unacknowledgedDocuments subarrayWithRange:NSMakeRange(diff, [_unacknowledgedDocuments count] - diff)];
            _numberOfAcknowledgedDocuments = numberOfAcknowledgedStanzas;

            DDLogInfo(@"Acknowledged (%ld) of (%ld) stanzas.", (unsigned long)_numberOfAcknowledgedDocuments, (unsigned long)_numberOfSentDocuments);
        }
    }
}

- (void)xmpp_resendPendingStanzas
{
    if ([_unacknowledgedDocuments count] > 0) {
        DDLogInfo(@"Resending (%ld) unacknowledged stanzas.", (unsigned long)[_unacknowledgedDocuments count]);
        for (XMPPStreamFeatureStreamManagement_Stanza *wrapper in _unacknowledgedDocuments) {
            [self.delegate streamFeature:self handleDocument:wrapper.document];
        }
    }
}

@end

#pragma mark -

@implementation XMPPStreamFeatureStreamManagement_Stanza
@end
