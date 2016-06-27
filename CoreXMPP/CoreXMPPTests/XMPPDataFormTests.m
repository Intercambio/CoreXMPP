//
//  XMPPDataFormTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 26.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPDataFormTests : XMPPTestCase

@end

@implementation XMPPDataFormTests

#pragma mark Tests

- (void)testElementSubclass
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    assertThat(document.root, isA([XMPPDataForm class]));
}

- (void)testFormType
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)document.root;

    form.type = XMPPDataFormTypeForm;
    assertThat([form valueForAttribute:@"type"], equalTo(@"form"));

    [form setValue:@"submit" forAttribute:@"type"];
    assertThatInt(form.type, equalToInt(XMPPDataFormTypeSubmit));

    form.type = XMPPDataFormTypeUndefined;
    assertThat([form valueForAttribute:@"type"], nilValue());
}

- (void)testFormTitle
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)document.root;

    [form addElementWithName:@"title" namespace:@"jabber:x:data" content:@"My Form"];
    assertThat(form.title, equalTo(@"My Form"));

    form.title = @"Your Form";
    NSArray *titleElements = [form nodesForXPath:@"./x:title" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    assertThat(titleElements, hasCountOf(1));

    NSString *title = [[titleElements firstObject] stringValue];
    assertThat(title, equalTo(@"Your Form"));
}

- (void)testFormInstructions
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)document.root;

    [form addElementWithName:@"instructions" namespace:@"jabber:x:data" content:@"Add your Data."];
    assertThat(form.instructions, equalTo(@"Add your Data."));

    form.instructions = @"Please fillout the form.";
    NSArray *instructionsElements = [form nodesForXPath:@"./x:instructions" usingNamespaces:@{ @"x" : @"jabber:x:data" }];
    assertThat(instructionsElements, hasCountOf(1));

    NSString *instructions = [[instructionsElements firstObject] stringValue];
    assertThat(instructions, equalTo(@"Please fillout the form."));
}

- (void)testManageFields
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)document.root;

    assertThat(form.fields, hasCountOf(0));

    [form addElementWithName:@"field" namespace:@"jabber:x:data" content:nil];
    [form addElementWithName:@"field" namespace:@"jabber:x:data" content:nil];

    assertThat(form.fields, hasCountOf(2));

    for (XMPPDataFormField *field in form.fields) {
        [form removeField:field];
    }

    assertThat(form.fields, hasCountOf(0));

    XMPPDataFormField *field = [form addFieldWithType:XMPPDataFormFieldTypeBoolean identifier:@"123"];
    assertThat(field.identifier, equalTo(@"123"));
    assertThatInt(field.type, equalToInt(XMPPDataFormFieldTypeBoolean));
    assertThat(form.fields, contains(field, nil));
}

- (void)testNamespace
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"x" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataForm *form = (XMPPDataForm *)document.root;

    assertThat(form.namespace, nilValue());

    XMPPDataFormField *field = [form addFieldWithType:XMPPDataFormFieldTypeHidden identifier:@"FORM_TYPE"];
    field.value = @"http://example.com/ns_1";

    assertThat(form.namespace, equalTo(@"http://example.com/ns_1"));

    form.namespace = @"http://example.com/ns_2";

    assertThat([[form.fields firstObject] value], equalTo(@"http://example.com/ns_2"));
    assertThat([[form.fields firstObject] identifier], equalTo(@"FORM_TYPE"));
    assertThatInt([[form.fields firstObject] type], equalToInt(XMPPDataFormFieldTypeHidden));

    form.namespace = nil;

    assertThat(form.fields, hasCountOf(0));
}

@end
