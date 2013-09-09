//
//  LFViewController.m
//  CommentStream
//
//  Created by Eugene Scherba on 8/7/13.
//  Copyright (c) 2013 Livefyre. All rights reserved.
//

#import <StreamHub-iOS-SDK/LFSClient.h>
#import <DTCoreText/DTImageTextAttachment.h>
#import <DTCoreText/DTLinkButton.h>
#import <AFNetworking/AFImageRequestOperation.h>

#import "LFSConfig.h"
#import "DTLazyImageView+TextContentView.h"
#import "LFSAttributedTextCell.h"
#import "LFSViewController.h"

@interface LFSViewController () <DTAttributedTextContentViewDelegate, DTLazyImageViewDelegate>
@property (nonatomic, strong) NSMutableDictionary *authors;
@property (nonatomic, strong) NSMutableArray *content;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic, readonly) LFSBootstrapClient *bootstrapClient;
@property (strong, nonatomic, readonly) LFSStreamClient *streamClient;

- (BOOL)canReuseCells;
@end

// identifier for cell reuse
NSString * const AttributedTextCellReuseIdentifier = @"AttributedTextCellReuseIdentifier";

@implementation LFSViewController
{
    BOOL     _useStaticRowHeight;
    NSCache* _cellCache;
}

#pragma mark - properties
@synthesize authors = _authors;
@synthesize content = _content;
@synthesize bootstrapClient = _bootstrapClient;
@synthesize streamClient = _streamClient;
@synthesize dateFormatter = _dateFormatter;

- (LFSBootstrapClient*)bootstrapClient
{
    if (_bootstrapClient == nil) {
        _bootstrapClient = [LFSBootstrapClient
                            clientWithNetwork:[LFSConfig objectForKey:@"domain"]
                            environment:[LFSConfig objectForKey:@"environment"] ];
    }
    return _bootstrapClient;
}

- (LFSStreamClient*)streamClient
{
    if (_streamClient == nil) {
        _streamClient = [LFSStreamClient
                         clientWithNetwork:[LFSConfig objectForKey:@"domain"]
                         environment:[LFSConfig objectForKey:@"environment"]];
        
        __weak typeof(self) weakSelf = self;
        [self.streamClient setResultHandler:^(id responseObject) {
            [weakSelf addTopLevelContent:[[responseObject objectForKey:@"states"] allValues]
                             withAuthors:[responseObject objectForKey:@"authors"]];
            
        } success:nil failure:nil];
    }
    return _streamClient;
}

-(void)addTopLevelContent:(NSArray*)content withAuthors:(NSDictionary*)authors
{
    // in this sample app, we update the model in the most simplistic way --
    // only insert new comments that are not children of other comments
    [self.authors addEntriesFromDictionary:authors];
    
    NSPredicate *p = [NSPredicate predicateWithFormat:@"content.parentId == ''"];
    NSArray *filteredContent = [content filteredArrayUsingPredicate:p];
    NSRange contentSpan;
    contentSpan.location = 0;
    contentSpan.length = [filteredContent count];
    [self.content insertObjects:filteredContent
                      atIndexes:[NSIndexSet indexSetWithIndexesInRange:contentSpan]];
    
    // also cause table to redraw
    if ([filteredContent count] == 1u) {
        // animate insertion
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:
                                                [NSIndexPath indexPathForRow:0 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
        [self.tableView endUpdates];
    }
    
    [self.tableView reloadData];
}

#pragma mark - Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _authors = [NSMutableDictionary dictionary];
    _content = [NSMutableArray array];
    
    _useStaticRowHeight = NO;
    
    /*
     if you enable static row height in this demo then the cell height is determined from the tableView.rowHeight.
     Cells can be reused in this mode.
     If you disable this then cells are prepared and cached to reused their internal layouter and layoutFrame.
     Reuse is not recommended since the cells are cached anyway.
     */
    
    if (_useStaticRowHeight) {
        self.tableView.rowHeight = 60.0f;
    }
    else {
        // establish a cache for prepared cells because heightForRowAtIndexPath and cellForRowAtIndexPath
        // both need the same cell for an index path
        _cellCache = [[NSCache alloc] init];
    }
    
    // Hide Status Bar
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        // iOS 7
        [self prefersStatusBarHidden];
        [self performSelector:@selector(setNeedsStatusBarAppearanceUpdate)];
    } else {
        // iOS 6
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
    }
    
    // set system cache for URL data to 5MB
    [[NSURLCache sharedURLCache] setMemoryCapacity:1024*1024*5];
    
    self.dateFormatter = [[NSDateFormatter alloc] init];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.bootstrapClient getInitForSite:[LFSConfig objectForKey:@"site"]
                                 article:[LFSConfig objectForKey:@"article"]
                               onSuccess:^(NSOperation *operation, id responseObject) {
                                   NSDictionary *headDocument = [responseObject objectForKey:@"headDocument"];
                                   [self addTopLevelContent:[headDocument objectForKey:@"content"]
                                                withAuthors:[headDocument objectForKey:@"authors"]];
                                   NSDictionary *collectionSettings = [responseObject objectForKey:@"collectionSettings"];
                                   NSString *collectionId = [collectionSettings objectForKey:@"collectionId"];
                                   NSNumber *eventId = [collectionSettings objectForKey:@"event"];
                                   
                                   // we are already on the main queue...
                                   [self.streamClient setCollectionId:collectionId];
                                   [self.streamClient startStreamWithEventId:eventId];
                               }
                               onFailure:^(NSOperation *operation, NSError *error) {
                                   NSLog(@"Error code %d, with description %@", error.code, [error localizedDescription]);
                               }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    _cellCache = nil;
}

- (void) dealloc
{
    _authors = nil;
    _content = nil;
    _cellCache = nil;
}

#pragma mark - UITableViewControllerDelegate

// disable this method to get static height = better performance
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_useStaticRowHeight) {
        return tableView.rowHeight;
    }
    
    LFSAttributedTextCell *cell = (LFSAttributedTextCell *)[self tableView:tableView cellForRowAtIndexPath:indexPath];
    return [cell requiredRowHeightInTableView:tableView];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.content count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // workaround for iOS 5 bug (TODO: remove this)
    NSString *key = [NSString stringWithFormat:@"%d-%d", indexPath.section, indexPath.row];
    
    LFSAttributedTextCell *cell = [_cellCache objectForKey:key];
    
    if (!cell) {
        if ([self canReuseCells]) {
            cell = (LFSAttributedTextCell *)[tableView dequeueReusableCellWithIdentifier:AttributedTextCellReuseIdentifier];
        }
        if (!cell) {
            cell = [[LFSAttributedTextCell alloc] initWithReuseIdentifier:AttributedTextCellReuseIdentifier];
        }
        [cell setAccessoryType:UITableViewCellAccessoryNone];
        [cell.imageView setContentMode:UIViewContentModeScaleAspectFit];
        cell.hasFixedRowHeight = _useStaticRowHeight;
        
        // cache it, if there is a cache
        [_cellCache setObject:cell forKey:key];
        
        // LFAttributedTextCell specifics
        cell.attributedTextContextView.shouldDrawImages = NO;
        cell.attributedTextContextView.delegate = self;
    }
    
    [self configureCell:cell forIndexPath:indexPath];
    return cell;
}

#pragma mark - Private methods

// Hide Status Bar
- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)canReuseCells
{
    // reuse does not work for variable height -- only reuse cells with fixed height
    return (![self respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]);
}

- (void)setImage:(UIImage*)image forCell:(LFSAttributedTextCell*)cell
{
    // scale down image if we are not on a Retina device
    UIScreen *screen = [UIScreen mainScreen];
    if ([screen respondsToSelector:@selector(scale)] && [screen scale] == 2)
    {
        // we are on a Retina device
        cell.imageView.image = image;
        [cell setNeedsLayout];
    } else {
        // we are on a non-Retina device
        dispatch_queue_t queue =
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            
            // scale image on a background thread
            // Note: to keep things simple, we do not worry about aspect ratio
            CGSize size = cell.imageView.frame.size;
            UIGraphicsBeginImageContext(size);
            [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
            UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            // display image on the main thread
            dispatch_sync(dispatch_get_main_queue(), ^{
                cell.imageView.image = scaledImage;
                [cell setNeedsLayout];
            });
        });
    }
}

// called every time a cell is configured
- (void)configureCell:(LFSAttributedTextCell *)cell forIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *content = [[_content objectAtIndex:indexPath.row] objectForKey:@"content"];
    NSDictionary *author = [_authors objectForKey:[content objectForKey:@"authorId"]];
    NSTimeInterval timeStamp = [[content objectForKey:@"createdAt"] doubleValue];
    
    NSString *authorName = [author objectForKey:@"displayName"];
    NSString *avatarURL = [author objectForKey:@"avatar"];
    NSString *bodyHTML = [content objectForKey:@"bodyHtml"];
    
    cell.titleView.text = authorName;
    cell.noteView.text = [self.dateFormatter
                          relativeStringFromDate:
                          [NSDate dateWithTimeIntervalSince1970:timeStamp]];
    
    // load avatar images in a separate queue
    NSURLRequest *request = 
        [NSURLRequest requestWithURL:[NSURL URLWithString:avatarURL]];
    AFImageRequestOperation* operation = [AFImageRequestOperation
                                          imageRequestOperationWithRequest:request
                                          imageProcessingBlock:nil
                                          success: ^(NSURLRequest *req,
                                                     NSHTTPURLResponse *response,
                                                     UIImage *image)
                                          {
                                              [self setImage:image forCell:cell];
                                          }
                                          failure:nil];
    [operation start];
    
    // To test image downloading:
    //NSString *html = [NSString stringWithFormat:@"<img src=\"%@\"/><div style=\"font-family:Avenir\">%@</div>", avatarURL, bodyHTML];
    NSString *html = [NSString stringWithFormat:@"<div style=\"font-family:Avenir\">%@</div>", bodyHTML];
    
    [cell setHTMLString:html];
}

#pragma mark - DTAttributedTextContentViewDelegate
-(UIView*)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView viewForLink:(NSURL *)url identifier:(NSString *)identifier frame:(CGRect)frame
{
    DTLinkButton *btn = [[DTLinkButton alloc] initWithFrame:frame];
    btn.URL = url;
    [btn addTarget:self action:@selector(btnDidClick:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

-(UIView*)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView viewForAttachment:(DTTextAttachment *)attachment frame:(CGRect)frame
{
    if ([attachment isKindOfClass:[DTImageTextAttachment class]]) {
        
        DTLazyImageView *imageView = [[DTLazyImageView alloc] initWithFrame:frame];
        imageView.textContentView = attributedTextContentView;
        imageView.delegate = self;
        
        // defer loading of image under given URL
        imageView.url = attachment.contentURL;
        return imageView;
    }
    return nil;
}

-(void)lazyImageView:(DTLazyImageView *)lazyImageView didChangeImageSize:(CGSize)size
{
    DTAttributedTextContentView *cv = lazyImageView.textContentView;
    NSURL *url = lazyImageView.url;
    //CGSize imageSize = size;
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"contentURL == %@", url];
    // update all attachments that matchin this URL (possibly multiple images with same size)
    for (DTTextAttachment *attachment in [cv.layoutFrame textAttachmentsWithPredicate:pred])
    {
        /*
         attachment.originalSize = imageSize;
         if (!CGSizeEqualToSize(imageSize, attachment.displaySize)) {
         attachment.displaySize = imageSize;
         }*/
        attachment.originalSize = size;
        lazyImageView.bounds = CGRectMake(0, 0, attachment.displaySize.width, attachment.displaySize.height);
    }
    
    // need to reset the layouter because otherwise we get the old framesetter or cached layout frames
    // see https://github.com/Cocoanetics/DTCoreText/issues/307
    cv.layouter = nil;
    
    // here we're layouting the entire string, might be more efficient to only relayout the paragraphs that contain these attachments
    [cv relayoutText];
}
/*
 -(UIView*)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView viewForAttributedString:(NSAttributedString *)string frame:(CGRect)frame
 {
 // initialize and return your view here
 }
 */

#pragma mark - Events

- (IBAction)btnDidClick:(DTLinkButton*)sender
{
    [[UIApplication sharedApplication] openURL:sender.URL];
}

@end
