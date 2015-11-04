//
//  XMPPStream.h
//  CoreXMPP
//
//  Created by Tobias Kräntzer on 04.11.15.
//  Copyright © 2015 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PureXML/PureXML.h>

@class XMPPStream;

@protocol XMPPStreamDelegate <NSObject>
@optional
- (void)stream:(XMPPStream *)stream didOpenWithStreamId:(NSString *)streamId;
- (void)stream:(XMPPStream *)stream didReceiveElement:(PXElement *)element;
- (void)stream:(XMPPStream *)stream didFailWithError:(NSError *)error;
- (void)streamDidClose:(XMPPStream *)stream;
@end

@interface XMPPStream : NSObject

#pragma mark Life-cycle
- (instancetype)initWithHostname:(NSString *)hostname
                        language:(NSString *)language
                         options:(NSDictionary *)options;

#pragma mark Delegate
@property (nonatomic, weak) id<XMPPStreamDelegate> delegate;

#pragma mark Properties
@property (nonatomic, readonly) NSString *hostname;
@property (nonatomic, readonly) NSString *language;
@property (nonatomic, readonly) NSDictionary *options;

#pragma mark Managing Stream
- (void)open;
- (void)close;
- (void)sendElement:(PXElement *)element;

@end
