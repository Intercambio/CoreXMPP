//
//  XMPPPingModuleTests.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 20.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <PureXML/PureXML.h>

#import "XMPPTestCase.h"

@interface XMPPPingModuleTests : XMPPTestCase

@end

@implementation XMPPPingModuleTests

- (void)testPingSuccess
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.stanzaHandler = dispatcher;
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    [connection onHandleStanza:^(PXElement *stanza, void (^completion)(NSError *), id<XMPPStanzaHandler> responseHandler) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        assertThatInteger(stanza.numberOfElements, equalToInteger(1));

        PXElement *ping = [stanza elementAtIndex:0];
        assertThat(ping.qualifiedName, equalTo(PXQN(@"urn:xmpp:ping", @"ping")));

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

        [responseHandler handleStanza:response completion:nil];
    }];

    XMPPPingModule *module = [[XMPPPingModule alloc] initWithServiceManager:nil dispatcher:dispatcher options:nil];
    [module loadModule:nil];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Pong"];
    [module sendPingTo:to
                     from:from
                  timeout:2.0
        completionHandler:^(BOOL success, NSError *error) {
            assertThatBool(success, isTrue());
            assertThat(error, nilValue());
            [expectation fulfill];
        }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatInteger(dispatcher.numberOfPendingIQResponses, equalToInteger(0));
}

- (void)testPingError
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.stanzaHandler = dispatcher;
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    [connection onHandleStanza:^(PXElement *stanza, void (^completion)(NSError *), id<XMPPStanzaHandler> responseHandler) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        assertThatInteger(stanza.numberOfElements, equalToInteger(1));

        PXElement *ping = [stanza elementAtIndex:0];
        assertThat(ping.qualifiedName, equalTo(PXQN(@"urn:xmpp:ping", @"ping")));

        NSString *from = [stanza valueForAttribute:@"to"];
        NSString *to = [stanza valueForAttribute:@"from"];
        NSString *_id = [stanza valueForAttribute:@"id"];

        PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
        PXElement *response = doc.root;
        [response setValue:from forAttribute:@"from"];
        [response setValue:to forAttribute:@"to"];
        [response setValue:@"error" forAttribute:@"type"];
        [response setValue:_id forAttribute:@"id"];

        PXElement *error = [response addElementWithName:@"error" namespace:@"jabber:client" content:nil];
        [error setValue:@"cancel" forAttribute:@"type"];
        [error addElementWithName:@"service-unavailable" namespace:@"urn:ietf:params:xml:ns:xmpp-stanzas" content:nil];

        if (completion) {
            completion(nil);
        }

        [responseHandler handleStanza:response completion:nil];
    }];

    XMPPPingModule *module = [[XMPPPingModule alloc] initWithServiceManager:nil dispatcher:dispatcher options:nil];
    [module loadModule:nil];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Pong"];
    [module sendPingTo:to
                     from:from
                  timeout:2.0
        completionHandler:^(BOOL success, NSError *error) {
            assertThatBool(success, isFalse());
            assertThat(error.domain, equalTo(XMPPStanzaErrorDomain));
            assertThatInteger(error.code, equalToInteger(XMPPStanzaErrorCodeServiceUnavailable));
            [expectation fulfill];
        }];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    assertThatInteger(dispatcher.numberOfPendingIQResponses, equalToInteger(0));
}

- (void)testPingWithTimeout
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.stanzaHandler = dispatcher;
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPPingModule *module = [[XMPPPingModule alloc] initWithServiceManager:nil dispatcher:dispatcher options:nil];
    [module loadModule:nil];

    XMPPJID *from = JID(@"romeo@localhost");
    XMPPJID *to = JID(@"juliet@example.com");

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Pong"];
    [module sendPingTo:to
                     from:from
                  timeout:1.0
        completionHandler:^(BOOL success, NSError *error) {
            assertThatBool(success, isFalse());
            assertThat(error.domain, equalTo(XMPPDispatcherErrorDomain));
            assertThatInteger(error.code, equalToInteger(XMPPDispatcherErrorCodeTimeout));
            [expectation fulfill];
        }];
    [self waitForExpectationsWithTimeout:2.0 handler:nil];

    assertThatInteger(dispatcher.numberOfPendingIQResponses, equalToInteger(0));
}

- (void)testPong
{
    XMPPDispatcher *dispatcher = [[XMPPDispatcher alloc] init];
    XMPPConnectionStub *connection = [[XMPPConnectionStub alloc] init];
    connection.stanzaHandler = dispatcher;
    [dispatcher setConnection:connection forJID:JID(@"romeo@localhost")];

    XMPPPingModule *module = [[XMPPPingModule alloc] initWithServiceManager:nil dispatcher:dispatcher options:nil];
    [module loadModule:nil];

    XMPPJID *from = JID(@"juliet@example.com");
    XMPPJID *to = JID(@"romeo@localhost");
    NSString *requestID = [[NSUUID UUID] UUIDString];

    PXDocument *doc = [[PXDocument alloc] initWithElementName:@"iq" namespace:@"jabber:client" prefix:nil];
    PXElement *iq = doc.root;
    [iq setValue:[to stringValue] forAttribute:@"to"];
    [iq setValue:[from stringValue] forAttribute:@"from"];
    [iq setValue:@"get" forAttribute:@"type"];
    [iq setValue:requestID forAttribute:@"id"];
    [iq addElementWithName:@"ping" namespace:@"urn:xmpp:ping" content:nil];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect Pong"];
    [connection onHandleStanza:^(PXElement *stanza, void (^completion)(NSError *), id<XMPPStanzaHandler> responseHandler) {
        assertThat(stanza, equalTo(PXQN(@"jabber:client", @"iq")));
        assertThatInteger(stanza.numberOfElements, equalToInteger(0));
        assertThat([stanza valueForAttribute:@"type"], equalTo(@"result"));
        assertThat([stanza valueForAttribute:@"id"], equalTo(requestID));
        assertThat([stanza valueForAttribute:@"from"], equalTo([to stringValue]));
        assertThat([stanza valueForAttribute:@"to"], equalTo([from stringValue]));
        [expectation fulfill];
    }];

    [dispatcher handleStanza:iq completion:nil];
    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
