import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mybank/components/progress.dart';
import 'package:mybank/components/response_dialog.dart';
import 'package:mybank/components/transaction_auth_dialog.dart';
import 'package:mybank/http/webclients/transaction_webclient.dart';
import 'package:mybank/models/contact.dart';
import 'package:mybank/models/transaction.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TransactionForm extends StatefulWidget {
  final Contact contact;

  // ignore: use_key_in_widget_constructors
  const TransactionForm(this.contact);

  @override
  _TransactionFormState createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final TextEditingController _valueController = TextEditingController();
  final TransactionWebClient _webClient = TransactionWebClient();
  final String transactionId = const Uuid().v4();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: const Text("New transaction")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.contact.fullName,
                  style: const TextStyle(
                      fontSize: 56.0, fontWeight: FontWeight.bold)),
              Text("Account: ${widget.contact.accountNumber.toString()}",
                  style: const TextStyle(fontSize: 24.0)),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                    controller: _valueController,
                    style: const TextStyle(fontSize: 24.0),
                    decoration: const InputDecoration(labelText: "Value"),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: SizedBox(
                  width: double.maxFinite,
                  child: ElevatedButton(
                    child: const Text("Transfer",
                        style: TextStyle(
                            fontSize: 18.0, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final double? value =
                          double.tryParse(_valueController.text);
                      final transactionCreated =
                          Transaction(transactionId, value, widget.contact);
                      showDialog(
                          context: context,
                          builder: (contextDialog) {
                            return TransactionAuthDialog(
                                onConfirm: (String password) {
                              _save(transactionCreated, password, context);
                            });
                          });
                    },
                  ),
                ),
              ),
              Visibility(
                child: const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Progress(message: "Sending...")),
                visible: _sending,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save(Transaction transactionCreated, String password,
      BuildContext context) async {
    Transaction transaction =
        await _send(transactionCreated, password, context);
    _showSuccessfulMessage(transaction, context);
  }

  Future<void> _showSuccessfulMessage(
      Transaction transaction, BuildContext context) async {
    await showDialog(
        context: context,
        builder: (contextDialog) {
          return const SucessDialog("Successful transaction");
        });
    Navigator.pop(context);
  }

  Future<Transaction> _send(Transaction transactionCreated, String password,
      BuildContext context) async {
    setState(() {
      _sending = true;
    });
    final Transaction transaction =
        await _webClient.save(transactionCreated, password).catchError((e) {
      FirebaseCrashlytics.instance.setCustomKey("exception", e.toString());
      FirebaseCrashlytics.instance
          .setCustomKey("http_body", transactionCreated.toString());
      FirebaseCrashlytics.instance.recordError(e, null);

      _showFailureMessage(context,
          message: "timeout submitting the transaction");
    }, test: (e) => e is TimeoutException).catchError((e) {
      FirebaseCrashlytics.instance.setCustomKey("exception", e.toString());
      FirebaseCrashlytics.instance
          .setCustomKey("http_body", transactionCreated.toString());
      FirebaseCrashlytics.instance.recordError(e, null);

      _showFailureMessage(context, message: e.message);
    }, test: (e) => e is HttpException).catchError((e) {
      FirebaseCrashlytics.instance.setCustomKey("exception", e.toString());
      FirebaseCrashlytics.instance.setCustomKey("http_code", e.statusCode);
      FirebaseCrashlytics.instance
          .setCustomKey("http_body", transactionCreated.toString());
      FirebaseCrashlytics.instance.recordError(e, null);

      _showFailureMessage(context);
    }, test: (e) => e is Exception).whenComplete(() {
      setState(() {
        _sending = false;
      });
    });
    return transaction;
  }

  void _showFailureMessage(BuildContext context,
      {String message = "Unknown error"}) {
    _showToast(message);
    // final snackBar = SnackBar(
    //   backgroundColor: Theme.of(context).colorScheme.primary,
    //   elevation: 20,
    //   content: Text(
    //     message,
    //     style: const TextStyle(
    //       fontSize: 24,
    //       fontWeight: FontWeight.bold,
    //     ),
    //   ),
    // );
    // ScaffoldMessenger.of(context).showSnackBar(snackBar);
    // showDialog(
    //     context: context,
    //     builder: (contextDialog) {
    //       return FailureDialog(message);
    //     });
  }

  late FToast fToast;

  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);
  }

  _showToast(String message) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning,
            color: Colors.white,
          ),
          const SizedBox(
            width: 12.0,
          ),
          Wrap(children: [
            Text(
              message,
              style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white),
            ),
          ]),
        ],
      ),
    );

    fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: const Duration(seconds: 10),
    );
  }
}
