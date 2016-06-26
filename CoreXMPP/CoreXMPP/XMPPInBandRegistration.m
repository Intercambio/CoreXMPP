//
//  XMPPInBandRegistration.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPInBandRegistration.h"

NSString * const XMPPInBandRegistrationNamespace = @"http://jabber.org/features/iq-register";

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
    PXDocument *request = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *iq = request.root;
    
    [iq setValue:@"get" forAttribute:@"type"];
    [iq setValue:hostname forAttribute:@"to"];
    [iq addElementWithName:@"query" namespace:@"jabber:iq:register" content:nil];
    
    [self.delegate streamFeature:self handleDocument:request];
}

#pragma mark Handle Document

- (BOOL)handleDocument:(PXDocument *)document error:(NSError **)error
{
    return YES;
}

@end
