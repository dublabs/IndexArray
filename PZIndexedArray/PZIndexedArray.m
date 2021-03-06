//Copyright (c) 2011 Pat Zearfoss, http://zearfoss.wordpress.com
//
//Permission is hereby granted, free of charge, to any person obtaining
//a copy of this software and associated documentation files (the "Software"), 
//to deal in the Software without restriction, including
//without limitation the rights to use, copy, modify, merge, publish,
//distribute, sublicense, and/or sell copies of the Software, and to
//permit persons to whom the Software is furnished to do so, subject to
//the following conditions:
//
//The above copyright notice and this permission notice shall be
//included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "PZIndexedArray.h"

@interface PZIndexedArray()
- (void)insertKeySorted:(id)key;
- (void)insertObject:(id)object array:(NSMutableArray *)array;

@end

@implementation PZIndexedArray
@synthesize keySortSelector = keySortSelector_;
@synthesize objectSortSelector = objectSortSelector_;
@synthesize keySortComparator = keySortComparator_;
@synthesize objectSortComparator = objectSortComparator_;

- (id)init
{
    self = [super init];
    if (self)
    {
        dictionary_ = [[NSMutableDictionary alloc] init];
        orderedKeys_ = [[NSMutableOrderedSet alloc] init];
        
        usesComparatorForObjects_ = YES;
        usesComparatorForKeys_ = YES;
    }
    
    return self;
}

- (void)dealloc
{
    [keySortComparator_ release];
    [objectSortComparator_ release];
    [dictionary_ release];
    [orderedKeys_ release];
    [super dealloc];
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone
{
    PZIndexedArray *copy = [[[self class] alloc] init];
    copy->orderedKeys_ = [orderedKeys_ copyWithZone:zone];
    copy->dictionary_ = [dictionary_ copyWithZone:zone];
    copy.keySortComparator = self.keySortComparator;
    copy.objectSortComparator = self.objectSortComparator;
    copy.keySortSelector = self.keySortSelector;
    copy.objectSortSelector = self.objectSortSelector;
    
    return copy;   
}

// accessing keys
- (id)keyAtIndex:(NSUInteger)index
{
    if ([orderedKeys_ count] == 0)
    {
        return nil;
    }
    
    return [orderedKeys_ objectAtIndex:index];
}

- (NSOrderedSet *)allKeys
{
    return [orderedKeys_ copy];
}

- (NSUInteger)keyCount
{
    return [orderedKeys_ count];
}

- (BOOL)hasKey:(id)key
{
    NSInteger index = [orderedKeys_ indexOfObject:key];
    return index != NSNotFound;
}

- (NSUInteger)indexForKey:(id)key
{
    return [orderedKeys_ indexOfObject:key];
}

// accessing objects
- (id)objectForKey:(id)key index:(NSUInteger)index
{
    NSArray *array = [dictionary_ objectForKey:key];
    if (array && index < [array count])
    {
        return [array objectAtIndex:index];
    }
    
    return nil;
}

- (id)objectForKeyAtIndex:(NSUInteger)keyIndex objectIndex:(NSUInteger)objIndex
{
    id key = [self keyAtIndex:keyIndex];
    return [self objectForKey:key index:objIndex];
}

- (NSArray *)allObjectsForKey:(id)key
{
    return [[dictionary_ objectForKey:key] copy];
}

- (NSUInteger)count
{
    NSUInteger count = 0;
    for (id key in [dictionary_ allKeys])
    {
        count += [[dictionary_ objectForKey:key] count];
    }
    
    return count;
}

// adding objects
- (void)addObject:(id)object forKey:(id<NSCopying>)key
{
    NSMutableArray *array = [dictionary_ objectForKey:key];
    if (!array)
    {
        array = [NSMutableArray array];
        [dictionary_ setObject:array forKey:key];
        
        if (sortsKeys_)
        {
            [self insertKeySorted:key];
        }
        else
        {
            [orderedKeys_ addObject:key];
        }
    }
    
    if (sortsObjects_)
    {
        [self insertObject:object array:array];
    }
    else
    {
        [array addObject:object];
    }
}

// removing
- (void)removeObject:(id)object forKey:(id)key
{
    NSMutableArray *array = [dictionary_ objectForKey:key];
    [array removeObject:object];
    if ([array count] == 0)
    {
        [orderedKeys_ removeObject:key];
        [dictionary_ removeObjectForKey:key];
    }
}

#pragma mark - sorting
- (void)insertKeySorted:(id)key
{
    if ([orderedKeys_ count] == 0)
    {
        [orderedKeys_ addObject:key];
        return;
    }
    
    __block NSUInteger insertIndex = -1;
    __block NSInvocation *selectorInvocation = nil;
    if (!usesComparatorForKeys_)
    {
        selectorInvocation = [NSInvocation invocationWithMethodSignature:[key methodSignatureForSelector:keySortSelector_]];
        [selectorInvocation setTarget:key];
        [selectorInvocation setSelector:keySortSelector_];
    }
    
    [orderedKeys_ enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx  < [orderedKeys_ count])
        {     
            NSComparisonResult result = NSOrderedAscending;
            if (usesComparatorForKeys_)
            {
                result = self.keySortComparator(key, obj);
            }
            else
            {
                [selectorInvocation setArgument:&obj atIndex:2];
                [selectorInvocation invoke];
                [selectorInvocation getReturnValue:&result];
            }
            
            if (result == NSOrderedAscending)
            {
                insertIndex = idx;
                *stop = YES;
            }
                                
        }
    }];
    
    if (insertIndex == -1)
    {
        [orderedKeys_ addObject:key];
    }
    else
    {
        [orderedKeys_ insertObject:key atIndex:insertIndex];
    }
}

- (void)insertObject:(id)object array:(NSMutableArray *)array
{
    if ([array count] == 0)
    {
        [array addObject:object];
        return;
    }
    
    __block NSUInteger insertIndex = -1;
    __block NSInvocation *selectorInvocation = nil;
    if (!usesComparatorForObjects_)
    {
        selectorInvocation = [NSInvocation invocationWithMethodSignature:[object methodSignatureForSelector:objectSortSelector_]];
    }
    
    [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSComparisonResult result = NSOrderedAscending;
        
        if (usesComparatorForObjects_)
        {
            result = self.objectSortComparator(object, obj);
        }
        else
        {
            [selectorInvocation setArgument:&obj atIndex:2];
            [selectorInvocation invoke];
            [selectorInvocation getReturnValue:&result];
            //result = [object performSelector:objectSortSelector_ withObject:obj];
        }
        
        if (result == NSOrderedAscending)
        {
            insertIndex = idx;
            *stop = YES;
        }
    }];
    
    if (insertIndex == -1)
    {
        [array addObject:object];
    }
    else
    {
        [array insertObject:object atIndex:insertIndex];
    }
}

#pragma mark -  handling selectors and comparators
- (void)setKeySortSelector:(SEL)keySortSelector
{
    if (keySortSelector != keySortSelector_)
    {
        keySortSelector_ = keySortSelector;
    }
    
    sortsKeys_ = keySortSelector_ != NULL;
    usesComparatorForKeys_ = keySortSelector_ == NULL;
}

- (void)setObjectSortSelector:(SEL)objectSortSelector
{
    if (objectSortSelector != objectSortSelector_)
    {
        objectSortSelector_ = objectSortSelector;
    }
    
    sortsObjects_ = objectSortSelector_ != NULL;
    usesComparatorForObjects_ = objectSortComparator_ == NULL;
}

- (void)setKeySortComparator:(NSComparator)keySortComparator
{
    if (keySortComparator != keySortComparator_)
    {
        [keySortComparator_ release];
        keySortComparator_ = Block_copy(keySortComparator);
    }
    
    sortsKeys_ = keySortComparator != nil;
}

- (void)setObjectSortComparator:(NSComparator)objectSortComparator
{
    if (objectSortComparator != objectSortComparator_)
    {
        [objectSortComparator_ release];
        objectSortComparator_ = Block_copy(objectSortComparator);
    }
    
    sortsObjects_ = objectSortComparator != nil;
}

@end
