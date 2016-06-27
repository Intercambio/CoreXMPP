//
//  XMPPDataFormOptionTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 27.06.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPDataFormOptionTests : XMPPTestCase

@end

@implementation XMPPDataFormOptionTests

#pragma mark Tests

- (void)testElementSubclass
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"option" namespace:@"jabber:x:data" prefix:nil];
    assertThat(document.root, isA([XMPPDataFormOption class]));
}

- (void)testLabel
{
    PXDocument *document = [[PXDocument alloc] initWithElementName:@"option" namespace:@"jabber:x:data" prefix:nil];
    XMPPDataFormOption *option = (XMPPDataFormOption *)document.root;

    [option setValue:@"Password" forAttribute:@"label"];
    assertThat(option.label, equalTo(@"Password"));

    option.label = @"Your Password";
    assertThat([option valueForAttribute:@"label"], equalTo(@"Your Password"));

    option.label = nil;
    assertThat([option valueForAttribute:@"label"], nilValue());
}

@end
