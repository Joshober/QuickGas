import 'package:flutter/material.dart';

class AnimationConstants {
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve entranceCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
  static const Curve springCurve = Curves.easeInOutCubic;

  static const Duration fastDuration = Duration(milliseconds: 200);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);

  static String heroTagOrderCard(String orderId) => 'order_card_$orderId';
  static String heroTagDeliveryPhoto(String orderId) =>
      'delivery_photo_$orderId';
  static String heroTagUserAvatar(String userId) => 'user_avatar_$userId';
}
