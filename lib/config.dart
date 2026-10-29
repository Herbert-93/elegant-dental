import 'package:intl/intl.dart';

class Cfg {
  // ====== EDIT THESE WITH YOUR REAL CLINIC DETAILS (they appear on every receipt) ======
  static const clinicName = 'Elegant Dental Care';
  static const tagline = 'Quality care for a brighter smile';
  static const address = 'Kira, Mulawa on City Mall';
  static const phone = '0703751724  0778635607  0393101041';
  static const email = 'elegantdentalcare2026@gmail.com';
  static const currency = 'UGX';
  static const countryCode =
      '0393101041'; // used to build WhatsApp numbers (0772... -> 256772...)
  // =====================================================================================

  static const payCash = 'Cash';
  static const payMtn = 'MTN Mobile Money';
  static const payAirtel = 'Airtel Money';
  static const paymentMethods = [
    payCash,
    payMtn,
    payAirtel,
    'Card',
    'Insurance',
    'Bank Transfer'
  ];
  static const expenseCategories = [
    'Dental supplies',
    'Lab fees',
    'Utilities',
    'Staff / wages',
    'Transport',
    'Rent',
    'Cleaning',
    'Other'
  ];
}

String money(num n) => '${Cfg.currency} ${NumberFormat('#,##0.##').format(n)}';
