//
//  XMPPImmediatelyReconnectStrategyTests.m
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPImmediatelyReconnectStrategy.h"
#import "XMPPTestCase.h"

@interface XMPPImmediatelyReconnectStrategyTests : XMPPTestCase
@property (nonatomic, strong) XMPPClient *client;
@property (nonatomic, strong) XMPPImmediatelyReconnectStrategy *strategy;
@end

@implementation XMPPImmediatelyReconnectStrategyTests

- (void)setUp
{
    [super setUp];
    self.client = mock([XMPPClient class]);
    self.strategy = [[XMPPImmediatelyReconnectStrategy alloc] initWithClient:self.client];
}

#pragma mark Tests

- (void)testStrategy
{
    [self.strategy start];
    [verify(self.client) connect];
}

@end
