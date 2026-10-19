import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OFL requires the licence to travel with the fonts: shown in the
/// app's licences page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final cairo = await rootBundle.loadString('assets/fonts/OFL-Cairo.txt');
    yield LicenseEntryWithLineBreaks(['Cairo'], cairo);
    final noto = await rootBundle.loadString('assets/fonts/OFL-Noto.txt');
    yield LicenseEntryWithLineBreaks([
      'NotoSans',
      'NotoSansMath',
      'NotoSansSymbols',
    ], noto);
  });
}
