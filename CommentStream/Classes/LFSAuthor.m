//
//  LFSAuthor.m
//  CommentStream
//
//  Created by Eugene Scherba on 9/23/13.
//  Copyright (c) 2013 Livefyre. All rights reserved.
//

#import "LFSAuthor.h"

@implementation LFSAuthor
/*
 * Sample JSON object:
 {
 displayName: "The Latest News",
 tags: [ ],
 profileUrl: "https://twitter.com/#!/all_latestnews",
 avatar: "http://a0.twimg.com/profile_images/3719913420/ecabbb041e3195e10ce87102c91b56aa_normal.jpeg",
 type: 3,
 id: "1463096012@twitter.com"
 }
 
 */

#pragma mark - Properties

@synthesize object = _object;
-(void)setObject:(id)object
{
    if (_object != nil && _object != object) {
        id newObject = [[self.class alloc] initWithObject:object];
        NSString *newId = [newObject idString];
        if (![self.idString isEqualToString:newId]) {
            [NSException raise:@"Object rebase conflict"
                        format:@"Cannot rebase object with id %@ on top %@", self.idString, newId];
        }
        [self resetCached];
    }
    _object = object;
}

-(NSString*)description
{
    return [_object description];
}

#pragma mark -
@synthesize displayName = _displayName;
-(NSString*)displayName
{
    const static NSString* const key = @"displayName";
    if (_displayName == nil) {
        _displayName = [_object objectForKey:key];
    }
    return _displayName;
}

#pragma mark -
@synthesize idString = _idString;
-(NSString*)idString
{
    const static NSString* const key = @"id";
    if (_idString == nil) {
        _idString = [_object objectForKey:key];
    }
    return _idString;
}

#pragma mark -
@synthesize profileUrlString = _profileUrlString;
-(NSString*)profileUrlString
{
    const static NSString* const key = @"profileUrl";
    if (_profileUrlString == nil) {
        _profileUrlString = [_object objectForKey:key];
    }
    return _profileUrlString;
}

#pragma mark -
@synthesize profileUrlStringNoHashBang = _profileUrlStringNoHashBang;
-(NSString*)profileUrlStringNoHashBang
{
    static NSRegularExpression *regex1 = nil;
    static NSString* const regexTemplate1 = @"/";
    if (_profileUrlStringNoHashBang == nil) {
        if (regex1 == nil) {
            NSError *regexError1 = nil;
            regex1 = [NSRegularExpression
                      regularExpressionWithPattern:@"/#!/"
                      options:NSRegularExpressionIgnoreMetacharacters
                      error:&regexError1];
            NSAssert(regexError1 == nil,
                     @"Error creating regex: %@",
                     regexError1.localizedDescription);
        }
        _profileUrlStringNoHashBang =
        [regex1 stringByReplacingMatchesInString:self.profileUrlString
                                         options:0
                                           range:NSMakeRange(0, [self.profileUrlString length])
                                    withTemplate:regexTemplate1];
    }
    return _profileUrlStringNoHashBang;
}

#pragma mark -
@synthesize avatarUrlString = _avatarUrlString;
-(NSString*)avatarUrlString
{
    const static NSString* const key = @"avatar";
    if (_avatarUrlString == nil) {
        _avatarUrlString = [_object objectForKey:key];
    }
    return _avatarUrlString;
}

#pragma mark -
@synthesize avatarUrlString75 = _avatarUrlString75;
-(NSString*)avatarUrlString75
{
    // create 75px avatar url
    static NSRegularExpression *regex1 = nil;
    static NSRegularExpression *regex2 = nil;
    static NSString* const regexTemplate1 = @"$1s=75$2";
    static NSString* const regexTemplate2 = @"/75.$1";
    if (_avatarUrlString75 == nil)
    {
        // We will handle two types of avatar URLs:
        // http://gravatar.com/avatar/c228ecbc43be06cc999c08cf020f9fde/?s=50&d=http://avatars-staging.fyre.co/a/anon/50.jpg
        // http://avatars.fyre.co/a/26/6dbce19ef7452f69164e857d55d173ae/50.jpg?v=1375324889"
        //
        if (regex1 == nil) {
            NSError *regexError1 = nil;
            regex1 = [NSRegularExpression
                      regularExpressionWithPattern:@"([?&])s=50(&?)"
                      options:NSRegularExpressionCaseInsensitive
                      error:&regexError1];
            NSAssert(regexError1 == nil,
                     @"Error creating regex: %@",
                     regexError1.localizedDescription);
        }
        
        if (regex2 == nil) {
            NSError *regexError2 = nil;
            regex2 = [NSRegularExpression
                      regularExpressionWithPattern:@"/50.([a-z]+)\\b"
                      options:NSRegularExpressionCaseInsensitive
                      error:&regexError2];
            NSAssert(regexError2 == nil,
                     @"Error creating regex: %@",
                     regexError2.localizedDescription);
        }
        
        NSString *avatarUrlString1 = [regex1 stringByReplacingMatchesInString:self.avatarUrlString
                                                                      options:0
                                                                        range:NSMakeRange(0, [self.avatarUrlString length])
                                                                 withTemplate:regexTemplate1];
        _avatarUrlString75 = [regex2 stringByReplacingMatchesInString:avatarUrlString1
                                                              options:0
                                                                range:NSMakeRange(0, [avatarUrlString1 length])
                                                         withTemplate:regexTemplate2];
    }
    return _avatarUrlString75;
}

#pragma mark -
@synthesize userType = _userType;
-(NSNumber*)userType
{
    const static NSString* const key = @"type";
    if (_userType == nil) {
        _userType = [_object objectForKey:key];
    }
    return _userType;
}

#pragma mark -
@synthesize userTags = _userTags;
-(NSArray*)userTags
{
    const static NSString* const key = @"tags";
    if (_userTags == nil) {
        _userTags = [_object objectForKey:key];
    }
    return _userTags;
}

#pragma mark -
@synthesize twitterHandle = _twitterHandle;
-(NSString*)twitterHandle
{
    static NSString* const twitterHost = @"twitter.com";
    NSURL *url = [NSURL URLWithString:self.profileUrlStringNoHashBang];
    if ([[url host] isEqualToString:twitterHost]) {
        NSString *handle = [[url pathComponents] lastObject];
        return handle;
    } else {
        return nil;
    }
}

#pragma mark - Lifecycle
-(id)initWithObject:(id)object
{
    self = [super init];
    if (self ) {
        // initialization stuff here
        _object = object;
        [self resetCached];
    }
    return self;
}

-(id)init
{
    // simply call designated initializer
    self = [self initWithObject:nil];
    return self;
}

-(void)dealloc
{
    [self resetCached];
    _object = nil;
}

-(void)resetCached
{
    // reset all cached properties except _object
    _displayName = nil;
    _idString = nil;
    _profileUrlString = nil;
    _profileUrlStringNoHashBang = nil;
    _avatarUrlString = nil;
    _avatarUrlString75 = nil;
    _userType = nil;
    _userTags = nil;
    _twitterHandle = nil;
}

@end
