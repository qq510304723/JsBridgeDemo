//
//  WebViewJavascriptBridge.h
//  ExampleApp-iOS
//
//  Created by Marcus Westin on 6/14/13.
//  Copyright (c) 2013 Marcus Westin. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kCustomProtocolScheme @"wvjbscheme"
#define kQueueHasMessage      @"__WVJB_QUEUE_MESSAGE__"

typedef void (^WVJBResponseCallback)(id responseData);
typedef void (^WVJBHandler)(id data, WVJBResponseCallback responseCallback);

@interface BkJsBridge : NSObject <UIWebViewDelegate>

//初始化
- (id)initBridgeForWebView:(UIWebView *)webView;

//注册 oc方法，供 js调用
- (void)registerHandler:(NSString*)handlerName handler:(WVJBHandler)handler;

// oc调用 js方法
- (void)callHandler:(NSString*)handlerName data:(id)data responseCallback:(WVJBResponseCallback)responseCallback;

@end
