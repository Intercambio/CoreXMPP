//
//  XMPPDataFormField.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPDataFormField.h"
#import "XMPPJID.h"

@interface XMPPDataFormField ()
@property (nonatomic, readwrite) NSArray<NSString *> *valueStrings;
@end

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

#pragma mark Manage Value

- (id)value
{
    switch (self.type) {
    case XMPPDataFormFieldTypeJIDMulti:
    case XMPPDataFormFieldTypeListMulti:
    case XMPPDataFormFieldTypeTextMulti:
        return [self multiValue];

    default:
        return [self singleValue];
    }
}

- (void)setValue:(id)value
{
    switch (self.type) {
    case XMPPDataFormFieldTypeJIDMulti:
    case XMPPDataFormFieldTypeListMulti:
    case XMPPDataFormFieldTypeTextMulti:
        [self setMultiValue:value];
        break;

    default:
        [self setSingleValue:value];
        break;
    }
}

- (id)singleValue
{
    NSString *string = [self.valueStrings firstObject];
    return string ? [self valueFromString:string] : nil;
}

- (void)setSingleValue:(id)value
{
    if (value) {
        [self setMultiValue:@[ value ]];
    } else {
        self.valueStrings = nil;
    }
}

- (NSArray *)multiValue
{
    NSMutableArray *values = [[NSMutableArray alloc] init];
    for (NSString *string in self.valueStrings) {
        id value = [self valueFromString:string];
        if (value) {
            [values addObject:value];
        }
    }
    return values;
}

- (void)setMultiValue:(id)values
{
    NSMutableArray *strings = [[NSMutableArray alloc] init];
    if ([values conformsToProtocol:@protocol(NSFastEnumeration)]) {
        for (id value in values) {
            NSString *string = [self stringFromValue:value];
            [strings addObject:string];
        }
    }
    self.valueStrings = strings;
}

- (id)valueFromString:(NSString *)string
{
    switch (self.type) {
    case XMPPDataFormFieldTypeBoolean:
        return @([string boolValue]);
        break;

    case XMPPDataFormFieldTypeJIDMulti:
    case XMPPDataFormFieldTypeJIDSingle:
        return [XMPPJID JIDFromString:string];
        break;

    default:
        return string;
    }
}

- (NSString *)stringFromValue:(id)value
{
    switch (self.type) {
    case XMPPDataFormFieldTypeBoolean:
        if ([value respondsToSelector:@selector(boolValue)]) {
            return [value boolValue] ? @"true" : @"false";
        } else {
            return nil;
        }

    case XMPPDataFormFieldTypeJIDMulti:
    case XMPPDataFormFieldTypeJIDSingle:
        if ([value isKindOfClass:[XMPPJID class]]) {
            return [(XMPPJID *)value stringValue];
        } else {
            return nil;
        }

    default:
        if ([value isKindOfClass:[NSString class]]) {
            return value;
        } else if ([value respondsToSelector:@selector(stringValue)]) {
            return [value stringValue];
        } else {
            return nil;
        }
    }
}

- (void)setValueStrings:(NSArray<NSString *> *)valueStrings
{
    NSArray *elements = [self nodesForXPath:@"./x:value" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    for (PXElement *element in elements) {
        [element removeFromParent];
    }

    for (NSString *string in valueStrings) {
        [self addElementWithName:@"value" namespace:@"jabber:x:data" content:string];
    }
}

- (NSArray<NSString *> *)valueStrings
{
    NSArray *elements = [self nodesForXPath:@"./x:value" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    NSMutableArray *valueStrings = [[NSMutableArray alloc] init];
    for (PXElement *value in elements) {
        NSString *string = value.stringValue;
        if (string) {
            [valueStrings addObject:string];
        }
    }
    return valueStrings;
}

@end
