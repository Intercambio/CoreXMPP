//
//  XMPPDataFormFieldTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPDataFormFieldTests : XMPPTestCase

@end

@implementation XMPPDataFormFieldTests

#pragma mark Tests

- (void)testElementSubclass
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    assertThat(document.root, isA([XMPPDataFormField class]));
}

- (void)testFieldIdentifier
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormField *field = (XMPPDataFormField *)document.root;

    field.identifier = @"123";
    assertThat([field valueForAttribute:@"identifier"], equalTo(@"123"));

    [field setValue:@"234" forAttribute:@"identifier"];
    assertThat(field.identifier, equalTo(@"234"));

    field.identifier = nil;
    assertThat([field valueForAttribute:@"identifier"], nilValue());
}

- (void)testFieldType
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormField *field = (XMPPDataFormField *)document.root;

    field.type = XMPPDataFormFieldTypeBoolean;
    assertThat([field valueForAttribute:@"type"], equalTo(@"boolean"));

    [field setValue:@"jid-multi" forAttribute:@"type"];
    assertThatInt(field.type, equalToInt(XMPPDataFormFieldTypeJIDMulti));

    field.type = XMPPDataFormFieldTypeUndefined;
    assertThat([field valueForAttribute:@"type"], nilValue());
}

- (void)testLabel
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormField *field = (XMPPDataFormField *)document.root;

    field.label = @"Some Data";
    assertThat([field valueForAttribute:@"label"], equalTo(@"Some Data"));

    [field setValue:@"More Data" forAttribute:@"label"];
    assertThat(field.label, equalTo(@"More Data"));

    field.label = nil;
    assertThat([field valueForAttribute:@"label"], nilValue());
}

- (void)testText
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormField *field = (XMPPDataFormField *)document.root;

    [field addElementWithName:@"description" namespace:@"jabber:x:data" content:@"Add something …"];
    assertThat(field.text, equalTo(@"Add something …"));

    field.text = @"Please add something.";
    NSArray *descriptionElements = [field nodesForXPath:@"./x:description" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    assertThat(descriptionElements, hasCountOf(1));

    NSString *text = [[descriptionElements firstObject] stringValue];
    assertThat(text, equalTo(@"Please add something."));

    field.text = nil;
    descriptionElements = [field nodesForXPath:@"./x:description" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    assertThat(descriptionElements, hasCountOf(0));
}

- (void)testRequired
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormField *field = (XMPPDataFormField *)document.root;

    assertThatBool(field.required, isFalse());

    [field addElementWithName:@"required" namespace:@"jabber:x:data" content:nil];
    assertThatBool(field.required, isTrue());

    field.required = NO;
    NSArray *requiredElements = [field nodesForXPath:@"./x:required" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    assertThat(requiredElements, hasCountOf(0));

    field.required = YES;
    requiredElements = [field nodesForXPath:@"./x:required" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    assertThat(requiredElements, hasCountOf(1));
}

- (void)testManageOptions
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"field" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormField *field = (XMPPDataFormField *)document.root;

    assertThat(field.options, hasCountOf(0));

    [field addElementWithName:@"option" namespace:@"jabber:x:data" content:nil];
    [field addElementWithName:@"option" namespace:@"jabber:x:data" content:nil];

    assertThat(field.options, hasCountOf(2));

    for (XMPPDataFormOption *option in field.options) {
        [field removeOption:option];
    }

    assertThat(field.options, hasCountOf(0));

    XMPPDataFormOption *option = [field addOptionWithLabel:@"#1"];
    assertThat(option.label, equalTo(@"#1"));
    assertThat(field.options, contains(option, nil));
}

@end
