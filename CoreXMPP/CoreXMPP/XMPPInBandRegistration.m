//
//  XMPPInBandRegistration.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPInBandRegistration.h"

NSString *const XMPPInBandRegistrationNamespace = @"http://jabber.org/features/iq-register";

@interface XMPPInBandRegistration () <XMPPRegistrationChallenge> {
    PXDocument *_registrationDocument;
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
    [self requestRegistrationFormFromHost:hostname];
}

- (void)requestRegistrationFormFromHost:(NSString *)hostname
{
    PXDocument *request = [self registrationRequestWithHostname:hostname];
    [self sendIQRequest:request
                timeout:60.0
             completion:^(PXDocument *response, NSError *error) {
                 if (response) {
                     _registrationDocument = [self registrationFormFromResponse:response];
                     if ([self.delegate conformsToProtocol:@protocol(XMPPStreamFeatureDelegateInBandRegistration)]) {
                         id<XMPPStreamFeatureDelegateInBandRegistration> delegate = (id<XMPPStreamFeatureDelegateInBandRegistration>)self.delegate;
                         [delegate streamFeature:self didReceiveRegistrationChallenge:self];
                     }
                 } else {
                     [self.delegate streamFeature:self didFailNegotiationWithError:error];
                 }
             }];
}

#pragma mark XMPPRegistrationChallenge

- (XMPPDataForm *)registrationForm
{
    if ([_registrationDocument.root isKindOfClass:[XMPPDataForm class]]) {
        return (XMPPDataForm *)[[[PXDocument alloc] initWithElement:_registrationDocument.root] root];
    } else {
        return nil;
    }
}

- (void)submitRegistration:(XMPPDataForm *)registrationForm
                completion:(void (^)(BOOL, NSError *))completion
{
}

#pragma mark -

- (PXDocument *)registrationRequestWithHostname:(NSString *)hostname
{
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *iq = request.root;

    [iq setValue:@"get" forAttribute:@"type"];
    [iq setValue:hostname forAttribute:@"to"];
    [iq addElementWithName:@"query" namespace:@"jabber:iq:register" content:nil];

    return request;
}

- (PXDocument *)registrationFormFromResponse:(PXDocument *)response
{
    NSDictionary *ns = @{ @"register" : @"jabber:iq:register",
                          @"data" : @"jabber:x:data" };

    PXElement *formElement = [[response.root nodesForXPath:@"./register:query/data:x" usingNamespaces:ns] firstObject];
    if (formElement) {
        PXDocument *registrationForm = [[PXDocument alloc] initWithElement:formElement];
        return registrationForm;
    }

    PXDocument *registrationForm = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)registrationForm.root;
    form.namespace = @"XMPPInBandRegistration";

    PXElement *queryElement = [[response.root nodesForXPath:@"./register:query" usingNamespaces:ns] firstObject];
    [queryElement enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
        if ([element.namespace isEqualToString:@"jabber:iq:register"]) {
            if ([element.name isEqualToString:@"instructions"]) {
                form.instructions = element.stringValue;
            } else if ([element.name isEqualToString:@"username"]) {
                [form addFieldWithType:XMPPDataFormFieldTypeJIDSingle identifier:@"username"];
            } else if ([element.name isEqualToString:@"password"]) {
                [form addFieldWithType:XMPPDataFormFieldTypeTextPrivate identifier:@"password"];
            } else if ([element.name isEqualToString:@"email"]) {
                [form addFieldWithType:XMPPDataFormFieldTypeTextSingle identifier:@"email"];
            }
        }
    }];

    return registrationForm;
}

@end
