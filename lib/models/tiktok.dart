import 'package:http/http.dart' as http;
import 'dart:convert';

class TiktokApiClient {
  late String apiUrl;

  TiktokApiClient({required this.apiUrl});

  Future<Tiktok?> fetchTiktokInfo() async {
    if (apiUrl.isEmpty) {
      return null;
    }

    final response = await http
        .get(Uri.parse("https://www.tikwm.com/api/?url=$apiUrl?hd=1"));

    if (response.statusCode == 200) {
      return Tiktok.fromJson(jsonDecode(response.body));
    } else {
      return null;
    }
  }
}

class Tiktok {
  int? code;
  String? msg;
  double? processedTime;
  Data? data;

  Tiktok({this.code, this.msg, this.processedTime, this.data});

  Tiktok.fromJson(Map<String, dynamic> json) {
    code = json['code'];
    msg = json['msg'];
    processedTime = json['processed_time'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
}

class Data {
  String? play;
  
  Data({this.play});

  Data.fromJson(Map<String, dynamic> json) {
    play = json['play'];
  }
}