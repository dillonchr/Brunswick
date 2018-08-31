//
//  main.m
//  Brunswick
//
//  Created by Dillonchr on 10/4/12.
//  Copyright (c) 2012 iMirus. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Logger.h"
#define MAX_CONCURRENT_CONVERSIONS 2
static NSString *inputDir;
static NSString *outputDir;
void scanForMovies(NSDirectoryEnumerator *files);
static NSMutableArray *movies;
void deleteSourceMovie(NSString *sourcePath);
void moveToPepper(NSString *sourcePath);
void writeToLog(NSString *message);
static int currentMovieIndex;
static int concurrentCount;
void processMovieInBackground(void);
static Logger *logger;
NSString *getInputPath(NSString *pathArg);
NSString *getOutputPath(NSString *pathArg);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        inputDir = getInputPath(@(argv[0]));
        outputDir = getOutputPath(@(argv[1]));
        writeToLog([NSString stringWithFormat:@"Scanning `%@`", inputDir]);
        writeToLog([NSString stringWithFormat:@"Dumping to `%@`", outputDir]);
        
        NSURL *inputDirURL = [NSURL fileURLWithPath:inputDir];
        NSArray *properties = @[NSURLNameKey, NSURLIsDirectoryKey, NSURLFileSizeKey, NSURLPathKey];
        NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:inputDirURL includingPropertiesForKeys:properties options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
        scanForMovies(dirEnumerator);
    }
    return 0;
}

NSString *getInputPath(NSString *pathArg) {
    BOOL isArgADir;
    if (pathArg != nil && [[NSFileManager defaultManager] fileExistsAtPath:pathArg isDirectory:&isArgADir] && isArgADir) {
        return pathArg;
    }
    return [@"~/Desktop/test/" stringByExpandingTildeInPath];
}

NSString *getOutputPath(NSString *pathArg) {
    BOOL isArgADir;
    if (pathArg != nil && [[NSFileManager defaultManager] fileExistsAtPath:pathArg isDirectory:&isArgADir] && isArgADir) {
        return pathArg;
    }
    return [@"~/Desktop/test/" stringByExpandingTildeInPath];
}

void scanForMovies(NSDirectoryEnumerator *files) {
    //  initialize static variables
    NSArray *movieTypes = @[@"avi", @"ts", @"divx", @"mpg", @"mpeg", @"flv", @"mkv"];
    movies = [[NSMutableArray alloc] init];
    for(NSURL *file in files) {
        NSNumber *isDirectory;
        [file getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
        if(!isDirectory.boolValue) {
            NSString *path;
            [file getResourceValue:&path forKey:NSURLPathKey error:NULL];
            writeToLog([NSString stringWithFormat:@"Scanning path '%@'", path]);
            NSString *filename = [path lastPathComponent];
            NSString *extension = [[filename pathExtension] lowercaseString];
            if ([movieTypes containsObject:extension] && ![filename.lowercaseString hasPrefix:@"sample"]) {
                [movies addObject:path];
            }
        }
    }
    //  view results
    if (movies.count) {
        writeToLog([NSString stringWithFormat:@"Found %ld movies!", movies.count]);
        for(int i = 1; i <= MAX_CONCURRENT_CONVERSIONS; i++) {
            processMovieInBackground();
        }
    } else {
        writeToLog( @"Didn't find nothin.");
        [logger writeLog];
    }
}

void processMovieInBackground(void) {
    if(currentMovieIndex < movies.count) {
        concurrentCount++;
        writeToLog([NSString stringWithFormat:@"Running in queue number %d", concurrentCount]);
        NSString *moviePath = [movies objectAtIndex:currentMovieIndex];
        currentMovieIndex++;
        dispatch_queue_t conversionQueue = dispatch_queue_create( "Converting in background", NULL );
        dispatch_async(conversionQueue, ^{
            NSString *filename = [[[moviePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@".m4v"];
            NSString *outputPath = [outputDir stringByAppendingPathComponent:filename];
            writeToLog([NSString stringWithFormat:@"Starting to convert %@", moviePath]);
            NSString *command = [NSString stringWithFormat:@"handbrake -i \"%@\" -o \"%@\" --preset=\"AppleTV 3\"", moviePath, outputPath];
            system([command cStringUsingEncoding:NSUTF8StringEncoding]);
            writeToLog([NSString stringWithFormat:@"CONVERSION COMPLETED FOR %d/%d '%@'", currentMovieIndex, (int) movies.count, moviePath]);
            if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
                NSError *attributesError;
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:&attributesError];
                if (attributesError || ![attributes objectForKey:NSFileSize] || [[attributes objectForKey:NSFileSize] longLongValue] < 1024 * 100) {
                    writeToLog(@"HBERR: Doesn't look like it copied.");
                    writeToLog([NSString stringWithFormat:@"MANUALLY CHECK OUT: %@", outputPath]);
                    writeToLog([NSString stringWithFormat:@"LEAVING SOURCE ALONE: %@", moviePath]);
                } else {
                    writeToLog([NSString stringWithFormat:@"Everything appears to be in order for %@", outputPath]);
                    deleteSourceMovie(moviePath);
                    moveToPepper(outputPath);
                }
            } else {
                writeToLog([NSString stringWithFormat:@"Don't see the converted file for %@", moviePath]);
            }
            concurrentCount--;
            processMovieInBackground();
        });
    } else {
        writeToLog(@"No more movies to convert. Resting up.");
        if (!concurrentCount) {
            writeToLog(@"All jobs reported as completed.");
            writeToLog(@"Terminating application");
            [logger writeLog];
        }
    }
}

void moveToPepper(NSString *sourcePath) {
    NSString *destination = [@"/Volumes/SgtPepper/iTunes Media/Converted/" stringByAppendingPathComponent:[sourcePath lastPathComponent]];
    NSError *moveError;
    [[NSFileManager defaultManager] moveItemAtPath:sourcePath toPath:destination error:&moveError];
    if (moveError) {
        writeToLog([NSString stringWithFormat:@"Couldn't move %@", sourcePath]);
        writeToLog([NSString stringWithFormat:@"Not removing from MacBook."]);
    } else {
        writeToLog( [NSString stringWithFormat:@"Moved over to '%@'", destination] );
    }
}

void deleteSourceMovie(NSString *sourcePath) {
    NSString *parentDir = [sourcePath stringByDeletingLastPathComponent];
    NSError *deleteError;
    if ([parentDir isEqualToString:inputDir]) {
        writeToLog([NSString stringWithFormat:@"DELETING: %@", sourcePath]);
        [[NSFileManager defaultManager] removeItemAtPath:sourcePath error:&deleteError];
    } else {
        writeToLog([NSString stringWithFormat:@"DELETEING FOLDER %@", parentDir]);
        [[NSFileManager defaultManager] removeItemAtPath:parentDir error:&deleteError];
    }
    
    if (deleteError) {
        writeToLog([NSString stringWithFormat:@"DELERR: ERROR DELETING '%@'", sourcePath]);
        writeToLog(deleteError.description);
        writeToLog(@"MAY NEED TO MANUALLY DELETE");
    }
}

void writeToLog(NSString *message) {
    if (!logger) {
        logger = [[Logger alloc] init];
    }
    [logger log:message];
}
