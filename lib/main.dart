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
  bool applePayEnabled = false;

  String locationID = "L6QAMVVZWQH73";

  Future<void> initSquarePayService() async {
    bool canUseGooglePlay = false;

    if (Platform.isAndroid) {
      await InAppPayments.initializeGooglePay(
        locationID,
        gpConstants.environmentTest,
      );

      canUseGooglePlay = await InAppPayments.canUseGooglePay;
    } else if (Platform.isIOS) {
      await InAppPayments.initializeApplePay('');
      applePayEnabled = await InAppPayments.canUseApplePay;
      setState(() {});
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

  /// Google Pay Configuration
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

  /// ============ ============== =========== ===============

  /// Apple Pay Configuration
  Future<void> payWithApple() async {
    Map<String, dynamic> orderResult = await order();

    String squareOrderId = orderResult["squareOrderId"];
    squareOrderConfirmId = squareOrderId;
    int orderId = orderResult["orderId"];
    String price = orderResult["grandTotal"];

    try {
      await InAppPayments.requestApplePayNonce(
        price: price,
        summaryLabel: "pay",
        countryCode: "+44",
        currencyCode: 'USD',
        onApplePayComplete: onApplePayComplete,
        onApplePayNonceRequestFailure: onApplePayNonceRequestFailure,
        onApplePayNonceRequestSuccess: onApplePayNonceRequestSuccess,
      );
    } on InAppPaymentsException catch (e) {}
  }

  void onApplePayComplete() {}

  void onApplePayNonceRequestFailure(ErrorInfo errorInfo) {}

  void onApplePayNonceRequestSuccess(CardDetails result) {
    confirm();
  }

  /// ============ ============== =========== ===============

  Future<void> _initSquarePayment() async {
    await InAppPayments.setSquareApplicationId(
        'sandbox-sq0idb-c7xlomqnz-ZJ_dU3qvdizw');
  }

  @override
  void initState() {
    super.initState();
    _initSquarePayment();
    initSquarePayService();
    login().then((value) => auth());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                googlePayEnabled
                    ? "Google Pay Enabled"
                    : "Cannot use Google pay",
                style: TextStyle(color: Colors.black, fontSize: 35),
              ),
              SizedBox(height: 50,),
              Text(
                applePayEnabled ? "Apple Pay Enabled" : "Cannot use Apple pay",
                style: TextStyle(color: Colors.black, fontSize: 35),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (Platform.isAndroid) {
            payWithGoogle();
          } else if (Platform.isIOS) {}
        },
      ),
    );
  }
}
