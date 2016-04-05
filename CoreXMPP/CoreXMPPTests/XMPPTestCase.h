//
//  XMPPTestCase.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 18.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

#define MOCKITO_SHORTHAND
#import <OCMockito/OCMockito.h>

#import <CocoaLumberjack/CocoaLumberjack.h>
#import <OHHTTPStubs/OHHTTPStubs.h>

#import <CoreXMPP/CoreXMPP.h>

#import "XMPPConnectionStub.h"
#import "XMPPModuleStub.h"
#import "XMPPStreamFeatureStub.h"
#import "XMPPStreamStub.h"

@interface XMPPTestCase : XCTestCase
@property (nonatomic, strong) NSString *keyChainServiceName;
@end
