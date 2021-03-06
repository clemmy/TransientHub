//
//  TWDataManager.m
//  TransientHub
//
//  Created by Kevin Hunt on 2015-04-09.
//  Copyright (c) 2015 ProphetStudios. All rights reserved.
//

#import "TWDataManager.h"
#import "CDEvent.h"
#import "CDEventFeed.h"

#import "TWCRTSEvent.h"

#define kCDEvent        @"CDEvent"
#define kCDEventFeed    @"CDEventFeed"

@interface TWDataManager ()
+ (NSManagedObjectModel *)managedObjectModel;
@property (nonatomic, weak) NSThread *coreDataThread;

@end

@implementation TWDataManager {
    NSRecursiveLock *_saveLock;
}

static TWDataManager *_sharedDataManager;
static NSPersistentStoreCoordinator *__persistentStoreCoordinator;
static NSManagedObjectModel *__managedObjectModel;

+ (TWDataManager *)sharedDataManager {
    @synchronized([TWDataManager class]) {
        if(!_sharedDataManager) {
            NSLog(@"Creating Data Manager");
            _sharedDataManager  = [[TWDataManager alloc] init];
        }
        return _sharedDataManager;
    }
    
    return nil;
}

- (id)init {
    if(self = [super init]) {
        _saveLock = [[NSRecursiveLock alloc] init];
    }
    
    return self;
}

+ (void)cleanDataManager {
    if(__persistentStoreCoordinator) {
        __persistentStoreCoordinator = nil;
    }
    if(__managedObjectModel) {
        __managedObjectModel = nil;
    }
    [[self sharedDataManager]cleanDataManager];
}

- (void)cleanDataManager {
    // NSLogMethod();
    
    if(_managedObjectContext) {
        self.managedObjectContext = nil;
    }
}

#pragma mark -
#pragma mark TransientHub methods

- (int)getNumberOfFeeds {
    // TODO: replace this with actual logic
    return 1;
}

- (NSArray *)initializeStandardFeeds {
    
    [_saveLock lock];
    
    // TODO: Replace with code to add CRTS feed
    // TODO: add more standard feeds
    
    // TODO: Remove this sample event load
    
    NSMutableArray *eventArray = [[NSMutableArray alloc] init];
    
    //get dictionary from json file
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"LSST" ofType:@"json"];
    NSData* data = [NSData dataWithContentsOfFile:filePath];
    
    NSError* error = nil;
    if (data) {
        NSArray *lsstEvents = [NSJSONSerialization JSONObjectWithData:data
                                                                      options:kNilOptions error:&error];
        for (NSDictionary *eventDict in lsstEvents) {
            if ([eventDict objectForKey:@"resumptionToken"] == nil) {
                CDEvent *cdEvent = [self saveEventFromDict:eventDict];
                if (cdEvent) {
                    TWCRTSEvent *event = [TWCRTSEvent crtsEventWithSavedEvent:cdEvent];
                    if (event) {
                        [eventArray addObject:event];
                    } else {
                        NSLog(@"Unable to create crtsEvent from dict: %@",eventDict);
                    }
                } else {
                    NSLog(@"Unable to create cdEvent from dict: %@",eventDict);
                }
            }
        }
    }
    if (error || !data) {
        NSLog(@"Error loading events");
    }
    
    @try {
        [self saveChanges:&error];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:@"alreadyInitialized"];
    } @catch (NSException *e) {
        NSLog(@"error: %@, %@", e, [e reason]);
    } @finally {
        // unlock record lock
        [_saveLock unlock];
    }
    
    return eventArray;
}

- (NSArray *)getSampleFeedData {
    
    NSError *error                  = nil;
    NSFetchRequest *fetchRequest    = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity     = [NSEntityDescription entityForName:kCDEvent inManagedObjectContext:self.managedObjectContext];
    
    [fetchRequest setEntity:entity];
    
    NSArray *results = [self fetchData:fetchRequest withError:&error];
    
    
    if(error) {
        NSLog(@"Error getting sample data %@", error.description);
    }
    
    if(results) {
        return results;
    } else {
        NSLog(@"No results");
        return nil;
    }
}

- (CDEvent *)saveEventFromDict:(NSDictionary *)eventDict {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    
    CDEvent *cdEvent = [NSEntityDescription insertNewObjectForEntityForName:kCDEvent inManagedObjectContext:self.managedObjectContext];
    
    NSArray *objectNameDict = [eventDict objectForKey:@"objectName"];
    if (objectNameDict && [objectNameDict count] > 0) {
        cdEvent.name = [objectNameDict  objectAtIndex:0];
    }
    cdEvent.type = [eventDict objectForKey:@"type"];
    
    NSString *alertTimeString = [eventDict objectForKey:@"triggerEventTime"];
    cdEvent.alertTime = [dateFormatter dateFromString:alertTimeString];
    
    NSString *eventTimeString = [eventDict objectForKey:@"firstEventTime"];
    cdEvent.eventTime = [dateFormatter dateFromString:eventTimeString];

    cdEvent.magnitude = [NSNumber numberWithFloat:[[eventDict objectForKey:@"magnitude"] floatValue]];
    cdEvent.ra = [NSNumber numberWithFloat:[[eventDict objectForKey:@"ra"] floatValue]];
    cdEvent.dec = [NSNumber numberWithFloat:[[eventDict objectForKey:@"dec"] floatValue]];
    
    NSArray *referenceImageURLDict = [eventDict objectForKey:@"referenceImageURL"];
    if (referenceImageURLDict && [referenceImageURLDict count] > 0) {
        cdEvent.refImgUrl = [referenceImageURLDict  objectAtIndex:0];
    }
    
    NSArray *findingChartDict = [eventDict objectForKey:@"findingChart"];
    if (findingChartDict && [findingChartDict count] > 0) {
        cdEvent.finderChartUrl = [findingChartDict  objectAtIndex:0];
    }
    
    NSArray *lightCurveDict = [eventDict objectForKey:@"lightCurve"];
    if (lightCurveDict && [lightCurveDict count] > 0) {
        cdEvent.lightCurveUrl = [lightCurveDict  objectAtIndex:0];
    }
    
    NSArray *pastImgsDict = [eventDict objectForKey:@"pastImgs"];
    if (pastImgsDict && [pastImgsDict count] > 0) {
        cdEvent.pastImg = [pastImgsDict  objectAtIndex:0];
    }
    
    cdEvent.recentImgs = [eventDict objectForKey:@"freshImageURL"];
    
    cdEvent.firstIVORNRef = [eventDict objectForKey:@"firstIVORN"];
    cdEvent.triggerIVORN = [eventDict objectForKey:@"triggerIVORN"];
    cdEvent.localIVORN = [eventDict objectForKey:@"localIVORN"];
    
    NSArray *findingChartImageDict = [eventDict objectForKey:@"findingChartImage"];
    if (findingChartImageDict && [findingChartImageDict count] > 0) {
        cdEvent.findingChartImage = [findingChartImageDict  objectAtIndex:0];
    }
    
    cdEvent.viewed = [NSNumber numberWithFloat:[[NSNumber numberWithBool:NO] boolValue]];
    
    return cdEvent;
}

#pragma mark -
#pragma mark Core Data stack

- (BOOL)saveChanges:(NSError **)error {
    [_saveLock lock];
    
    [self.managedObjectContext lock];
    
    BOOL returnStatus;
    
    @try {
        returnStatus     = [self.managedObjectContext save:error];
        if(!returnStatus && error) {
            NSLog(@"error in save %@", *error);
        }
    } @catch (NSException *e) {
        NSLog(@"Failed To SaveChanges -> %@", [e reason]);
    } @finally {
        [self.managedObjectContext unlock];
        [_saveLock unlock];
        
        return returnStatus;
    }
}

- (NSArray *)fetchData:(NSFetchRequest *)fetchRequest withError:(NSError **)error {
    [_saveLock lock];
    
    [[self managedObjectContext] lock];
    
    NSArray *result = nil;
    
    @try {
        result = [[self managedObjectContext] executeFetchRequest:fetchRequest error:error];
    } @catch (NSException *e) {
        NSLog(@"Failed To Fetch Data %@", [e reason]);
        NSLog(@"Sumpting blew up: %@", [e reason]);
    } @finally {
        [[self managedObjectContext] unlock];
        [_saveLock unlock];
        return result;
    }
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
+ (NSManagedObjectModel *)managedObjectModel {
    
    if(__managedObjectModel == nil) {
        NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Model" ofType:@"momd"];
        
        NSURL *momURL = [NSURL fileURLWithPath:path isDirectory:YES];
        __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];
    }
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    return [TWDataManager persistentStoreCoordinator];
}

+ (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    @synchronized(self) {
        
        if(__persistentStoreCoordinator == nil) {
            
            NSArray *paths      = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *basePath  = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            NSString *sqliteFile = [basePath stringByAppendingPathComponent:@"TransHub.sqlite"];
            
            NSURL *storeUrl = [NSURL fileURLWithPath:sqliteFile];
            
            NSLog(@"Store URL is: %@", storeUrl);
            NSError *error;
            
            
            NSDictionary *optionsDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                               [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
            
            
            NSManagedObjectModel *model = [self managedObjectModel];
            
            __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
            
            if(![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:optionsDictionary error:&error]) {
                // Handle error
                if(error && [error localizedDescription]) {
                    NSLog(@"Error getting persistentStoreCoordinator - %@  %@", [error localizedDescription], [error userInfo]);
                }
            }
        }
        
        
        
        return __persistentStoreCoordinator;
    }
}

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
    @synchronized([TWDataManager class]) {
        if(_managedObjectContext == nil) {
            [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(handleMerge:) name:NSManagedObjectContextDidSaveNotification object:nil];
            self.coreDataThread = [NSThread currentThread];
            NSLog(@"coreDataThread %@", self.coreDataThread);
            NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
            if(coordinator != nil) {
                self.managedObjectContext = [[NSManagedObjectContext alloc] init];
                self.managedObjectContext.persistentStoreCoordinator = coordinator;
                NSLog(@"created MOC %@", self.managedObjectContext);
            }
        }
        
        return _managedObjectContext;
    }
    
    return nil;
}

- (void)handleMerge:(NSNotification *)mergeNotification {
    if(_managedObjectContext != nil) {
        if(_managedObjectContext != mergeNotification.object) {
            [self performSelector:@selector(doMerge:) onThread:self.coreDataThread withObject:mergeNotification waitUntilDone:NO];
        } else {
            NSLog(@"unexpected notification on my own MOC");
        }
    }
}

- (void)doMerge:(NSNotification *)mergeNotification {
    if([[(NSManagedObjectContext *)[mergeNotification object] persistentStoreCoordinator] isEqual:self.managedObjectContext.persistentStoreCoordinator]) {
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:mergeNotification];
    }
}

// internal data manager methods
- (void)dumpAllManagedObjects {
    [self dumpAllEvents];
    [self dumpAllFeeds];
}

- (void)dumpAllEvents {
    
}

- (void)dumpAllFeeds {
    
}


@end
