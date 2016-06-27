//
//  XMPPDataFormField.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDataFormField.h"

@implementation XMPPDataFormField

+ (void)load
{
    [PXDocument registerElementClass:[XMPPDataFormField class]
                    forQualifiedName:PXQN(@"jabber:x:data", @"field")];
}

#pragma mark Properties

- (NSString *)identifier
{
    return [self valueForAttribute:@"identifier"];
}

- (void)setIdentifier:(NSString *)identifier
{
    [self setValue:identifier forAttribute:@"identifier"];
}

- (XMPPDataFormFieldType)type
{
    NSString *typeString = [self valueForAttribute:@"type"];
    if ([typeString isEqualToString:@"boolean"]) {
        return XMPPDataFormFieldTypeBoolean;
    } else if ([typeString isEqualToString:@"fixed"]) {
        return XMPPDataFormFieldTypeFixed;
    } else if ([typeString isEqualToString:@"hidden"]) {
        return XMPPDataFormFieldTypeHidden;
    } else if ([typeString isEqualToString:@"jid-multi"]) {
        return XMPPDataFormFieldTypeJIDMulti;
    } else if ([typeString isEqualToString:@"jid-single"]) {
        return XMPPDataFormFieldTypeJIDSingle;
    } else if ([typeString isEqualToString:@"list-multi"]) {
        return XMPPDataFormFieldTypeListMulti;
    } else if ([typeString isEqualToString:@"list-single"]) {
        return XMPPDataFormFieldTypeListSingle;
    } else if ([typeString isEqualToString:@"text-multi"]) {
        return XMPPDataFormFieldTypeTextMulti;
    } else if ([typeString isEqualToString:@"text-private"]) {
        return XMPPDataFormFieldTypeTextPrivate;
    } else if ([typeString isEqualToString:@"text-single"]) {
        return XMPPDataFormFieldTypeTextSingle;
    } else {
        return XMPPDataFormFieldTypeBoolean;
    }
}

- (void)setType:(XMPPDataFormFieldType)type
{
    switch (type) {
    case XMPPDataFormFieldTypeBoolean:
        [self setValue:@"boolean" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeFixed:
        [self setValue:@"fixed" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeHidden:
        [self setValue:@"hidden" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeJIDMulti:
        [self setValue:@"jid-multi" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeJIDSingle:
        [self setValue:@"jid-single" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeListMulti:
        [self setValue:@"list-multi" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeListSingle:
        [self setValue:@"list-single" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeTextMulti:
        [self setValue:@"text-multi" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeTextPrivate:
        [self setValue:@"text-private" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeTextSingle:
        [self setValue:@"text-single" forAttribute:@"type"];
        break;

    case XMPPDataFormFieldTypeUndefined:
    default:
        [self setValue:nil forAttribute:@"type"];
        break;
    }
}

- (NSString *)label
{
    return [self valueForAttribute:@"label"];
}

- (void)setLabel:(NSString *)label
{
    [self setValue:label forAttribute:@"label"];
}

- (NSString *)text
{
    NSArray *nodes = [self nodesForXPath:@"./x:description" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    return [[nodes firstObject] stringValue];
}

- (void)setText:(NSString *)text
{
    NSArray *nodes = [self nodesForXPath:@"./x:description" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    for (PXElement *element in nodes) {
        [element removeFromParent];
    }

    if (text) {
        [self addElementWithName:@"description" namespace:@"jabber:x:data" content:text];
    }
}

- (BOOL)required
{
    NSArray *nodes = [self nodesForXPath:@"./x:required" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    return [nodes count] > 0;
}

- (void)setRequired:(BOOL)required
{
    NSArray *nodes = [self nodesForXPath:@"./x:required" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    for (PXElement *element in nodes) {
        [element removeFromParent];
    }

    if (required) {
        [self addElementWithName:@"required" namespace:@"jabber:x:data" content:nil];
    }
}

#pragma mark Manage Options

- (NSArray<XMPPDataFormOption *> *)options
{
    return [self nodesForXPath:@"./x:option" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
}

- (XMPPDataFormOption *)addOptionWithLabel:(NSString *)label
{
    XMPPDataFormOption *option = (XMPPDataFormOption *)[self addElementWithName:@"option" namespace:@"jabber:x:data" content:nil];
    if ([option isKindOfClass:[XMPPDataFormOption class]]) {
        option.label = label;
    }
    return option;
}

- (void)removeOption:(XMPPDataFormOption *)option
{
    if (option.parent == self) {
        [option removeFromParent];
    }
}

@end
