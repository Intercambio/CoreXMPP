//
//  XMPPDispatcherTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPTestCase.h"

@interface XMPPDispatcherTests : XMPPTestCase

@end

@implementation XMPPDispatcherTests

#pragma mark Connection Handling

- (void)testHandleConnections
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    id<XMPPConnection> connection = mockProtocol(@protocol(XMPPConnection));

    [dispatcher addMessageHandler:module];

    // Add Connection

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Add Connection"];
    [module onAddConnection:^(XMPPJID *JID) {
        XCTAssertEqualObjects(JID, [XMPPJID JIDFromString:@"romeo@example.com"]);
        [expectation fulfill];
    }];
    [dispatcher setConnection:connection forJID:JID(@"romeo@example.com")];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Connect

    expectation = [self expectationWithDescription:@"Expect Connect"];
    [module onConnect:^(XMPPJID *JID, BOOL resumed) {
        XCTAssertEqualObjects(JID, [XMPPJID JIDFromString:@"romeo@example.com"]);
        [expectation fulfill];
    }];
    [dispatcher connection:connection didConnectTo:JID(@"romeo@example.com") resumed:NO];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Disconnect

    expectation = [self expectationWithDescription:@"Expect Disconnect"];
    [module onDisconnect:^(XMPPJID *JID) {
        XCTAssertEqualObjects(JID, [XMPPJID JIDFromString:@"romeo@example.com"]);
        [expectation fulfill];
    }];
    [dispatcher connection:connection didDisconnectFrom:JID(@"romeo@example.com")];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    // Remove Connection

    expectation = [self expectationWithDescription:@"Expect Remove Connection"];
    [module onRemoveConnection:^(XMPPJID *JID) {
        XCTAssertEqualObjects(JID, [XMPPJID JIDFromString:@"romeo@example.com"]);
        [expectation fulfill];
    }];
    [dispatcher removeConnectionForJID:JID(@"romeo@example.com")];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark Message Handling

- (void)testManagingMessageHandler
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [dispatcher addMessageHandler:module];
    assertThat(dispatcher.messageHandlers, contains(module, nil));

    [dispatcher removeMessageHandler:module];
    assertThat(dispatcher.messageHandlers, isNot(contains(module, nil)));
}

- (void)testIncomingMessage
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [module onMessage:^(PXDocument *document) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([document.root stringValue], equalTo(@"Hello!"));
        [expectation fulfill];
    }];

    [dispatcher addMessageHandler:module];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[from stringValue] forAttribute:@"from"];
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    [dispatcher handleDocument:doc completion:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingMessage
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[from stringValue] forAttribute:@"from"];
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([document.root stringValue], equalTo(@"Hello!"));
        if (completion)
            completion(nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [dispatcher handleMessage:doc
                   completion:^(NSError *error) {
                       assertThat(error, nilValue());
                       [expectation fulfill];
                   }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingMessageWithoutRoute
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPJID *from = JID(@"romeo@example.com");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[from stringValue] forAttribute:@"from"];
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([document.root stringValue], equalTo(@"Hello!"));
        if (completion)
            completion(nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [dispatcher handleMessage:doc
                   completion:^(NSError *error) {
                       assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
                       assertThatInteger(error.code, equalToInteger(XMPPDispatcherErrorCodeNoRoute));
                       [expectation fulfill];
                   }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingMessageWithoutSender
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"message")));
        assertThat([document.root stringValue], equalTo(@"Hello!"));
        if (completion)
            completion(nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Message"];
    [dispatcher handleMessage:doc
                   completion:^(NSError *error) {
                       assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
                       assertThatInteger(error.code, equalToInteger(XMPPDispatcherErrorCodeNoSender));
                       [expectation fulfill];
                   }];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark Presence Handling

- (void)testManagingPresenceHandler
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [dispatcher addPresenceHandler:module];
    assertThat(dispatcher.presenceHandlers, contains(module, nil));

    [dispatcher removePresenceHandler:module];
    assertThat(dispatcher.presenceHandlers, isNot(contains(module, nil)));
}

- (void)testIncomingPresence
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Presence"];
    [module onPresence:^(PXDocument *document) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"presence")));
        [expectation fulfill];
    }];

    [dispatcher addPresenceHandler:module];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];

    [dispatcher handleDocument:doc completion:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingPresence
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"presence")));
        if (completion)
            completion(nil);
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Presence"];
    [dispatcher handlePresence:doc
                    completion:^(NSError *error) {
                        [expectation fulfill];
                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark IQ Handling

- (void)testManageIQHandler
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];

    [dispatcher setIQHandler:module forQuery:PXQN(@"foo:bar", @"query")];
    assertThat(dispatcher.IQHandlersByQuery[PXQN(@"foo:bar", @"query")], is(module));

    [dispatcher removeIQHandlerForQuery:PXQN(@"foo:bar", @"query")];
    assertThat(dispatcher.IQHandlersByQuery[PXQN(@"foo:bar", @"query")], nilValue());

    [dispatcher setIQHandler:module forQuery:PXQN(@"foo:bar", @"query")];
    [dispatcher setIQHandler:module forQuery:PXQN(@"foo:baz", @"query")];
    assertThat(dispatcher.IQHandlersByQuery[PXQN(@"foo:bar", @"query")], is(module));
    assertThat(dispatcher.IQHandlersByQuery[PXQN(@"foo:baz", @"query")], is(module));

    [dispatcher removeIQHandler:module];
    assertThat(dispatcher.IQHandlersByQuery[PXQN(@"foo:bar", @"query")], nilValue());
    assertThat(dispatcher.IQHandlersByQuery[PXQN(@"foo:baz", @"query")], nilValue());
}

- (void)testIncomingIQRequest
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPModuleStub *module = [[XMPPModuleStub alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [dispatcher setIQHandler:module forQuery:PXQN(@"foo:bar", @"query")];
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    [module onIQRequest:^(PXElement *stanza, NSTimeInterval timeout, void (^completion)(PXElement *, NSError *)) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        assertThat(completion, notNilValue());

        NSString *from = [stanza valueForAttribute:@"to"];
        NSString *to = [stanza valueForAttribute:@"from"];
        NSString *_id = [stanza valueForAttribute:@"id"];

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
        PXElement *response = doc.root;
        [response setValue:from forAttribute:@"from"];
        [response setValue:to forAttribute:@"to"];
        [response setValue:@"result" forAttribute:@"type"];
        [response setValue:_id forAttribute:@"id"];

        if (completion) {
            completion(response, nil);
        }
    }];

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"iq")));
        [expectation fulfill];
    }];

    [dispatcher handleDocument:doc completion:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testIncomingIQRequestNotSupported
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"iq")));
        NSError *error = [NSError errorFromStanza:document.root];
        assertThat(error.domain, equalTo(XMPPStanzaErrorDomain));
        assertThatInteger(error.code, equalToInteger(XMPPStanzaErrorCodeItemNotFound));
        [expectation fulfill];
    }];
    [dispatcher handleDocument:doc completion:nil];

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testOutgoingIQRequest
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];
    connection.connectionDelegate = dispatcher;

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {

        PXElement *stanza = document.root;

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

        if (completion) {
            completion(nil);
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [responseHandler handleDocument:doc completion:nil];
        });
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [dispatcher handleIQRequest:request
                        timeout:0
                     completion:^(PXElement *response, NSError *error) {
                         assertThat(response, equalTo(PXQN(@"jabber:client", @"iq")));
                         [expectation fulfill];
                     }];
    [self waitForExpectationsWithTimeout:100.0 handler:nil];

    assertThatInteger(dispatcher.numberOfPendingIQResponses, equalToInteger(0));
}

- (void)testOutgoingIQRequestWithoutToAddress
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];
    connection.connectionDelegate = dispatcher;

    XMPPJID *from = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {

        PXElement *stanza = document.root;

        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));

        NSString *to = [stanza valueForAttribute:@"from"];
        NSString *from = [[[XMPPJID JIDFromString:[stanza valueForAttribute:@"from"]] bareJID] stringValue];
        NSString *_id = [stanza valueForAttribute:@"id"];

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
        PXElement *response = doc.root;
        [response setValue:from forAttribute:@"from"];
        [response setValue:to forAttribute:@"to"];
        [response setValue:@"result" forAttribute:@"type"];
        [response setValue:_id forAttribute:@"id"];

        if (completion) {
            completion(nil);
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [responseHandler handleDocument:doc completion:nil];
        });
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [dispatcher handleIQRequest:request
                        timeout:0
                     completion:^(PXElement *response, NSError *error) {
                         assertThat(response, equalTo(PXQN(@"jabber:client", @"iq")));
                         [expectation fulfill];
                     }];
    [self waitForExpectationsWithTimeout:100.0 handler:nil];

    assertThatInteger(dispatcher.numberOfPendingIQResponses, equalToInteger(0));
}

- (void)testOutgoingIQRequestWithTimeout
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];
    connection.connectionDelegate = dispatcher;

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    [connection onHandleDocument:^(PXDocument *document, void (^completion)(NSError *), id<XMPPDocumentHandler> responseHandler) {
        assertThat(document.root, equalTo(PXQN(@"jabber:client", @"iq")));
        if (completion) {
            completion(nil);
        }
    }];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Response"];
    [dispatcher handleIQRequest:request
                        timeout:1.0
                     completion:^(PXElement *response, NSError *error) {
                         assertThat(response, nilValue());
                         assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
                         assertThatInteger(error.code, equalToInteger(XMPPDispatcherErrorCodeTimeout));
                         [expectation fulfill];
                     }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    assertThatInteger(dispatcher.numberOfPendingIQResponses, equalToInteger(0));
}

#pragma mark Connection Handling

- (void)testManageConnection
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];

    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];
    assertThat(dispatcher.connectionsByJID[JID(@"romeo@localhost")], is(connection));

    [dispatcher removeConnectionForJID:JID(@"romeo@localhost")];
    assertThat(dispatcher.connectionsByJID[JID(@"romeo@localhost")], nilValue());

    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];
    [dispatcher setConnection:connection forJID:JID(@"juliet@localhost")];
    assertThat(dispatcher.connectionsByJID[JID(@"romeo@localhost")], is(connection));
    assertThat(dispatcher.connectionsByJID[JID(@"juliet@localhost")], is(connection));

    [dispatcher removeConnection:connection];
    assertThat(dispatcher.connectionsByJID[JID(@"romeo@localhost")], nilValue());
    assertThat(dispatcher.connectionsByJID[JID(@"juliet@localhost")], nilValue());
}

#pragma mark Stanza Handling

- (void)testHandleMessageStanza
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"message" namespace:@"jabber:client" prefix:nil];
    PXElement *message = doc.root;
    [message setValue:[from stringValue] forAttribute:@"from"];
    [message setValue:[to stringValue] forAttribute:@"to"];
    [message setValue:@"chat" forAttribute:@"type"];
    [message setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [message addElementWithName:@"body" namespace:@"jabber:client" content:@"Hello!"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Completion"];
    [dispatcher handleDocument:doc
                    completion:^(NSError *error) {
                        assertThat(error, nilValue());
                        [expectation fulfill];
                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testHandlePresenceStanza
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"presence" namespace:@"jabber:client" prefix:nil];
    PXElement *presence = doc.root;
    [presence setValue:[from stringValue] forAttribute:@"from"];
    [presence setValue:[to stringValue] forAttribute:@"to"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Completion"];
    [dispatcher handleDocument:doc
                    completion:^(NSError *error) {
                        assertThat(error, nilValue());
                        [expectation fulfill];
                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testHandleIQStanza
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *request = doc.root;
    [request setValue:[from stringValue] forAttribute:@"from"];
    [request setValue:[to stringValue] forAttribute:@"to"];
    [request setValue:@"get" forAttribute:@"type"];
    [request setValue:[[NSUUID UUID] UUIDString] forAttribute:@"id"];
    [request addElementWithName:@"query" namespace:@"foo:bar" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Completion"];
    [dispatcher handleDocument:doc
                    completion:^(NSError *error) {
                        assertThat(error, nilValue());
                        [expectation fulfill];
                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testHandleInvalidNamespace
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"element" namespace:@"foo:bar" prefix:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Completion"];
    [dispatcher handleDocument:doc
                    completion:^(NSError *error) {
                        assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
                        assertThatInteger(error.code, equalToInteger(XMPPDispatcherErrorCodeInvalidStanza));
                        [expectation fulfill];
                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testHandleInvalidName
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"element" namespace:@"jabber:client" prefix:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Completion"];
    [dispatcher handleDocument:doc
                    completion:^(NSError *error) {
                        assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
                        assertThatInteger(error.code, equalToInteger(XMPPDispatcherErrorCodeInvalidStanza));
                        [expectation fulfill];
                    }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
