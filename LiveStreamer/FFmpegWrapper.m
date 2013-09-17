//
//  FFmpegWrapper.m
//  FFmpegWrapper
//
//  Created by Christopher Ballinger on 9/14/13.
//  Copyright (c) 2013 OpenWatch, Inc. All rights reserved.
//
//  This file is part of FFmpegWrapper.
//
//  FFmpegWrapper is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//
//  FFmpegWrapper is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with FFmpegWrapper; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
//

#import "FFmpegWrapper.h"
#import "avformat.h"

NSString const *kFFmpegInputFormatKey = @"kFFmpegInputFormatKey";
NSString const *kFFmpegOutputFormatKey = @"kFFmpegOutputFormatKey";
static NSString * const kFFmpegErrorDomain = @"org.ffmpeg.FFmpeg";

@implementation FFmpegWrapper
@synthesize conversionQueue, callbackQueue;

- (void) dealloc {
    avformat_network_deinit();
}

- (id) init {
    if (self = [super init]) {
        self.conversionQueue = dispatch_queue_create("ffmpeg conversion queue", NULL);
        self.callbackQueue = dispatch_get_main_queue();
        av_register_all();
        avformat_network_init();
    }
    return self;
}

+ (NSString*) stringForAVErrorNumber:(int)errorNumber {
    NSString *errorString = nil;
    char *errorBuffer = malloc(sizeof(char) * AV_ERROR_MAX_STRING_SIZE);
    
    int value = av_strerror(errorNumber, errorBuffer, AV_ERROR_MAX_STRING_SIZE);
    if (value != 0) {
        return nil;
    }
    errorString = [NSString stringWithUTF8String:errorBuffer];
    free(errorBuffer);
    return errorString;
}

+ (NSError*) errorWithCode:(int)errorCode localizedDescription:(NSString*)description {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:1];
    if (description) {
        [userInfo setObject:description forKey:NSLocalizedDescriptionKey];
    }
    return [NSError errorWithDomain:kFFmpegErrorDomain code:errorCode userInfo:userInfo];
}

+ (NSError*) errorForAVErrorNumber:(int)errorNumber {
    NSString *description = [self stringForAVErrorNumber:errorNumber];
    return [self errorWithCode:errorNumber localizedDescription:description];
}

- (void) convertInputPath:(NSString*)inputPath outputPath:(NSString*)outputPath options:(NSDictionary*)options progressBlock:(FFmpegWrapperProgressBlock)progressBlock completionBlock:(FFmpegWrapperCompletionBlock)completionBlock {
    dispatch_async(conversionQueue, ^{
        BOOL success = NO;
        NSError *error = nil;
        
        // You can override the detected input format
        AVInputFormat *inputFormat = NULL;
        NSString *inputFormatString = [options objectForKey:kFFmpegInputFormatKey];
        if (inputFormatString) {
            inputFormat = av_find_input_format([inputFormatString UTF8String]);
        }
        
        AVDictionary *inputOptions = NULL;
        // It's possible to send more options to the parser
        // av_dict_set(&inputOptions, "video_size", "640x480", 0);
        // av_dict_set(&inputOptions, "pixel_format", "rgb24", 0);
        // av_dict_free(&inputOptions); // Don't forget to free
        
        AVFormatContext *inputFormatContext = NULL;
        int returnValue = avformat_open_input(&inputFormatContext, [inputPath UTF8String], inputFormat, &inputOptions);
        if (returnValue != 0) {
            if (completionBlock) {
                NSError *error = [[self class] errorForAVErrorNumber:returnValue];
                dispatch_async(callbackQueue, ^{
                    completionBlock(NO, error);
                });
            }
            return;
        }
        
        avformat_close_input(&inputFormatContext);
        success = YES;
        error = nil;
        if (completionBlock) {
            dispatch_async(callbackQueue, ^{
                completionBlock(success, error);
            });
        }
    });
}

@end
