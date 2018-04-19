// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/io;

//Includes all the transforming functions which transform required json to type object/record and vice versa

documentation{
    Transforms JSON mail object into Message type object.

    P{{sourceMailJsonObject}} - Json mail object
    R{{}} - Message type object if the conversion is successful.
    R{{}} - GMailError if the conversion is unsuccessful.
}
function convertJsonMailToMessage(json sourceMailJsonObject) returns Message|GMailError {
    Message targetMessageType;
    targetMessageType.id = sourceMailJsonObject.id.toString();
    targetMessageType.threadId = sourceMailJsonObject.threadId.toString() ;
    targetMessageType.labelIds = sourceMailJsonObject.labelIds != () ?
                                        convertJSONArrayToStringArray(sourceMailJsonObject.labelIds) : [];
    targetMessageType.raw = sourceMailJsonObject.raw.toString();
    targetMessageType.snippet = sourceMailJsonObject.snippet.toString();
    targetMessageType.historyId = sourceMailJsonObject.historyId.toString();
    targetMessageType.internalDate = sourceMailJsonObject.internalDate.toString();
    targetMessageType.sizeEstimate = sourceMailJsonObject.sizeEstimate.toString();
    targetMessageType.headers = sourceMailJsonObject.payload.headers != () ?
                                        convertToMsgPartHeaders(sourceMailJsonObject.payload.headers) : [];
    targetMessageType.headerTo = sourceMailJsonObject.payload.headers != () ?
                                getMsgPartHeaderTo(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.headerFrom = sourceMailJsonObject.payload.headers != () ?
                            getMsgPartHeaderFrom(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.headerCc = sourceMailJsonObject.payload.headers != () ?
                                getMsgPartHeaderCc(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.headerBcc = sourceMailJsonObject.payload.headers != () ?
                                getMsgPartHeaderBcc(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.headerSubject = sourceMailJsonObject.payload.headers != () ?
                            getMsgPartHeaderSubject(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.headerDate = sourceMailJsonObject.payload.headers != () ?
                            getMsgPartHeaderDate(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.headerContentType = sourceMailJsonObject.payload.headers != () ?
                        getMsgPartHeaderContentType(convertToMsgPartHeaders(sourceMailJsonObject.payload.headers)) : {};
    targetMessageType.mimeType = sourceMailJsonObject.payload.mimeType.toString();
    string payloadMimeType = sourceMailJsonObject.payload.mimeType.toString();
    if (sourceMailJsonObject.payload != ()){
        match getMessageBodyPartFromPayloadByMimeType(sourceMailJsonObject.payload, TEXT_PLAIN){
            MessageBodyPart body => targetMessageType.plainTextBodyPart = body;
            GMailError gmailError => return gmailError;
        }
        match getMessageBodyPartFromPayloadByMimeType(sourceMailJsonObject.payload, TEXT_HTML){
            MessageBodyPart body => targetMessageType.htmlBodyPart = body;
            GMailError gmailError => return gmailError;
        }
        match getInlineImgPartsFromPayloadByMimeType(sourceMailJsonObject.payload, []){
            MessageBodyPart[] bodyParts => targetMessageType.inlineImgParts = bodyParts;
            GMailError gmailError => return gmailError;
        }
    }
    targetMessageType.msgAttachments = sourceMailJsonObject.payload != () ?
                                                getAttachmentPartsFromPayload(sourceMailJsonObject.payload, []) : [];
    return targetMessageType;
}

documentation{
    Transforms MIME Message Part Json into MessageBody type object.

    P{{sourceMessagePartJsonObject}} - Json message part object
    R{{}} - MessageBodyPart type object if the conversion successful.
    R{{}} - GMailError if conversion unsuccesful.
}
function convertJsonMsgBodyPartToMsgBodyType(json sourceMessagePartJsonObject) returns MessageBodyPart|GMailError {
    MessageBodyPart targetMessageBodyType;
    if (sourceMessagePartJsonObject != ()){
        targetMessageBodyType.fileId = sourceMessagePartJsonObject.body.attachmentId.toString();
        match decodeMsgBodyData(sourceMessagePartJsonObject){
            string decodeBody => targetMessageBodyType.body = decodeBody;
            GMailError gMailError => return gMailError;
        }
        targetMessageBodyType.size = sourceMessagePartJsonObject.body.size.toString();
        targetMessageBodyType.mimeType = sourceMessagePartJsonObject.mimeType.toString();
        targetMessageBodyType.partId = sourceMessagePartJsonObject.partId.toString();
        targetMessageBodyType.fileName = sourceMessagePartJsonObject.filename.toString();
        targetMessageBodyType.bodyHeaders = sourceMessagePartJsonObject.headers != () ?
                                                convertToMsgPartHeaders(sourceMessagePartJsonObject.headers) : [];
    }
    return targetMessageBodyType;
}

documentation{
    Transforms MIME Message Part JSON into MessageAttachment type object.

    P{{sourceMessagePartJsonObject}} - Json message part object
    R{{}}- MessageAttachment type object
}
function convertJsonMsgPartToMsgAttachment(json sourceMessagePartJsonObject) returns MessageAttachment {
    MessageAttachment targetMessageAttachmentType;
    targetMessageAttachmentType.attachmentFileId = sourceMessagePartJsonObject.body.attachmentId.toString();
    targetMessageAttachmentType.attachmentBody = sourceMessagePartJsonObject.body.data.toString();
    targetMessageAttachmentType.size = sourceMessagePartJsonObject.body.size.toString();
    targetMessageAttachmentType.mimeType = sourceMessagePartJsonObject.mimeType.toString();
    targetMessageAttachmentType.partId = sourceMessagePartJsonObject.partId.toString();
    targetMessageAttachmentType.attachmentFileName = sourceMessagePartJsonObject.filename.toString();
    targetMessageAttachmentType.attachmentHeaders = sourceMessagePartJsonObject.headers != () ?
                                                    convertToMsgPartHeaders(sourceMessagePartJsonObject.headers) : [];
    return targetMessageAttachmentType;
}

documentation{
    Transforms MIME Message Part Header into MessagePartHeader type.

    P{{sourceMessagePartHeader}} - Json message part header object
    R{{}} - MessagePartHeader type
}
function convertJsonToMesagePartHeader(json sourceMessagePartHeader) returns MessagePartHeader {
    MessagePartHeader targetMessagePartHeader;
    targetMessagePartHeader.name = sourceMessagePartHeader.name.toString();
    targetMessagePartHeader.value = sourceMessagePartHeader.value.toString();
    return targetMessagePartHeader;
}

documentation{
    Transforms single body of MIME Message part into MessageAttachment type object.

    P{{sourceMessageBodyJsonObject}} - Json message body object
    R{{}} - MessageAttachment type object
}
function convertJsonMessageBodyToMsgAttachment(json sourceMessageBodyJsonObject) returns MessageAttachment {
    MessageAttachment targetMessageAttachmentType;
    targetMessageAttachmentType.attachmentFileId = sourceMessageBodyJsonObject.attachmentId.toString();
    targetMessageAttachmentType.attachmentBody = sourceMessageBodyJsonObject.data.toString();
    targetMessageAttachmentType.size = sourceMessageBodyJsonObject.size.toString();
    return targetMessageAttachmentType;
}

documentation{
    Transforms mail thread Json object into Thread type

    P{{sourceThreadJsonObject}} - Json message thread object
    R{{}} - Thread type
    R{{}} - GMailError if conversion is unsuccessful.
}
function convertJsonThreadToThreadType(json sourceThreadJsonObject) returns Thread|GMailError{
    Thread targetThreadType;
    targetThreadType.id = sourceThreadJsonObject.id.toString();
    targetThreadType.historyId = sourceThreadJsonObject.historyId.toString();
    if (sourceThreadJsonObject.messages != ()){
        match (convertToMessageArray(sourceThreadJsonObject.messages)){
            Message[] msgs => targetThreadType.messages = msgs;
            GMailError gMailError => return gMailError;
        }
    }
    return targetThreadType;
}

documentation{
    Transforms user profile json object into UserProfile type.

    P{{sourceUserProfileJsonObject}} - Json user profile object
    R{{}} - UserProfile type
}
function convertJsonProfileToUserProfileType(json sourceUserProfileJsonObject) returns UserProfile {
    UserProfile targetUserProfile;
    targetUserProfile.emailAddress = sourceUserProfileJsonObject.emailAddress.toString();
    targetUserProfile.threadsTotal = sourceUserProfileJsonObject.threadsTotal.toString();
    targetUserProfile.messagesTotal = sourceUserProfileJsonObject.messagesTotal.toString();
    targetUserProfile.historyId = sourceUserProfileJsonObject.historyId.toString();
    return targetUserProfile;
}