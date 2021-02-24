import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:square_in_app_payments/models.dart';
import 'package:square_in_app_payments/google_pay_constants.dart'
    as gpConstants;
import 'package:square_in_app_payments/in_app_payments.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      title: "google pay try",
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool googlePayEnabled = false;

  String locationID = "L6QAMVVZWQH73";

  Future<void> initSquareGooglePay() async {
    bool canUseGooglePlay = false;

    if (Platform.isAndroid) {
      await InAppPayments.initializeGooglePay(
        locationID,
        gpConstants.environmentTest,
      );

      canUseGooglePlay = await InAppPayments.canUseGooglePay;
    }

    setState(() {
      googlePayEnabled = canUseGooglePlay;
    });
  }

  String phone = "+447856874102";

  String loginAccessToken;

  Future<String> login() async {
    var body = {
      "phone": "+905454963815",
      "mac": "a28:89",
      "loginType": "venuebot",
      "loginDevice": "MOBILE"
    };

    var headers = {
      "Authorization": null,
      "audience": null,
      "client_id": null,
      "x-ip-address": null
    };

    String url = "https://www.venuebot.app/VenueBotDAL/customerLogin/";
    var response = await http.post(
      url,
      body: jsonEncode(body),
    );

    Map<String, dynamic> responseBody = jsonDecode(response.body);

    String accessToken = responseBody["accessToken"];

    loginAccessToken = accessToken;

    return accessToken;
  }

  String authAccessToken;

  Future<String> auth() async {
    var body = {
      "otp": "0000",
      "mac": "a28:89",
      "loginType": "venuebot",
      "loginDevice": "MOBILE"
    };


    var headers = {
      "Authorization": loginAccessToken,
      "audience": "mobile-customer",
      "Content-type": "application/json"
    };

    String url = "https://www.venuebot.app/VenueBotDAL/customerAccess/";
    var response =
        await http.post(url, body: jsonEncode(body), headers: headers);

    Map<String, dynamic> responseBody = jsonDecode(response.body);

    authAccessToken = responseBody["accessToken"];

    return authAccessToken;
  }

  Future<Map<String, dynamic>> order() async {
    var body = {
      "venueId": 23,
      "customerId": 44,
      "orderType": "TABLE",
      "tableNo": "122",
      "products": [
        {
          "sku": "247",
          "size": {"unit": "1 portion", "price": 8.0, "inStock": false},
          "preference": {"question": "", "choice": ""},
          "addOns": [],
          "numberOfOrder": 2
        }
      ]
    };



    var headers = {
      "Authorization": authAccessToken,
      "audience": "mobile-customer",
      "Content-type": "application/json"
    };

    String url = "https://www.venuebot.app/VenueBotDAL/order/";
    var response =
        await http.post(url, body: jsonEncode(body), headers: headers);

    Map<String, dynamic> responseBody = jsonDecode(response.body);

    int orderId = responseBody["orderId"];
    String squareOrderId = responseBody["squareOrderId"];
    double grandTotal = responseBody["grandTotal"];

    return responseBody;
  }

  Future<void> confirm() async {

    var body = {
      "squareOrderId": squareOrderConfirmId,
      "sourceId": "cnon:card-nonce-ok"
    };

    var headers = {
      "Authorization": authAccessToken,
      "audience": "mobile-customer",
      "Content-type": "application/json"
    };

    String url = "https://www.venuebot.app/VenueBotDAL/payment/";
    var response =
        await http.post(url, body: jsonEncode(body), headers: headers);

    Map<String, dynamic> responseBody = jsonDecode(response.body);

    return responseBody;
  }

  String squareOrderConfirmId;

  Future<void> payWithGoogle() async {

    Map<String, dynamic> orderResult = await order();

    String squareOrderId = orderResult["squareOrderId"];
    squareOrderConfirmId = squareOrderId;
    int orderId = orderResult["orderId"];

    try {
      await InAppPayments.requestGooglePayNonce(
        price: orderResult["grandTotal"].toString(),
        currencyCode: 'USD',
        priceStatus: gpConstants.totalPriceStatusFinal,
        onGooglePayNonceRequestSuccess: _onGooglePayNonceRequestSuccess,
        onGooglePayNonceRequestFailure: _onGooglePayNonceRequestFailure,
        onGooglePayCanceled: _onGooglePayCancel,
      );
    } on InAppPaymentsException catch (e) {}
  }

  void _onGooglePayNonceRequestSuccess(CardDetails result) async {
    try {

      confirm();

      // print("payment done?");
      // take payment with the card nonce details
      // you can take a charge
      // await chargeCard(result);

    } on Exception catch (ex) {
      // handle card nonce processing failure
    }
  }

  void _onGooglePayCancel() {
    // handle google pay canceled
  }

  void _onGooglePayNonceRequestFailure(ErrorInfo errorInfo) {
    // handle google pay failure
  }

  Future<void> _initSquarePayment() async {
    await InAppPayments.setSquareApplicationId('sandbox-sq0idb-c7xlomqnz-ZJ_dU3qvdizw');
  }

  @override
  void initState() {
    super.initState();
    _initSquarePayment();
    initSquareGooglePay();
    login().then((value) => auth());



  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Center(
          child: Text(
            googlePayEnabled ? "Google Pay Enabled" : "Cannot use google pay",
            style: TextStyle(color: Colors.black, fontSize: 35),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          payWithGoogle();
        },
      ),
    );
  }
}
