//
//  XMPPStreamFeatureStreamManagement.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 25.01.16.
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

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <PureXML/PureXML.h>

#import "XMPPDispatcherImpl.h"
#import "XMPPError.h"
#import "XMPPStreamFeatureStreamManagement.h"

NSString *const XMPPStreamFeatureStreamManagementNamespace = @"urn:xmpp:sm:3";

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
    return XMPPStreamFeatureStreamManagementNamespace;
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
                                             code:XMPPDispatcherErrorCodeNoRoute
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
    PXElement *element = document.root;

    if ([element.namespace isEqualToString:[XMPPStreamFeatureStreamManagement namespace]]) {

        if ([element.name isEqualToString:@"enabled"]) {

            _id = [element valueForAttribute:@"id"];
            _resumable = [[element valueForAttribute:@"resume"] boolValue];

            _enabled = YES;
            _resumed = NO;
            _numberOfSentDocuments = 0;
            _numberOfReceivedDocuments = 0;
            _numberOfAcknowledgedDocuments = 0;
            _unacknowledgedDocuments = @[];

            [self.delegate streamFeatureDidSucceedNegotiation:self];

        } else if ([element.name isEqualToString:@"resumed"]) {

            NSString *previd = [element valueForAttribute:@"previd"];
            if ([previd isEqualToString:_id]) {

                _resumed = YES;

                NSString *value = [element valueForAttribute:@"h"];
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

        } else if ([element.name isEqualToString:@"failed"]) {

            _enabled = NO;

            __block NSError *error = nil;
            [element enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
                error = [NSError errorWithElement:element];
                *stop = error != nil;
            }];

            if (error == nil) {
                error = [NSError errorWithDomain:XMPPStanzaErrorDomain code:XMPPStanzaErrorCodeUndefinedCondition userInfo:nil];
            }

            [self.delegate streamFeature:self didFailNegotiationWithError:error];

        } else if ([element.name isEqualToString:@"r"]) {

            [self sendAcknowledgement];

        } else if ([element.name isEqualToString:@"a"]) {

            NSString *value = [element valueForAttribute:@"h"];
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
