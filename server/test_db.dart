import 'dart:io'; void main() async { try { await Socket.connect('localhost', 5432); } catch (e) { print(e); } }
