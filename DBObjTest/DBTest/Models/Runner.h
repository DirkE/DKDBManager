//
//  Runner.h
//  DBTest
//
//  Created by kevin delord on 01/10/14.
//  Copyright (c) 2014 kevin delord. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Runner : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * position;

@end
