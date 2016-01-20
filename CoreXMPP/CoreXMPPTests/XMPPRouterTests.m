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

#pragma mark Message Handling

- (void)testManagingMessageHandler
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [router addMessageHandler:module];
    assertThat(router.messageHandlers, contains(module, nil));
    
    [router removeMessageHandler:module];
    assertThat(router.messageHandlers, isNot(contains(module, nil)));
}

- (void)testIncomingMessage
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [module onMessage:^(PXElement *message) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([message stringValue], equalTo(@"Hello!"));
        [expectation fulfill];
    }];
    
    [router addMessageHandler:module];
    
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
    
    [router setConnection:connection forJID:JID(@"romeo@localhost")];
    
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
    [connection onHandleStanza:^(PXElement *message, id<XMPPStanzaHandler> responseHandler) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([message stringValue], equalTo(@"Hello!"));
        [expectation fulfill];
    }];
    
    [router handleMessage:message];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark Presence Handling

- (void)testManagingPresenceHandler
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    
    [router addPresenceHandler:module];
    assertThat(router.presenceHandlers, contains(module, nil));
    
    [router removePresenceHandler:module];
    assertThat(router.presenceHandlers, isNot(contains(module, nil)));
}

- (void)testIncomingPresence
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Presence"];
    [module onPresence:^(PXElement *message) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"presence")));
        [expectation fulfill];
    }];
    
    [router addPresenceHandler:module];
    
    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");
    
    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];
    
    [router handleStanza:presence];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingPresence
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    
    [router setConnection:connection forJID:JID(@"romeo@localhost")];
    
    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");
    
    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Presence"];
    [connection onHandleStanza:^(PXElement *message, id<XMPPStanzaHandler> responseHandler) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"presence")));
        [expectation fulfill];
    }];
    
    [router handlePresence:presence];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark IQ Handling

- (void)testManageIQHandler
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [router setIQHandler:module forQuery:PXQN(@"foo:bar", @"query")];
    assertThat(router.IQHandlersByQuery[PXQN(@"foo:bar", @"query")], is(module));
    
    [router removeIQHandlerForQuery:PXQN(@"foo:bar", @"query")];
    assertThat(router.IQHandlersByQuery[PXQN(@"foo:bar", @"query")], nilValue());
}

- (void)testIncomingIQRequest
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    
    [router setIQHandler:module forQuery:PXQN(@"foo:bar", @"query")];
    [router setConnection:connection forJID:JID(@"romeo@localhost")];
    
    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");
    
    [module onIQRequest:^(PXElement *stanza, id<XMPPIQHandler> resultHandler) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        
        NSString *from = [stanza valueForAttribute:@"to"];
        NSString *to = [stanza valueForAttribute:@"from"];
        NSString *_id = [stanza valueForAttribute:@"id"];
        
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
        PXElement *response = doc.root;
        [response setValue:from forAttribute:@"from"];
        [response setValue:to forAttribute:@"to"];
        [response setValue:@"result" forAttribute:@"type"];
        [response setValue:_id forAttribute:@"id"];
        
        [resultHandler handleIQResponse:response];
    }];
    
    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];
    
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [connection onHandleStanza:^(PXElement *message, id<XMPPStanzaHandler> responseHandler) {
        assertThat(message, equalTo(PXQN(@"jabber:client", @"iq")));
        [expectation fulfill];
    }];
    
    [router handleStanza:request];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingIQRequest
{
    XMPPRouter *router = [[XMPPRouter alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    [router setConnection:connection forJID:JID(@"romeo@localhost")];
    connection.stanzaHandler = router;
    
    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");
    
    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];
    
    [connection onHandleStanza:^(PXElement *stanza, id<XMPPStanzaHandler> responseHandler) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        
        NSString *from = [stanza valueForAttribute:@"to"];
        NSString *to = [stanza valueForAttribute:@"from"];
        NSString *_id = [stanza valueForAttribute:@"id"];
        
        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
        PXElement *response = doc.root;
        [response setValue:from forAttribute:@"from"];
        [response setValue:to forAttribute:@"to"];
        [response setValue:@"result" forAttribute:@"type"];
        [response setValue:_id forAttribute:@"id"];
        
        [responseHandler handleStanza:response];
    }];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [module onIQResponse:^(PXElement *stanza) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        [expectation fulfill];
    }];
    [router handleIQRequest:request resultHandler:module];
    
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
