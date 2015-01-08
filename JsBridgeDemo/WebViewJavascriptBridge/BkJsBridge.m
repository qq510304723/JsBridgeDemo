//
//  WebViewJavascriptBridge.m
//  ExampleApp-iOS
//
//  Created by Marcus Westin on 6/14/13.
//  Copyright (c) 2013 Marcus Westin. All rights reserved.
//

#import "BkJsBridge.h"

@implementation BkJsBridge
{
    UIWebView *_webView;
    NSMutableDictionary *_responseCallbackDic;
    NSMutableDictionary *_messageHandlerDic;
    long _uniqueId;
    NSUInteger _numRequestsLoading;
}

#pragma mark - public
//初始化
- (id)initBridgeForWebView:(UIWebView *)webView
{
    self = [super init];
    if (self)
    {
        _webView = webView;
        _webView.delegate = self;
        _messageHandlerDic = [[NSMutableDictionary alloc] init];
        _responseCallbackDic = [[NSMutableDictionary alloc] init];
        _uniqueId = 0;
    }
    
    return self;
}

//注册oc方法，供js调用
- (void)registerHandler:(NSString *)handlerName handler:(WVJBHandler)handler
{
    [_messageHandlerDic setObject:handler forKey:handlerName];
}

//oc调用 js方法
- (void)callHandler:(NSString *)handlerName data:(id)data responseCallback:(WVJBResponseCallback)responseCallback
{
    NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
    if (data)
    {
        [message setObject:data forKey:@"data"];
    }
    
    if (responseCallback)
    {
        NSString *callbackId = [NSString stringWithFormat:@"objc_cb_%ld", ++_uniqueId];
        [_responseCallbackDic setObject:responseCallback forKey:callbackId];
        [message setObject:callbackId forKey:@"callbackId"];
    }
    
    if (handlerName)
    {
        [message setObject:handlerName forKey:@"handlerName"];
    }
    
    [self queueMessage:message];
}

#pragma mark - private
//运行消息队列
- (void)queueMessage:(NSDictionary *)message
{
    //序列化JSON
    NSString *messageJSON = [self serializeMessage:message];
    
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\'" withString:@"\\\'"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    messageJSON = [messageJSON stringByReplacingOccurrencesOfString:@"\f" withString:@"\\f"];
    
    NSString *javascriptCommand = [NSString stringWithFormat:@"BkJsBridge.handleMessageFromObjC('%@');", messageJSON];
    if ([[NSThread currentThread] isMainThread])
    {
        [_webView stringByEvaluatingJavaScriptFromString:javascriptCommand];
    }
}

//刷新消息队列
- (void)refreshMessageQueue
{
    NSString *messageQueueString = [_webView stringByEvaluatingJavaScriptFromString:@"BkJsBridge.fetchQueue();"];
    
    //反序列化JSON
    id messages = [self deserializeMessageJSON:messageQueueString];
    if (![messages isKindOfClass:[NSArray class]])
    {
        return;
    }
    
    for (NSDictionary *message in messages)
    {
        if (![message isKindOfClass:[NSDictionary class]])
        {
            continue;
        }
        
        NSString *responseId = [message objectForKey:@"responseId"];
        if (responseId)
        {
            WVJBResponseCallback responseCallback = [_responseCallbackDic objectForKey:responseId];
            responseCallback([message objectForKey:@"responseData"]);
            [_responseCallbackDic removeObjectForKey:responseId];
        }
        else
        {
            WVJBResponseCallback responseCallback = NULL;
            NSString *callbackId = [message objectForKey:@"callbackId"];
            if (callbackId)
            {
                responseCallback = ^(id responseData)
                {
                    NSDictionary* msg = @{ @"responseId":callbackId, @"responseData":responseData };
                    [self queueMessage:msg];
                };
            }
            else
            {
                responseCallback = ^(id ignoreResponseData)
                {
                    // Do nothing
                };
            }
            
            WVJBHandler handler;
            if ([message objectForKey:@"handlerName"])
            {
                handler = [_messageHandlerDic objectForKey:[message objectForKey:@"handlerName"]];
                if (!handler)
                {
                    return responseCallback(@{});
                }
            }
            else
            {
                
            }
            
            @try
            {
                id data = [message objectForKey:@"data"];
                handler(data, responseCallback);
            }
            @catch (NSException *exception)
            {
                NSLog(@"BkJsBridge: WARNING: objc handler threw. %@ %@", message, exception);
            }
        }
    }
}

//序列化JSON
- (NSString *)serializeMessage:(id)message
{
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:message options:0 error:nil] encoding:NSUTF8StringEncoding];
}

//反序列化JSON
- (NSArray *)deserializeMessageJSON:(NSString *)messageJSON
{
    return [NSJSONSerialization JSONObjectWithData:[messageJSON dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:nil];
}

#pragma mark - UIWebViewDelegate
#pragma mark - UIWebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (webView != _webView)
    {
        return;
    }
    
    _numRequestsLoading--;
    
    if (_numRequestsLoading == 0 && ![[webView stringByEvaluatingJavaScriptFromString:@"typeof BkJsBridge == 'object'"] isEqualToString:@"true"])
    {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"BkJsBridge" ofType:@"js"];
        NSString *js = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        [webView stringByEvaluatingJavaScriptFromString:js];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if (webView != _webView)
    {
        return;
    }
    
    _numRequestsLoading--;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (webView != _webView)
    {
        return YES;
    }
    
    NSURL *url = [request URL];
    if ([[url scheme] isEqualToString:kCustomProtocolScheme])
    {
        if ([[url host] isEqualToString:kQueueHasMessage])
        {
            [self refreshMessageQueue];
        }
        else
        {
            NSLog(@"BkJsBridge: WARNING: Received unknown BkJsBridge command %@://%@", kCustomProtocolScheme, [url path]);
        }
        
        return NO;
    }
    else
    {
        return YES;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    if (webView != _webView)
    {
        return;
    }
    
    _numRequestsLoading++;
}

@end
