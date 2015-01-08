; (function () {
    if (window.BkJsBridge) { return }
    var messagingIframe
    var sendMessageQueue = []
    var receiveMessageQueue = []
    var messageHandlers = {}

    var CUSTOM_PROTOCOL_SCHEME = 'wvjbscheme'
    var QUEUE_HAS_MESSAGE = '__WVJB_QUEUE_MESSAGE__'

    var responseCallbacks = {}
    var uniqueId = 1

    //创建队列准备iframe
    function createQueueReadyIframe(doc) {
        messagingIframe = doc.createElement('iframe')
        messagingIframe.style.display = 'none'
        doc.documentElement.appendChild(messagingIframe)
    }

    function init(messageHandler) {
        if (BkJsBridge.messageHandler) {
            throw new Error('BkJsBridge.init called twice')
        }

        BkJsBridge.messageHandler = messageHandler
        var receivedMessages = receiveMessageQueue
        receiveMessageQueue = null

        for (var i = 0; i < receivedMessages.length; i++) {
            dispatchMessageFromObjC(receivedMessages[i])
        }
    }

    // js发送消息给oc(数据，回调方法)
    function send(data, responseCallback) {
        doSend({ data: data }, responseCallback)
    }

    // oc调js方法(方法名，回调方法)
    function registerHandler(handlerName, handler) {
    		if(handler.length == 0){
    				var innerHandler = function(data, responseCallback){
    					handler.call(this);
    					responseCallback();
    				};
    		}
    		else if(handler.length == 1){
    				innerHandler = function(data, responseCallback){
    					handler.call(this,data);
    					responseCallback();
    				};
    		}
    		else{
    				innerHandler = handler;
    		}
        messageHandlers[handlerName] = innerHandler;
    }

    //js调oc方法(方法名，数据，回调方法)
    function callHandler(handlerName, data, responseCallback) {
   alert("12345")
    		if(arguments.length == 1){
    				data = {};
    				responseCallback = function(result){
    				};
    		}
    		else if(arguments.length == 2){
    				responseCallback = function(result){
    				};
    		}
    		else{
    				
    		}
    		doSend({ handlerName: handlerName, data: data }, responseCallback)        
    }

    function doSend(message, responseCallback) {
        if (responseCallback) {
            var callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime()
            responseCallbacks[callbackId] = responseCallback
            message['callbackId'] = callbackId
        }
        sendMessageQueue.push(message)
        messagingIframe.src = CUSTOM_PROTOCOL_SCHEME + '://' + QUEUE_HAS_MESSAGE
    }

    //获取队列
    function fetchQueue() {
        var messageQueueString = JSON.stringify(sendMessageQueue)
        sendMessageQueue = []
        return messageQueueString
    }

    //获取从oc发送来的消息
    function dispatchMessageFromObjC(messageJSON) {
        setTimeout(function timeoutDispatchMessageFromObjC() {
            var message = JSON.parse(messageJSON)
            var messageHandler

            if (message.responseId) {
                var responseCallback = responseCallbacks[message.responseId]
                if (!responseCallback) { return; }
                responseCallback(message.responseData)
                delete responseCallbacks[message.responseId]
            } else {
                var responseCallback
                if (message.callbackId) {
                    var callbackResponseId = message.callbackId
                    responseCallback = function (responseData) {
                        doSend({ responseId: callbackResponseId, responseData: responseData })
                    }
                }

                var handler = BkJsBridge.messageHandler
                if (message.handlerName) {
                    handler = messageHandlers[message.handlerName]
                }

                try {
                    handler(message.data, responseCallback)
                } catch (exception) {
                    if (typeof console != 'undefined') {
                        console.log("BkJsBridge: WARNING: javascript handler threw.", message, exception)
                    }
                }
            }
        })
    }

    //处理从oc发送来的消息
    function handleMessageFromObjC(messageJSON) {
        if (receiveMessageQueue) {
            receiveMessageQueue.push(messageJSON)
        } else {
            dispatchMessageFromObjC(messageJSON)
        }
    }

    window.BkJsBridge = {
        init: init,
        send: send,
        on: registerHandler,
        call: callHandler,
        fetchQueue: fetchQueue,
        handleMessageFromObjC: handleMessageFromObjC
    }

    var doc = document
    createQueueReadyIframe(doc)

    init(function (data, responseCallback) {
				responseCallback();
    });

    var readyEvent = doc.createEvent('Events')
    readyEvent.initEvent('BkJsBridgeReady')
    readyEvent.bridge = BkJsBridge
    doc.dispatchEvent(readyEvent)
})();
