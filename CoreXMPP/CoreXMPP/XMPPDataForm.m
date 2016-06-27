//
//  XMPPDataForm.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 26.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDataForm.h"

@implementation XMPPDataForm

+ (void)load
{
    [PXDocument registerElementClass:[XMPPDataForm class]
                    forQualifiedName:PXQN(@"jabber:x:data", @"x")];
}

#pragma mark Properties

- (XMPPDataFormType)type
{
    NSString *typeString = [self valueForAttribute:@"type"];

    if ([typeString isEqualToString:@"cancel"]) {
        return XMPPDataFormTypeCancel;
    } else if ([typeString isEqualToString:@"form"]) {
        return XMPPDataFormTypeForm;
    } else if ([typeString isEqualToString:@"result"]) {
        return XMPPDataFormTypeResult;
    } else if ([typeString isEqualToString:@"submit"]) {
        return XMPPDataFormTypeSubmit;
    } else {
        return XMPPDataFormTypeUndefined;
    }
}

- (void)setType:(XMPPDataFormType)type
{
    switch (type) {
    case XMPPDataFormTypeCancel:
        [self setValue:@"cancel" forAttribute:@"type"];
        break;

    case XMPPDataFormTypeForm:
        [self setValue:@"form" forAttribute:@"type"];
        break;

    case XMPPDataFormTypeResult:
        [self setValue:@"result" forAttribute:@"type"];
        break;

    case XMPPDataFormTypeSubmit:
        [self setValue:@"submit" forAttribute:@"type"];
        break;

    default:
        [self setValue:nil forAttribute:@"type"];
        break;
    }
}

- (NSString *)title
{
    NSArray *nodes = [self nodesForXPath:@"./x:title" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    return [[nodes firstObject] stringValue];
}

- (void)setTitle:(NSString *)title
{
    NSArray *nodes = [self nodesForXPath:@"./x:title" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    for (PXElement *element in nodes) {
        [element removeFromParent];
    }

    if (title) {
        [self addElementWithName:@"title" namespace:@"jabber:x:data" content:title];
    }
}

- (NSString *)instructions
{
    NSArray *nodes = [self nodesForXPath:@"./x:instructions" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    return [[nodes firstObject] stringValue];
}

- (void)setInstructions:(NSString *)instructions
{
    NSArray *nodes = [self nodesForXPath:@"./x:instructions" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    for (PXElement *element in nodes) {
        [element removeFromParent];
    }

    if (instructions) {
        [self addElementWithName:@"instructions" namespace:@"jabber:x:data" content:instructions];
    }
}

- (NSString *)namespace
{
    for (XMPPDataFormField *field in self.fields) {
        if (field.type == XMPPDataFormFieldTypeHidden &&
            [field.identifier isEqualToString:@"FORM_TYPE"] &&
            [field.value isKindOfClass:[NSString class]]) {
            return field.value;
        }
    }

    return nil;
}

- (void)setNamespace:(NSString *)namespace
{
    for (XMPPDataFormField *field in self.fields) {
        if (field.type == XMPPDataFormFieldTypeHidden &&
            [field.identifier isEqualToString:@"FORM_TYPE"]) {
            [self removeField:field];
        }
    }

    if (namespace) {
        XMPPDataFormField *field = [self addFieldWithType:XMPPDataFormFieldTypeHidden identifier:@"FORM_TYPE"];
        field.value = namespace;
    }
}

#pragma mark Manage Fields

- (NSArray<XMPPDataFormField *> *)fields
{
    return [self nodesForXPath:@"./x:field" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
}

- (XMPPDataFormField *)addFieldWithType:(XMPPDataFormFieldType)type
                             identifier:(NSString *)identifier
{
    XMPPDataFormField *field = (XMPPDataFormField *)[self addElementWithName:@"field"
                                                                   namespace:@"jabber:x:data"
                                                                     content:nil];
    if ([field isKindOfClass:[XMPPDataFormField class]]) {
        field.type = type;
        field.identifier = identifier;
    }
    return field;
}

- (void)removeField:(XMPPDataFormField *)field
{
    if (field.parent == self) {
        [field removeFromParent];
    }
}

@end
