//
//  XMPPQueryRegister.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 28.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

@import Foundation;
@import XMPPFoundation;

#import "XMPPQueryRegister.h"

NSString *const XMPPQueryRegisterFormIdentifier = @"de.tobias-kraentzer.XMPPQueryRegister";

@implementation XMPPQueryRegister

+ (void)load
{
    [PXDocument registerElementClass:[XMPPQueryRegister class]
                    forQualifiedName:PXQN(@"jabber:iq:register", @"query")];
}

+ (NSArray *)fields
{
    return @[ @"username",
              @"nick",
              @"username",
              @"password",
              @"name",
              @"first",
              @"last",
              @"email",
              @"address",
              @"city",
              @"state",
              @"zip",
              @"phone",
              @"url",
              @"date",
              @"misc",
              @"text",
              @"key" ];
}

+ (XMPPDataFormFieldType)fieldTypeForField:(NSString *)field
{
    if ([field isEqualToString:@"password"]) {
        return XMPPDataFormFieldTypeTextPrivate;
    } else if ([field isEqualToString:@"key"]) {
        return XMPPDataFormFieldTypeHidden;
    } else {
        return XMPPDataFormFieldTypeTextSingle;
    }
}

#pragma mark Parameters

- (PXDocument *)registrationForm
{
    NSDictionary *ns = @{ @"register" : @"jabber:iq:register",
                          @"data" : @"jabber:x:data" };

    PXElement *formElement = [[self nodesForXPath:@"./data:x" usingNamespaces:ns] firstObject];
    if (formElement) {
        return [[PXDocument alloc] initWithElement:formElement];
    } else {
        PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
        XMPPDataForm *form = (XMPPDataForm *)document.root;
        form.type = XMPPDataFormTypeForm;
        form.identifier = XMPPQueryRegisterFormIdentifier;

        [self enumerateElementsUsingBlock:^(PXElement *element, BOOL *stop) {
            if ([element.namespace isEqualToString:@"jabber:iq:register"]) {

                if ([element.name isEqualToString:@"instructions"]) {
                    form.instructions = element.stringValue;
                }

                if ([[[self class] fields] containsObject:element.name]) {
                    XMPPDataFormField *field = [form addFieldWithType:[[self class] fieldTypeForField:element.name]
                                                           identifier:element.name];
                    field.value = [element stringValue];
                }
            }
        }];

        return document;
    }
}

- (void)setRegistrationForm:(PXDocument *)registrationForm
{
    NSDictionary *ns = @{ @"register" : @"jabber:iq:register",
                          @"data" : @"jabber:x:data" };

    for (PXElement *element in [self nodesForXPath:@"./data:x" usingNamespaces:ns]) {
        [element removeFromParent];
    }

    if ([registrationForm.root isKindOfClass:[XMPPDataForm class]]) {

        XMPPDataForm *form = (XMPPDataForm *)registrationForm.root;
        if ([form.identifier isEqualToString:XMPPQueryRegisterFormIdentifier]) {

            XMPPDataForm *form = (XMPPDataForm *)registrationForm.root;

            for (XMPPDataFormField *field in form.fields) {
                if ([[[self class] fields] containsObject:field.identifier]) {
                    NSString *stringValue = nil;
                    id value = field.value;
                    if ([value isKindOfClass:[NSString class]]) {
                        stringValue = value;
                    } else if ([value respondsToSelector:@selector(stringValue)]) {
                        stringValue = [value stringValue];
                    }
                    [self addElementWithName:field.identifier
                                   namespace:@"jabber:iq:register"
                                     content:stringValue];
                }
            }
        } else {
            [self addElement:form];
        }
    }
}

@end
