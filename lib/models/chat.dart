import 'package:json_annotation/json_annotation.dart';

part 'chat.g.dart';

@JsonSerializable()
class AppChatMessageDto {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final String? imageUrl;
  final bool isRead;
  final bool isMine;
  final DateTime dateCreated;

  AppChatMessageDto({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.imageUrl,
    required this.isRead,
    required this.isMine,
    required this.dateCreated,
  });

  factory AppChatMessageDto.fromJson(Map<String, dynamic> json) =>
      _$AppChatMessageDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AppChatMessageDtoToJson(this);
}

@JsonSerializable()
class AppConversationDto {
  final String id;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime dateCreated;

  AppConversationDto({
    required this.id,
    this.lastMessageText,
    this.lastMessageAt,
    required this.unreadCount,
    required this.dateCreated,
  });

  factory AppConversationDto.fromJson(Map<String, dynamic> json) =>
      _$AppConversationDtoFromJson(json);
  Map<String, dynamic> toJson() => _$AppConversationDtoToJson(this);
}

@JsonSerializable()
class PagedResponseOfAppChatMessageDto {
  final List<AppChatMessageDto> items;
  final int totalCount;
  final int page;
  final int pageSize;

  PagedResponseOfAppChatMessageDto({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory PagedResponseOfAppChatMessageDto.fromJson(
    Map<String, dynamic> json,
  ) => _$PagedResponseOfAppChatMessageDtoFromJson(json);
  Map<String, dynamic> toJson() =>
      _$PagedResponseOfAppChatMessageDtoToJson(this);
}

@JsonSerializable()
class SendAppMessageRequest {
  final String content;
  final String? image;

  SendAppMessageRequest({required this.content, this.image});

  factory SendAppMessageRequest.fromJson(Map<String, dynamic> json) =>
      _$SendAppMessageRequestFromJson(json);
  Map<String, dynamic> toJson() => _$SendAppMessageRequestToJson(this);
}
