//
// Created by chris on 6/17/13.
//

#import "Reader.h"
#import "NSData+EnumerateComponents.h"



@interface Reader () <NSStreamDelegate>

@property (nonatomic, strong) NSInputStream* inputStream;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, copy) NSData *delimiter;
@property (nonatomic, strong) NSMutableData *remainder;
@property (nonatomic, copy) void (^callback) (NSUInteger lineNumber, NSString* line);
@property (nonatomic, copy) void (^completion) (NSUInteger numberOfLines);
@property (nonatomic) NSUInteger lineNumber;
@property (nonatomic, strong) NSOperationQueue *queue;


@end



@implementation Reader

- (void)enumerateLinesWithBlock:(void (^)(NSUInteger lineNumber, NSString *line))block completionHandler:(void (^)(NSUInteger numberOfLines))completion;
{
    if (self.queue == nil) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
    }
    NSAssert(self.queue.maxConcurrentOperationCount == 1, @"Queue can't be concurrent.");
    NSAssert(self.inputStream == nil, @"Cannot process multiple input streams in parallel");
    self.callback = block;
    self.completion = completion;
    self.inputStream = [NSInputStream inputStreamWithURL:self.fileURL];
    self.inputStream.delegate = self;
    
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.inputStream open];
}

- (id)initWithFileAtURL:(NSURL *)fileURL;
{
    if (![fileURL isFileURL]) {
        return nil;
    }
    self = [super init];
    if (self) {
        self.fileURL = fileURL;
        self.delimiter = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
    }
    return self;
}

- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            break;
        }
        case NSStreamEventEndEncountered: {
            [self emitLineWithData:self.remainder];
            self.remainder = nil;
            [self.inputStream close];
            self.inputStream = nil;
            [self.queue addOperationWithBlock:^{
                self.completion(self.lineNumber + 1);
            }];
            break;
        }
        case NSStreamEventErrorOccurred: {
            NSLog(@"error"); // TODO
            break;
        }
        case NSStreamEventHasBytesAvailable: {
            NSMutableData *buffer = [NSMutableData dataWithLength:4 * 1024];
            NSUInteger length = (NSUInteger) [self.inputStream read:[buffer mutableBytes] maxLength:[buffer length]];
            if (0 < length) {
                [buffer setLength:length];
                __weak id weakSelf = self;
                [self.queue addOperationWithBlock:^{
                    [weakSelf processDataChunk:buffer];
                }];
            }
            break;
        }
        default: {
            break;
        }
    }
}

- (void)processDataChunk:(NSMutableData *)buffer;
{
    if (self.remainder != nil) {
        [self.remainder appendData:buffer];
    } else {
        self.remainder = buffer;
    }
    [self.remainder obj_enumerateComponentsSeparatedBy:self.delimiter usingBlock:^(NSData* component, BOOL last){
        if (!last) {
            [self emitLineWithData:component];
        } else if (0 < [component length]) {
            self.remainder = [component mutableCopy];
        } else {
            self.remainder = nil;
        }
    }];
}

- (void)emitLineWithData:(NSData *)data;
{
    NSUInteger lineNumber = self.lineNumber;
    self.lineNumber = lineNumber + 1;
    if (0 < data.length) {
        NSString *line = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        self.callback(lineNumber, line);
    }
}

@end
