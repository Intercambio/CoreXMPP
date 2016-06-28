//
//  XMPPInBandRegistration.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPInBandRegistration.h"
#import "XMPPDataForm.h"
#import "XMPPQueryRegister.h"

NSString *const XMPPInBandRegistrationNamespace = @"http://jabber.org/features/iq-register";

@interface XMPPInBandRegistration () <XMPPRegistrationChallenge> {
    PXDocument *_registrationDocument;
    NSString *_hostename;
}

@end

@implementation XMPPInBandRegistration

+ (void)load
{
    PXQName *QName = [[PXQName alloc] initWithName:[XMPPInBandRegistration name]
                                         namespace:[XMPPInBandRegistration namespace]];
    [self registerStreamFeatureClass:[XMPPInBandRegistration class]
               forStreamFeatureQName:QName];
}

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return @"register";
}

+ (NSString *)namespace
{
    return XMPPInBandRegistrationNamespace;
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
    _hostename = hostname;
    [self requestRegistrationFormFromHost:hostname];
}

- (void)requestRegistrationFormFromHost:(NSString *)hostname
{
    PXDocument *request = [self registrationFormRequestWithHostname:hostname];
    [self sendIQRequest:request
                timeout:60.0
             completion:^(PXDocument *response, NSError *error) {
                 if (response) {
                     NSDictionary *ns = @{ @"register" : @"jabber:iq:register" };
                     XMPPQueryRegister *query = (XMPPQueryRegister *)[[response.root nodesForXPath:@"./register:query" usingNamespaces:ns] firstObject];
                     if ([query isKindOfClass:[XMPPQueryRegister class]]) {
                         _registrationDocument = [query registrationForm];
                         if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateInBandRegistration)]) {
                             id<XMPPStreamFeatureDelegateInBandRegistration> delegate = (id<XMPPStreamFeatureDelegateInBandRegistration>)self.delegate;
                             [delegate streamFeature:self didReceiveRegistrationChallenge:self];
                         }
                     }
                 } else {
                     [self.delegate streamFeature:self didFailNegotiationWithError:error];
                 }
             }];
}

#pragma mark XMPPRegistrationChallenge

- (PXDocument *)registrationForm
{
    if ([_registrationDocument.root isKindOfClass:[XMPPDataForm class]]) {
        return [[PXDocument alloc] initWithElement:_registrationDocument.root];
    } else {
        return nil;
    }
}

- (void)submitRegistration:(PXDocument *)registrationForm
                completion:(void (^)(BOOL, NSError *))completion
{
    dispatch_async(self.queue ?: dispatch_get_main_queue(), ^{
        PXDocument *request = [self registrationSubmitRequestWithHostname:_hostename
                                                         registrationForm:registrationForm];
        [self sendIQRequest:request
                    timeout:60.0
                 completion:^(PXDocument *response, NSError *error) {
                     if (completion) {
                         completion(response != nil, error);
                     }
                 }];
    });
}

#pragma mark -

- (PXDocument *)registrationFormRequestWithHostname:(NSString *)hostname
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *iq = request.root;

    [iq setValue:@"get" forAttribute:@"type"];
    [iq setValue:hostname forAttribute:@"to"];
    [iq addElementWithName:@"query" namespace:@"jabber:iq:register" content:nil];

    return request;
}

- (PXDocument *)registrationSubmitRequestWithHostname:(NSString *)hostname
                                     registrationForm:(PXDocument *)registrationForm
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *iq = request.root;

    [iq setValue:@"set" forAttribute:@"type"];
    [iq setValue:hostname forAttribute:@"to"];

    XMPPQueryRegister *query = (XMPPQueryRegister *)[iq addElementWithName:@"query" namespace:@"jabber:iq:register" content:nil];
    query.registrationForm = registrationForm;

    return request;
}

@end
