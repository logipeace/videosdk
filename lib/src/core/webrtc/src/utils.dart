import 'dart:math';

import 'package:encrypt/encrypt.dart';

Random random = Random();

int generateRandomNumber() {
  return random.nextInt(10000000);
}

String decrypt(String encrypted) {
  //hardcode combination of 32 character
  final key = Key.fromUtf8("YSJ!gMW!Y1Eu8j1NTb^rZyQiNLplYz*n");

  //hardcode combination of 16 character
  final iv = IV.fromUtf8("y^LKkEGk0FwxjQ#B");

  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: null));
  Encrypted enBase64 = Encrypted.fromBase64(encrypted);
  final decrypted = encrypter.decrypt(enBase64, iv: iv);
  return decrypted;
}
