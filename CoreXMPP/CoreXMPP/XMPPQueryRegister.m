//
//  XMPPQueryRegister.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 28.06.16.
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
