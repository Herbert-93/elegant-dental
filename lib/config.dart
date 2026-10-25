import 'package:intl/intl.dart';

class Cfg {
  static const clinicName = 'Elegant Dental Care';
  static const address = 'Kira, Mulawa on City Mall';
  static const phone = '0703751724  0778635607  0393101041';
  static const currency = 'UGX'; // change to your currency
  static const paymentMethods = [
    'Cash',
    'Mobile Money',
    'Card',
    'Insurance',
    'Bank Transfer',
  ];
}

String money(num n) => '${Cfg.currency} ${NumberFormat('#,##0.##').format(n)}';
