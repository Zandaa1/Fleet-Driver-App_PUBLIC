// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppChatMessageDto _$AppChatMessageDtoFromJson(Map<String, dynamic> json) =>
    AppChatMessageDto(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      isRead: json['isRead'] as bool,
      isMine: json['isMine'] as bool,
      dateCreated: DateTime.parse(json['dateCreated'] as String),
    );

Map<String, dynamic> _$AppChatMessageDtoToJson(AppChatMessageDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'content': instance.content,
      'imageUrl': instance.imageUrl,
      'isRead': instance.isRead,
      'isMine': instance.isMine,
      'dateCreated': instance.dateCreated.toIso8601String(),
    };

AppConversationDto _$AppConversationDtoFromJson(Map<String, dynamic> json) =>
    AppConversationDto(
      id: json['id'] as String,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num).toInt(),
      dateCreated: DateTime.parse(json['dateCreated'] as String),
    );

Map<String, dynamic> _$AppConversationDtoToJson(AppConversationDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lastMessageText': instance.lastMessageText,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'dateCreated': instance.dateCreated.toIso8601String(),
    };

PagedResponseOfAppChatMessageDto _$PagedResponseOfAppChatMessageDtoFromJson(
  Map<String, dynamic> json,
) => PagedResponseOfAppChatMessageDto(
  items: (json['items'] as List<dynamic>)
      .map((e) => AppChatMessageDto.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalCount: (json['totalCount'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['pageSize'] as num).toInt(),
);

Map<String, dynamic> _$PagedResponseOfAppChatMessageDtoToJson(
  PagedResponseOfAppChatMessageDto instance,
) => <String, dynamic>{
  'items': instance.items,
  'totalCount': instance.totalCount,
  'page': instance.page,
  'pageSize': instance.pageSize,
};

SendAppMessageRequest _$SendAppMessageRequestFromJson(
  Map<String, dynamic> json,
) => SendAppMessageRequest(
  content: json['content'] as String,
  image: json['image'] as String?,
);

Map<String, dynamic> _$SendAppMessageRequestToJson(
  SendAppMessageRequest instance,
) => <String, dynamic>{'content': instance.content, 'image': instance.image};
