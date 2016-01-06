//
//  XMPPStreamFeature.m
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 05.01.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import "XMPPStreamFeature.h"

@implementation XMPPStreamFeature

#pragma mark Feature Name & Namespace

+ (NSString *)name
{
    return nil;
}

+ (NSString *)namespace
{
    return nil;
}

#pragma mark Life-cycle

- (id)initWithElement:(PXElement *)element
{
    return [super init];
}

#pragma mark Feature Properties

- (BOOL)isMandatory
{
    return NO;
}

- (BOOL)needsRestart
{
    return NO;
}

#pragma mark Negotiate Feature

- (void)beginNegotiation
{
}

- (void)handleElement:(PXElement *)element
{
}

@end
