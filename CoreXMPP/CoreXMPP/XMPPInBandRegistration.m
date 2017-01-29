//
//  XMPPInBandRegistration.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
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

@import Foundation;
@import XMPPFoundation;

#import "XMPPInBandRegistration.h"
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
    return YES;
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

        NSString *username = nil;
        if ([registrationForm.root isKindOfClass:[XMPPDataForm class]]) {
            XMPPDataForm *form = (XMPPDataForm *)[registrationForm root];
            username = [[form fieldWithIdentifier:@"username"] value];
        }

        PXDocument *request = [self registrationSubmitRequestWithHostname:_hostename
                                                         registrationForm:registrationForm];
        [self sendIQRequest:request
                    timeout:60.0
                 completion:^(PXDocument *response, NSError *error) {

                     BOOL success = response != nil;

                     if (success) {
                         if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateInBandRegistration)]) {
                             id<XMPPStreamFeatureDelegateInBandRegistration> delegate = (id<XMPPStreamFeatureDelegateInBandRegistration>)self.delegate;
                             [delegate streamFeature:self didRegisterWithUsername:username hostname:_hostename];
                         }
                     }

                     if (completion) {
                         completion(success, error);
                     }

                     if (success) {
                         [self.delegate streamFeatureDidSucceedNegotiation:self];
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
