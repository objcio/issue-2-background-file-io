//
// Created by chris on 6/17/13.
//

#import <Foundation/Foundation.h>


@interface Reader : NSObject

- (id)initWithFileAtURL:(NSURL *)fileURL;

- (void)enumerateLinesWithBlock:(void (^)(NSUInteger lineNumber, NSString *line))block
              completionHandler:(void (^)(NSUInteger numberOfLines))completion;

@end
