//
//  UIForLumberjack.m
//  UIForLumberjack
//
//  Created by Kamil Burczyk on 15.01.2014.
//  Copyright (c) 2014 Sigmapoint. All rights reserved.
//

#import "UIForLumberjack.h"
#import "MFMessageComposeViewController+BlocksKit.h"

@interface UIForLumberjack ()<UIActionSheetDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, strong) id<DDLogFormatter> logFormatter;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) NSMutableSet *messagesExpanded;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

@implementation UIForLumberjack

+ (UIForLumberjack*) sharedInstance {
    static UIForLumberjack *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UIForLumberjack alloc] init];
        sharedInstance.messages = [NSMutableArray array];
        sharedInstance.messagesExpanded = [NSMutableSet set];
        
        sharedInstance.tableView = [[UITableView alloc] init];
        sharedInstance.tableView.delegate = sharedInstance;
        sharedInstance.tableView.dataSource = sharedInstance;
        [sharedInstance.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LogCell"];
        sharedInstance.tableView.backgroundColor = [UIColor blackColor];
        sharedInstance.tableView.alpha = 0.9f;
        sharedInstance.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        sharedInstance.dateFormatter = [[NSDateFormatter alloc] init];
        [sharedInstance.dateFormatter setDateFormat:@"HH:mm:ss:SSS"];
    });
    return sharedInstance;
}

#pragma mark - DDLogger
- (void)logMessage:(DDLogMessage *)logMessage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_messages addObject:logMessage];
        
        BOOL scroll = NO;
        if(_tableView.contentOffset.y + _tableView.bounds.size.height >= _tableView.contentSize.height)
            scroll = YES;
        
        
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_messages.count-1 inSection:0];
        [_tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];
        
        if(scroll) {
            [_tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    });
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"LogCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forRowAtIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    DDLogMessage *message = _messages[indexPath.row];
    
    switch (message->logFlag) {
        case LOG_FLAG_ERROR:
            cell.textLabel.textColor = [UIColor redColor];
            break;
            
        case LOG_FLAG_WARN:
            cell.textLabel.textColor = [UIColor orangeColor];
            break;
            
        case LOG_FLAG_DEBUG:
            cell.textLabel.textColor = [UIColor greenColor];
            break;
            
        case LOG_FLAG_VERBOSE:
            cell.textLabel.textColor = [UIColor whiteColor];
            break;
            
        default:
            cell.textLabel.textColor = [UIColor whiteColor];
            break;
    }
    
    cell.textLabel.text = [self textOfMessageForIndexPath:indexPath];
    cell.textLabel.font = [self fontOfMessage];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    cell.backgroundColor = [UIColor clearColor];
}

- (NSString*)textOfMessageForIndexPath:(NSIndexPath*)indexPath
{
    DDLogMessage *message = _messages[indexPath.row];
    if ([_messagesExpanded containsObject:@(indexPath.row)]) {
        return [NSString stringWithFormat:@"[%@] %s:%d [%s]", [_dateFormatter stringFromDate:message->timestamp], message->file, message->lineNumber, message->function];
    } else {
        return [NSString stringWithFormat:@"[%@] %@", [_dateFormatter stringFromDate:message->timestamp], message->logMsg];
    }
}

- (UIFont*)fontOfMessage
{
    return [UIFont systemFontOfSize:9];
}

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *messageText = [self textOfMessageForIndexPath:indexPath];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    return [messageText sizeWithFont:[self fontOfMessage] constrainedToSize:CGSizeMake(self.tableView.bounds.size.width - 30, FLT_MAX)].height + kSPUILoggerMessageMargin;
#else
    return ceil([messageText boundingRectWithSize:CGSizeMake(self.tableView.bounds.size.width - 30, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[self fontOfMessage]} context:nil].size.height + kSPUILoggerMessageMargin);
#endif
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UITableViewHeaderFooterView *header = [[UITableViewHeaderFooterView alloc] init];
    header.contentView.backgroundColor = [UIColor colorWithRed:59/255.0 green:209/255.0 blue:65/255.0 alpha:1];
    header.alpha = 1.0;
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    closeButton.frame = CGRectMake(0, 0, 100, 60);
    [closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(hideLog) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeButton];
    
    UIButton *action = [UIButton buttonWithType:UIButtonTypeCustom];
    [action setTitle:@"More" forState:UIControlStateNormal];
    action.frame = CGRectMake(tableView.frame.size.width - 100, 0, 100 , 60);
    //    action.backgroundColor = [UIColor colorWithRed:59/255.0 green:209/255.0 blue:65/255.0 alpha:1];
    [action addTarget:self action:@selector(showActionSheet) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:action];
    return header;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSNumber *index = @(indexPath.row);
    if ([_messagesExpanded containsObject:index]) {
        [_messagesExpanded removeObject:index];
    } else {
        [_messagesExpanded addObject:index];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - public methods
- (void)showLogInView:(UIView*)view
{
    [view addSubview:self.tableView];
    UITableView *tv = self.tableView;
    tv.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tv]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(tv)]];
    [view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tv]|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(tv)]];
}

- (void)hideLog
{
    [self.tableView removeFromSuperview];
}

- (void)showActionSheet {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Log Options" delegate:self
                                              cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Clear" otherButtonTitles:@"Email", nil];
    [sheet showInView:self.tableView];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (buttonIndex) {
        case 1:
        {
            [self hideLog];
            NSMutableArray *messages = [NSMutableArray array];
            
            [_messages enumerateObjectsUsingBlock:^(DDLogMessage *message, NSUInteger idx, BOOL *stop) {
                NSString *string =  [NSString stringWithFormat:@"[%@] %@", [_dateFormatter stringFromDate:message->timestamp], message->logMsg];
                [messages addObject:string];
            }];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([MFMailComposeViewController canSendMail]) {
                    MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
                    controller.mailComposeDelegate = self;
                    [controller setSubject:@"Debug Log"];
                    
                    NSString *body = [messages componentsJoinedByString:@"\n"];
                    [controller setMessageBody:body isHTML:NO];
                    if (controller) {
                        UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
                        if (rootViewController) {
                            [rootViewController presentViewController:controller animated:YES completion:nil];
                        }
                    }
                }
                else {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't send mail" message:@"Mail is not available" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                }
            });
        }
            break;
        case 0: {
            [_messages removeAllObjects];
            [self.tableView reloadData];
        }
            
            break;
            
        default:
            break;
    }
}


- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [controller dismissViewControllerAnimated:YES completion:nil];
}
@end
