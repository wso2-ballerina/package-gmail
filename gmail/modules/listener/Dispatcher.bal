// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerinax/googleapis.gmail as gmail;

class Dispatcher {
    private boolean isOnNewEmail = false;
    private boolean isOnNewThread = false;
    private boolean isOnEmailLabelAdded = false;
    private boolean isOnEmailStarred = false;
    private boolean isOnEmailLabelRemoved = false;
    private boolean isOnEmailStarRemoved = false;
    private boolean isOnNewAttachment = false;

    private SimpleHttpService httpService;
    private gmail:Client gmailClient;

    isolated function init(SimpleHttpService|HttpService httpService, gmail:Client gmailClient) {

        self.gmailClient = gmailClient;
        self.httpService = httpService;
        string[] methodNames = getServiceMethodNames(self.httpService);
        foreach var methodName in methodNames {
            match methodName {
                "onNewEmail" => {
                    self.isOnNewEmail = true;
                }
                "onNewThread" => {
                    self.isOnNewThread = true;
                }
                "onEmailLabelAdded" => {
                    self.isOnEmailLabelAdded = true;
                }
                "onEmailStarred" => {
                    self.isOnEmailStarred = true;
                }
                "onEmailLabelRemoved" => {
                    self.isOnEmailLabelRemoved = true;
                }
                "onEmailStarRemoved" => {
                    self.isOnEmailStarRemoved = true;
                }
                "onNewAttachment" => {
                    self.isOnNewAttachment = true;
                }
                _ => {
                    log:printError("Unrecognized method [" + methodName + "] found in the implementation");
                }
            }
        }
    }

    isolated function dispatch(gmail:History history) returns @tainted error? {
                if (history?.messagesAdded is gmail:HistoryEvent[] ) {
                    gmail:HistoryEvent[] newMessages = <gmail:HistoryEvent[]>history?.messagesAdded;
                    if ((newMessages.length()>0) && (self.isOnNewEmail || self.isOnNewAttachment || self.isOnNewThread)) {
                        foreach var newMessage in newMessages {
                            if (newMessage.message?.labelIds is string[]) {
                                foreach var labelId in <string[]>newMessage.message?.labelIds {
                                    match labelId{
                                        INBOX =>{
                                            check self.dispatchNewMessage(newMessage);
                                            if (self.isOnNewThread) {
                                                check self.dispatchNewThread(newMessage);
                                            }
                                        }
                                    }
                                }  
                            }        
                        }
                    }
                }
                if (history?.labelsAdded is gmail:HistoryEvent[] ) {
                    gmail:HistoryEvent[] addedlabels = <gmail:HistoryEvent[]>history?.labelsAdded;
                    if ((addedlabels.length()>0) && (self.isOnEmailLabelAdded || self.isOnEmailStarred)) {
                        foreach var addedlabel in addedlabels {
                            if (self.isOnEmailLabelAdded) {
                                check self.dispatchLabelAddedEmail(addedlabel);
                            }
                            if (self.isOnEmailStarred) {
                                check self.dispatchStarredEmail(addedlabel);
                            }
                        }
                    }
                }
                if (history?.labelsRemoved is gmail:HistoryEvent[] ) {
                    gmail:HistoryEvent[] removedLabels = <gmail:HistoryEvent[]>history?.labelsRemoved;
                    if ((removedLabels.length()>0) && (self.isOnEmailLabelRemoved || self.isOnEmailStarRemoved)) {
                        foreach var removedLabel in removedLabels {
                            if (self.isOnEmailLabelRemoved) {
                                check self.dispatchLabelRemovedEmail(removedLabel);
                            }
                            if (self.isOnEmailStarRemoved) {
                                check self.dispatchStarRemovedEmail(removedLabel);
                            }
                        }
                    }
                }
    }

    isolated function dispatchNewMessage(gmail:HistoryEvent newMessage) returns @tainted error? {
        gmail:Message message = check self.gmailClient->readMessage(<@untainted>newMessage.message.id);
        if (self.isOnNewEmail) {
            check callOnNewEmail(self.httpService, message);
        }
        if (self.isOnNewAttachment) {
            if (message?.msgAttachments is gmail:MessageBodyPart[]) {
                gmail:MessageBodyPart[] msgAttachments = <gmail:MessageBodyPart[]>message?.msgAttachments;
                if (msgAttachments.length()>0) {
                    check self.dispatchNewAttachment(msgAttachments, message);
                }
            }
        }        
    }

    isolated function dispatchNewAttachment(gmail:MessageBodyPart[] msgAttachments, gmail:Message message) returns error? {
        MailAttachment mailAttachment = {
            messageId : message.id,
            msgAttachments:  msgAttachments
        };
        check callOnNewAttachment(self.httpService, mailAttachment);  
    }

    isolated function dispatchNewThread(gmail:HistoryEvent newMessage) returns @tainted error? {
        if(newMessage.message.id == newMessage.message.threadId) {               
            gmail:MailThread thread = check self.gmailClient->readThread(<@untainted>newMessage.message.threadId);
            check callOnNewThread(self.httpService, thread);
        }
    }

    isolated function dispatchLabelAddedEmail(gmail:HistoryEvent addedlabel) returns @tainted error? {
        ChangedLabel changedLabel = { messageDetail: {id : "", threadId : ""}, changedLabelId: []};
        if (addedlabel?.labelIds is string []) {
            changedLabel.changedLabelId = <string []>addedlabel?.labelIds;
        }
        gmail:Message message = check self.gmailClient->readMessage(<@untainted>addedlabel.message.id);
        changedLabel.messageDetail = message;
        check callOnEmailLabelAdded(self.httpService, changedLabel);
    }

    isolated function dispatchStarredEmail(gmail:HistoryEvent addedlabel) returns @tainted error? {
        if (addedlabel?.labelIds is string[]) {
            foreach var label in <string[]>addedlabel?.labelIds {
                match label{
                    STARRED =>{
                        gmail:Message message = check self.gmailClient->readMessage(<@untainted>addedlabel.message.id);
                        check callOnEmailStarred(self.httpService, message);
                    }
                }
            }
        }        
    }

    isolated function dispatchLabelRemovedEmail(gmail:HistoryEvent removedLabel) returns @tainted error?{
        ChangedLabel changedLabel = { messageDetail: {id : "", threadId : ""}, changedLabelId: []};
        if (removedLabel?.labelIds is string[]) {
            changedLabel.changedLabelId = <string[]>removedLabel?.labelIds;
        }
        gmail:Message message = check self.gmailClient->readMessage(<@untainted>removedLabel.message.id);
        changedLabel.messageDetail = message;
        check callOnEmailLabelRemoved(self.httpService, changedLabel);
    }

    isolated function dispatchStarRemovedEmail(gmail:HistoryEvent removedLabel) returns @tainted error? {
        if (removedLabel?.labelIds is string[]) {
            foreach var label in <string[]>removedLabel?.labelIds {
                match label{
                    STARRED =>{
                        gmail:Message message = check self.gmailClient->readMessage(<@untainted>removedLabel.message.id);
                        check callOnEmailStarRemoved(self.httpService, message);
                    }
                }
            }
        }        
    }
}
