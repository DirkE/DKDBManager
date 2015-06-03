//
//  NSManagedObject+DKDBManager.m
//
//  Created by kevin delord on 20/05/14.
//  Copyright (c) 2014 Kevin Delord. All rights reserved.
//

#import "NSManagedObject+DKDBManager.h"

@implementation NSManagedObject (DKDBManager)

#pragma mark - CREATE

+ (instancetype)createEntityFromDictionary:(NSDictionary *)dictionary {
    return [self createEntityFromDictionary:dictionary completion:nil];
}

+ (instancetype)createEntityFromDictionary:(NSDictionary *)dictionary completion:(void (^)(id entity, DKDBManagedObjectState status))completion {

    // now create, save or update an entity
    DKDBManagedObjectState status = DKDBManagedObjectStateSave;

    // if the entity already exist then update it
    id entity = [self MR_findFirstWithPredicate:[self primaryPredicateWithDictionary:dictionary]];
    // else create a new entity in the current thread MOC
    if (entity == nil) {
        entity = [self MR_createEntity];
        [entity updateWithDictionary:dictionary];
        status = DKDBManagedObjectStateCreate;

    } else if (DKDBManager.needForcedUpdate || (DKDBManager.allowUpdate && [entity shouldUpdateEntityWithDictionary:dictionary])) {
        // update attributes
        [entity updateWithDictionary:dictionary];
        status = DKDBManagedObjectStateUpdate;
    }

    // Just keeping the valid and managed entities and ignored the unvalid, disabled, non-managed ones.
    if ([entity invalidReason]) {
        [entity deleteEntityWithReason:[entity invalidReason]];
        entity = nil;
        status = DKDBManagedObjectStateDelete;
    }

    // Log and save current with or without child entities.
    [self saveEntityAfterCreation:entity status:status];

    if (completion) {
        completion(entity, status);
    }
    return entity;
}

+ (NSArray *)createEntitiesFromArray:(NSArray *)array {

    if (!array || !array.count) return nil;

    NSMutableArray *entities = [NSMutableArray new];
    for (NSDictionary *dictionary in array) {
        id entity = [self createEntityFromDictionary:dictionary];
        if (entity)
            [entities addObject:entity];
    }
    return entities;
}

#pragma mark - SAVE

+ (void)saveEntityAfterCreation:(id)entity status:(DKDBManagedObjectState)status {
    //
    // In case of a Database matching an API it is necessary to store entities as not deprecated.
    // Depending on the state different thing occurs:
    // If the state is `.Create` or `.Update`:
    // If the state is `.Save`:
    // If the state is `.Delete`:
    //
    switch (status) {
        case DKDBManagedObjectStateSave:
            DKLog(DKDBManager.verbose && [self verbose], @"Saving %@ %@", NSStringFromClass([self class]), entity);
            [entity saveCurrentAndChildEntitiesAsNotDeprecated];
            break;
        case DKDBManagedObjectStateCreate:
            DKLog(DKDBManager.verbose && [self verbose], @"Creating %@ %@", NSStringFromClass([self class]), entity);
            [entity saveCurrentEntityAsNotDeprecated];
            break;
        case DKDBManagedObjectStateUpdate:
            DKLog(DKDBManager.verbose && [self verbose], @"Updating %@ %@", NSStringFromClass([self class]), entity);
            [entity saveCurrentEntityAsNotDeprecated];
            break;
        case DKDBManagedObjectStateDelete:
            DKLog(DKDBManager.verbose && [self verbose], @"Deleting %@ %@", NSStringFromClass([self class]), entity);
            break;
        default:
            break;
    }

}

- (void)saveCurrentAndChildEntitiesAsNotDeprecated {
    //
    // Method to save/store the current object AND all its child relations as not deprecated.
    // See: DKDBManager
    //

    [self saveCurrentEntityAsNotDeprecated];
}

- (void)saveCurrentEntityAsNotDeprecated {
    //
    // Method to save/store the current object as not deprecated.
    // See: DKDBManager
    //

    [DKDBManager saveEntityAsNotDeprecated:self];
}

#pragma mark - READ

- (id)uniqueIdentifier {
    return self.objectID;
}

- (NSString *)invalidReason {
    // Check if the current entity is valid.
    // Return a NSString containing the reason, nil if the object is valid
    return nil;
}

- (BOOL)shouldUpdateEntityWithDictionary:(NSDictionary *)dictionary {
    // will be ignored if needForcedUpdate == true OR if allowUpdate == true
    return true;
}

+ (BOOL)verbose {
    return false;
}

+ (NSPredicate *)primaryPredicateWithDictionary:(NSDictionary *)dictionary {
    // If returns nil will only take the first entity created (if any) and update it.
    // By doing so only ONE entity will ever be created.
    // otherwise use the one find bu the predicate.
    return nil;
}

+ (NSString *)sortingAttributeName {
    return nil;
}

+ (NSInteger)count {
    return [self MR_countOfEntities];
}

+ (NSArray *)all {
    if (self.sortingAttributeName)
        return [self MR_findAllSortedBy:self.sortingAttributeName ascending:YES];
    return [self MR_findAll];
}

#pragma mark - UPDATE

- (void)updateWithDictionary:(NSDictionary *)dict {
    // this method should be overridden on the subclass
}

#pragma mark - DELETE

- (void)deleteChildEntities {
    // remove all the child of the current object
}

- (void)deleteEntityWithReason:(NSString *)reason {
    DKLog(DKDBManager.verbose && self.class.verbose, @"delete %@: %@ Reason: %@", [self class], self, reason);
    
    // remove all the child of the current object
    [self deleteChildEntities];
    
    // remove the current object
    [self MR_deleteEntity];
}

+ (void)deleteAllEntities {
    [self MR_deleteAllMatchingPredicate:nil];
}

+ (void)removeDeprecatedEntitiesFromArray:(NSArray *)array {
    // check if all entities are still in the dictionary
    for (id entity in [self MR_findAll]) {
        // if the entity is deprecated (no longer in the dictionary) then remove it !
        if ([entity respondsToSelector:@selector(uniqueIdentifier)]) {
            if (![array containsObject:[entity performSelector:@selector(uniqueIdentifier)]]) {
                [entity deleteEntityWithReason:@"deprecated"];
            }
        }
    }
}

@end
