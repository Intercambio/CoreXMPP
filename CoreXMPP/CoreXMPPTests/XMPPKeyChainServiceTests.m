//
//  XMPPKeyChainServiceTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 19.02.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPTestCase.h"

@interface XMPPKeyChainServiceTests : XMPPTestCase

@end

@implementation XMPPKeyChainServiceTests

- (void)testAddAndRemoveIdentity
{
    XMPPKeyChainService *keyChain = [[XMPPKeyChainService alloc] initWithServiceName:self.keyChainServiceName];
    assertThat([keyChain identities], hasCountOf(0));

    [keyChain addIdentitiyWithJID:JID(@"romeo@example.com")];
    assertThat([keyChain identities], hasCountOf(1));
    assertThat([keyChain identities], contains(JID(@"romeo@example.com"), nil));

    [keyChain addIdentitiyWithJID:JID(@"juliet@example.com")];
    assertThat([keyChain identities], hasCountOf(2));
    assertThat([keyChain identities], contains(JID(@"romeo@example.com"), JID(@"juliet@example.com"), nil));

    [keyChain removeIdentityWithJID:JID(@"romeo@example.com")];
    assertThat([keyChain identities], hasCountOf(1));
    assertThat([keyChain identities], contains(JID(@"juliet@example.com"), nil));

    [keyChain removeIdentityWithJID:JID(@"juliet@example.com")];
    assertThat([keyChain identities], hasCountOf(0));
}

- (void)testItemAttributes
{
    XMPPKeyChainService *keyChain = [[XMPPKeyChainService alloc] initWithServiceName:self.keyChainServiceName];
    assertThat([keyChain identities], hasCountOf(0));

    XMPPKeyChainItemAttributes *attributes = [keyChain attributesForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(attributes, nilValue());

    [keyChain addIdentitiyWithJID:JID(@"romeo@example.com")];
    attributes = [keyChain attributesForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(attributes, notNilValue());
    assertThatBool(attributes.suspended, isTrue());
    assertThat(attributes.options, equalTo(@{}));

    XMPPKeyChainItemAttributes *newAttributes = [[XMPPKeyChainItemAttributes alloc] initWithOptions:@{ @"foo" : @"bar" }
                                                                                          suspended:NO];
    [keyChain setAttributes:newAttributes forIdentityWithJID:JID(@"romeo@example.com")];

    attributes = [keyChain attributesForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(attributes, notNilValue());
    assertThatBool(attributes.suspended, isFalse());
    assertThat(attributes.options, equalTo(@{ @"foo" : @"bar" }));

    [keyChain removeIdentityWithJID:JID(@"romeo@example.com")];
    attributes = [keyChain attributesForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(attributes, nilValue());
}

- (void)testItemPassword
{
    XMPPKeyChainService *keyChain = [[XMPPKeyChainService alloc] initWithServiceName:self.keyChainServiceName];
    assertThat([keyChain identities], hasCountOf(0));

    NSString *password = [keyChain passwordForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(password, nilValue());

    [keyChain addIdentitiyWithJID:JID(@"romeo@example.com")];
    password = [keyChain passwordForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(password, nilValue());

    [keyChain setPassword:@"123" forIdentityWithJID:JID(@"romeo@example.com")];
    password = [keyChain passwordForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(password, equalTo(@"123"));

    [keyChain setPassword:nil forIdentityWithJID:JID(@"romeo@example.com")];
    password = [keyChain passwordForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(password, nilValue());
}

- (void)testInfluenceBetweenAttributesAndPassword
{
    XMPPKeyChainService *keyChain = [[XMPPKeyChainService alloc] initWithServiceName:self.keyChainServiceName];

    [keyChain addIdentitiyWithJID:JID(@"romeo@example.com")];

    XMPPKeyChainItemAttributes *newAttributes = [[XMPPKeyChainItemAttributes alloc] initWithOptions:@{ @"foo" : @"bar" }
                                                                                          suspended:NO];
    [keyChain setAttributes:newAttributes forIdentityWithJID:JID(@"romeo@example.com")];
    [keyChain setPassword:@"123" forIdentityWithJID:JID(@"romeo@example.com")];

    XMPPKeyChainItemAttributes *attributes = [keyChain attributesForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(attributes, notNilValue());
    assertThatBool(attributes.suspended, isFalse());
    assertThat(attributes.options, equalTo(@{ @"foo" : @"bar" }));

    NSString *password = [keyChain passwordForIdentityWithJID:JID(@"romeo@example.com")];
    assertThat(password, equalTo(@"123"));
}

@end
