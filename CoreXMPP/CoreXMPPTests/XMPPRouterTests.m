//
//  XMPPRouterTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPTestCase.h"

@interface XMPPRouterTests : XMPPTestCase

@end

@implementation XMPPRouterTests

- (void)testModuleManagement
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [router addModule:module];

    assertThat(router.modules, contains(module, nil));
    assertThat(module.router, is(router));

    [router removeModule:module];

    assertThat(router.modules, isNot(contains(module, nil)));
    assertThat(module.router, nilValue());
}

- (void)testManageConnections
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [router addConnection:connection];

    assertThat(router.connections, contains(connection, nil));
    assertThat(connection.router, is(router));

    [router removeConnection:connection];

    assertThat(router.connections, isNot(contains(connection, nil)));
    assertThat(connection.router, nilValue());
}

- (void)testIncomingMessage
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [router addModule:module];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [module onMessage:^(PXElement *message) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([message stringValue], equalTo(@"Hello!"));
        [expectation fulfill];
    }];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[from stringValue] forAttribute:@"from"];
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    [router handleStanza:message];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingMessage
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.JIDs = @[ JID(@"romeo@localhost") ];
    [router addConnection:connection];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[from stringValue] forAttribute:@"from"];
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [connection onHandleStanza:^(PXElement *message) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([message stringValue], equalTo(@"Hello!"));
        [expectation fulfill];
    }];

    [router handleMessage:message];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testIncomingPresence
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [router addModule:module];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Presence"];
    [module onPresence:^(PXElement *presense) {
        assertThat(presense, equalTo(PXQN(@"jabber:client", @"presence")));
        [expectation fulfill];
    }];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];
    [presence setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];

    [router handleStanza:presence];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingPresence
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.JIDs = @[ JID(@"romeo@localhost") ];
    [router addConnection:connection];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];
    [presence setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Presence"];
    [connection onHandleStanza:^(PXElement *presence) {
        assertThat(presence, equalTo(PXQN(@"jabber:client", @"presence")));
        [expectation fulfill];
    }];

    [router handlePresence:presence];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testIncomingIQRequest
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [router addModule:module];
    [router setModule:module forIQQuery:PXQN(@"foo:bar", @"query")];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Request"];
    [module onIQRequest:^(PXElement *stanza, id<XMPPIQHandler> resultHandler) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        [expectation fulfill];
    }];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    [router handleStanza:request];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingIQRequest
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.JIDs = @[ JID(@"romeo@localhost") ];
    [router addConnection:connection];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Request"];
    [connection onHandleStanza:^(PXElement *stanza) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        [expectation fulfill];
    }];

    [router handleIQRequest:request resultHandler:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testIQRequestResponse
{
    XMPPRouter *router = [[XMPPRouter alloc] init];

    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.JIDs = @[ JID(@"romeo@localhost") ];
    [router addConnection:connection];

    [connection onHandleStanza:^(PXElement *stanza) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        XMPPJID *from = [stanza valueForAttribute:@"to"];
        XMPPJID *to = [stanza valueForAttribute:@"from"];
        NSString *_id = [stanza valueForAttribute:@"id"];

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
        PXElement *response = doc.root;
        [response setValue:from forAttribute:@"from"];
        [response setValue:to forAttribute:@"to"];
        [response setValue:@"result" forAttribute:@"type"];
        [response setValue:_id forAttribute:@"id"];

        [connection.router handleStanza:response];
    }];

    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    [router addModule:module];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [module onIQResponse:^(PXElement *stanza) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        [expectation fulfill];
    }];

    [module sendIQRequest:request];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
