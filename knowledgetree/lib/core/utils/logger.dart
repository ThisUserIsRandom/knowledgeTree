import 'dart:developer' as dev;

abstract class Logger {
  static void info(String msg) => dev.log(msg, name: 'KT');
  static void debug(String msg) => dev.log(msg, name: 'KT');
  static void error(String msg) => dev.log(msg, name: 'KT', level: 1000);
}
