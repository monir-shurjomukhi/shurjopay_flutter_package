library shurjopay;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

part 'token.dart';
part 'required_data.dart';
part 'checkout_request.dart';
part 'checkout_response.dart';
part 'transaction_info.dart';

class Shurjopay extends StatefulWidget {
  final RequiredData data;
  final Function onSuccess;
  final Function onFail;

  const Shurjopay({
    Key? key,
    required this.data,
    required this.onSuccess,
    required this.onFail,
  }) : super(key: key);

  @override
  _ShurjopayState createState() => _ShurjopayState();
}

class _ShurjopayState extends State<Shurjopay> {
  late WebViewController _controller;
  late Token _token;
  late CheckoutResponse _checkoutResponse;

  @override
  void initState() {
    super.initState();

    _showLoaderDialog();
    _createToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('shurjoPay'),
      ),
      body: WebView(
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) {
          _controller = controller;
        },
        onPageStarted: (url) {
          debugPrint('url = $url');
          if (url.contains('cancel_url')) {
            Navigator.pop(context);
            widget.onFail('Payment Cancelled!');
          }
          if (url.contains("return_url") && url.contains("order_id")) {
            _verifyPayment();
          }
        },
      ),
    );
  }

  void _showLoaderDialog() async {
    await Future.delayed(const Duration(milliseconds: 10));
    AlertDialog alert = AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          Container(
              margin: const EdgeInsets.only(left: 20.0),
              child: const Text(
                  "Loading...",
                style: TextStyle(
                  fontSize: 20.0
                ),
              )
          ),
        ],
      ),
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void _createToken() async {
    final response = await http.post(
      Uri.parse('https://engine.shurjopayment.com/api/get_token'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'username': widget.data.username,
        'password': widget.data.password,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _token = Token.fromJson(jsonDecode(response.body));
      _getExecuteUrl();
    } else {
      widget.onFail('Payment has been declined from gateway!');
      Navigator.of(context).pop();
      throw Exception('Failed to get token.');
    }
  }

  void _getExecuteUrl() async {
    final response = await http.post(
      Uri.parse('https://engine.shurjopayment.com/api/secret-pay'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${_token.token}',
      },
      body: jsonEncode(<String, dynamic>{
        'token': _token.token.toString(),
        'store_id': _token.store_id!,
        'prefix': widget.data.prefix,
        'currency': widget.data.currency,
        'return_url': "https://www.sandbox.shurjopayment.com/return_url",
        'cancel_url': "https://www.sandbox.shurjopayment.com/cancel_url",
        'amount': widget.data.amount,
        'order_id': widget.data.order_id,
        'discsount_amount': widget.data.discount_amount,
        'disc_percent': widget.data.disc_percent,
        'client_ip': "127.0.0.1",
        'customer_name': widget.data.customer_name,
        'customer_phone': widget.data.customer_phone,
        'customer_email': widget.data.customer_email,
        'customer_address': widget.data.customer_address,
        'customer_city': widget.data.customer_city,
        'customer_state': widget.data.customer_state,
        'customer_postcode': widget.data.customer_postcode,
        'customer_country': widget.data.customer_country,
        'value1': widget.data.value1,
        'value2': widget.data.value2,
        'value3': widget.data.value3,
        'value4': widget.data.value4,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _checkoutResponse = CheckoutResponse.fromJson(jsonDecode(response.body));
      _controller.loadUrl(_checkoutResponse.checkout_url!);
      await Future.delayed(const Duration(milliseconds: 3000));
      Navigator.pop(context);
    } else {
      widget.onFail('Payment has been declined from gateway!');
      Navigator.of(context).pop();
      throw Exception('Failed to get execute url.');
    }
  }

  void _verifyPayment() async {
    _showLoaderDialog();

    final response = await http.post(
      Uri.parse('https://engine.shurjopayment.com/api/verification'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ${_token.token}',
      },
      body: jsonEncode(<String, dynamic>{
        'sp_order_id': _checkoutResponse.sp_order_id,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      TransactionInfo transactionInfo = TransactionInfo.fromJson(jsonDecode(response.body));
      if(transactionInfo.sp_code == '1000') {
        widget.onSuccess(transactionInfo);
      } else {
        widget.onFail(transactionInfo.message.toString());
      }

      Navigator.pop(context);
      Navigator.pop(context);
    } else {
      widget.onFail('Payment has been declined from gateway!');
      Navigator.of(context).pop();
      throw Exception('Failed to get token.');
    }
  }
}
