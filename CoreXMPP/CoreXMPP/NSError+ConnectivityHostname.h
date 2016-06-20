//
//  NSError+ConnectivityHostname.h
//  CoreXMPP
//
//  Created by Tobias Kraentzer on 24.05.16.
//  Copyright © 2016 Tobias Kräntzer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (ConnectivityHostname)

- (NSString *)xmpp_connectivityHostname;

@end
