import 'package:flutter/material.dart';

RoundedRectangleBorder cardBorder = RoundedRectangleBorder(
  borderRadius: BorderRadiusGeometry.circular(20),
  side: BorderSide(width: 2, color: Color.fromARGB(255, 59, 128, 123)),
);

RoundedRectangleBorder dangerCardBorder = RoundedRectangleBorder(
  borderRadius: BorderRadiusGeometry.circular(20),
  side: BorderSide(width: 2, color: Color.fromARGB(128, 244, 67, 54)),
);

Color mainColor = Color.fromARGB(255, 59, 128, 123);
Color secondaryColor = Color.fromARGB(128, 59, 128, 123);
Color dangerColor = Color.fromARGB(255, 244, 67, 54);