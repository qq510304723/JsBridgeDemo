//
//  BKViewController.m
//  JsBridgeDemo
//
//  Created by 李华光 on 14-10-29.
//  Copyright (c) 2014年 bitcare. All rights reserved.
//

#import "BKViewController.h"
#import "BkJsBridge.h"

@interface BKViewController () <UIAlertViewDelegate>
{
    BkJsBridge *_bridge;
    WVJBResponseCallback _callback;
}

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation BKViewController

//加载本地html
- (void)loadExamplePage:(UIWebView *)webView
{
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"ExampleApp" ofType:@"html"];
    NSString* appHtml = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    [webView loadHTMLString:appHtml baseURL:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    _bridge = [[BkJsBridge alloc] initBridgeForWebView:self.webView];
    
    //js调oc方法
    [_bridge registerHandler:@"confirm"
                     handler:^(id data, WVJBResponseCallback responseCallback) {
                         
                         if ([data isKindOfClass:[NSDictionary class]])
                         {
                             _callback = responseCallback;
                             NSDictionary *dict = (NSDictionary *)data;
                             if ([[dict allKeys] count] > 0)
                             {
                                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[dict objectForKey:@"title"]
                                                                                 message:[dict objectForKey:@"message"]
                                                                                delegate:self
                                                                       cancelButtonTitle:[dict objectForKey:@"okButton"]
                                                                       otherButtonTitles:[dict objectForKey:@"cancelButton"], nil];
                                 [alert show];
                             }
                            
                         }
                     }];
    
    //加载html
    [self loadExamplePage:self.webView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// oc调js方法
- (IBAction)callHandler:(id)sender
{
    id data = @{ @"data": @"Hi there, JS!" };
    [_bridge callHandler:@"titleClick" data:data responseCallback:^(id response) {
        
        NSLog(@"js responded: %@", response);
    }];
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        _callback(@{@"result": @YES});
    }
    else
    {
        _callback(@{@"result": @NO});
    }
}

@end
