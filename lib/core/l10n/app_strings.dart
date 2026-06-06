/// App-wide UI strings in Amharic (አማርኛ) with English fallback keys.
///
/// Usage:
///   import 'package:bingo_mk/core/l10n/app_strings.dart';
///   Text(S.welcomeBack)
abstract class S {
  static bool isAmharic = true;

  // ── Splash ──────────────────────────────────────────────────────────────
  static String get authorizedOnly => isAmharic ? 'የተፈቀደላቸው ሰዎች ብቻ' : 'AUTHORIZED ACCESS ONLY';
  static String get bingo => isAmharic ? 'ቢንጎ' : 'BINGO';
  static const mk               = 'MK';
  static String get establishingSecurity => isAmharic ? 'ደህንነት እየተረጋገጠ ነው…' : 'ESTABLISHING SECURITY';
  static String get ready => isAmharic ? 'ዝግጁ' : 'READY';
  static String get enterLounge => isAmharic ? 'ወደ ቢንጎ ግባ' : 'ENTER LOUNGE';
  static String get tagline => isAmharic ? 'ምርጥ የቢንጎ ጨዋታን ይጫወቱ።' : 'Experience the height of professional bingo.';

  // ── Login ────────────────────────────────────────────────────────────────
  static const vip              = 'ቪአይፒ (VIP)';
  static String get accessOnly => isAmharic ? 'ለተፈቀደላቸው ብቻ' : 'ACCESS ONLY';
  static String get premiumGamingSuite => isAmharic ? 'ፕሪሚየም ጌሚንግ' : 'PREMIUM GAMING SUITE';
  static String get welcomeBack => isAmharic ? 'እንኳን ደህና መጡ' : 'Welcome Back';
  static String get accessAccount => isAmharic ? 'ወደ አካውንትዎ ይግቡ' : 'Access your high-stakes account';
  static String get phoneNumber => isAmharic ? 'ስልክ ቁጥር' : 'Phone Number';
  static String get password => isAmharic ? 'የይለፍ ቃል (Password)' : 'Password';
  static String get forgotPassword => isAmharic ? 'የይለፍ ቃል ረስተዋል?' : 'Forgot Password?';
  static String get or => isAmharic ? 'ወይም' : 'OR';
  static String get biometrics => isAmharic ? 'ባዮሜትሪክስ' : 'Biometrics';
  static String get passkey => isAmharic ? 'ፓስኪ (Passkey)' : 'Passkey';
  static String get signIn => isAmharic ? 'ግባ' : 'SIGN IN';
  static String get noAccount => isAmharic ? 'አካውንት የለዎትም?' : 'Don\'t have an account?';
  static String get signUpNow => isAmharic ? 'አሁን ይመዝገቡ' : 'Sign Up Now';

  // ── Sign Up ──────────────────────────────────────────────────────────────
  static String get createAccount => isAmharic ? 'አካውንት ይፍጠሩ' : 'Create Account';
  static String get joinCommunity => isAmharic ? 'የቢንጎ ማህበረሰብን ይቀላቀሉ' : 'Join the Bingo community';
  static String get phoneHint => isAmharic ? 'ስልክ ቁጥር (ለምሳሌ 0912…)' : 'Phone number (e.g. 0912…)';
  static String get passwordHint => isAmharic ? 'የይለፍ ቃል' : 'Password';
  static String get confirmPasswordHint => isAmharic ? 'የይለፍ ቃልዎን ያረጋግጡ' : 'Confirm password';
  static String get createAccountBtn => isAmharic ? 'አካውንት ይፍጠሩ' : 'CREATE ACCOUNT';
  static String get alreadyHaveAccount => isAmharic ? 'አካውንት አለዎት?' : 'Already have an account?';
  static String get signInLink => isAmharic ? 'ግባ' : 'Sign In';
  static String get confirmAge => isAmharic ? 'እባክዎ ዕድሜዎ 18+ መሆኑን እና በውልና ደንቦቹ መስማማትዎን ያረጋግጡ' : 'Please confirm you are 18+ and agree to the Terms';
  static const iConfirmAge      = 'እኔ ዕድሜዬ ';
  static const years18OrOlder   = '18 ዓመት ወይም ከዚያ በላይ መሆኑን አረጋግጣለሁ';
  static const andAgreeTo       = ' እና በ ';
  static String get termsOfService => isAmharic ? 'የአጠቃቀም ደንቦች' : 'Terms of Service';
  static const agreed           = ' እስማማለሁ።';

  // ── Validation ───────────────────────────────────────────────────────────
  static String get enterValidPhone => isAmharic ? 'ትክክለኛ ስልክ ቁጥር ያስገቡ' : 'Enter a valid phone number';
  static String get atLeast8Chars => isAmharic ? 'ቢያንስ 8 ፊደላት/ቁጥሮች ያስፈልጋሉ' : 'At least 8 characters required';
  static String get passwordsNoMatch => isAmharic ? 'የይለፍ ቃሎቹ አይዛመዱም' : 'Passwords do not match';
  static String get phoneRequired => isAmharic ? 'ስልክ ቁጥር ያስፈልጋል' : 'Phone number required';
  static String get passwordRequired => isAmharic ? 'የይለፍ ቃል ያስፈልጋል' : 'Password required';
  static String get confirmPassRequired => isAmharic ? 'እባክዎ የይለፍ ቃሉን ያረጋግጡ' : 'Please confirm password';
  static String get enterValidNumber => isAmharic ? 'ትክክለኛ ቁጥር ያስገቡ' : 'Enter a valid number';
  static String get insufficientBalance => isAmharic ? 'በቂ ቀሪ ሂሳብ የለም' : 'Insufficient balance';
  static String get referenceRequired => isAmharic ? 'ማጣቀሻ ቁጥር (Reference) ያስፈልጋል' : 'Reference required';
  static String get accountRequired => isAmharic ? 'የባንክ ሂሳብ ቁጥር ያስፈልጋል' : 'Account required';

  // ── Dashboard ────────────────────────────────────────────────────────────
  static String get playNow => isAmharic ? 'አሁኑኑ ይጫወቱ' : 'PLAY NOW';
  static String get wallet => isAmharic ? 'ሂሳብ (ቦርሳ)' : 'Wallet';
  static String get logout => isAmharic ? 'ውጣ' : 'Logout';
  static String get signInBtn => isAmharic ? 'ግባ' : 'SIGN IN';
  static String get signUpBtn => isAmharic ? 'ተመዝገብ' : 'SIGN UP';

  // ── Bottom Nav ───────────────────────────────────────────────────────────
  static String get play => isAmharic ? 'ይጫወቱ' : 'Play';
  static String get profile => isAmharic ? 'መገለጫ' : 'Profile';

  // ── Game Page ────────────────────────────────────────────────────────────
  static String get winners => isAmharic ? 'አሸናፊዎች' : 'WINNERS';
  static String get pending => isAmharic ? 'በመጠባበቅ ላይ' : 'PENDING';
  static String get claims => isAmharic ? 'የቢንጎ ጥያቄዎች' : 'CLAIMS';
  static String get blocked => isAmharic ? 'የታገደ' : 'BLOCKED';
  static String get autoDaub => isAmharic ? 'አውቶማቲክ ምልክት' : 'AUTO-DAUB';
  static String get compact => isAmharic ? 'አጭር ሰሌዳ' : 'COMPACT';
  static String get fullBoard => isAmharic ? 'ሙሉ ሰሌዳ' : 'FULL BOARD';
  static String get claimWindow => isAmharic ? 'የጥያቄ ሰዓት: ' : 'CLAIM WINDOW:';
  static String get buyCards => isAmharic ? 'ካርታዎችን ይግዙ' : 'BUY CARDS';
  static String get buyCartelas => isAmharic ? 'ካርቴላዎችን ይግዙ' : 'BUY CARTELAS';
  static String get maxCardsMsg => isAmharic ? 'በአንድ ጊዜ ቢበዛ 25 ካርታዎች ይፈቀዳሉ — ' : 'Max 25 cards per session —';
  static String get ownedSuffix => isAmharic ? ' የተገዙ' : 'owned';
  static String get card => isAmharic ? 'ካርቴላ' : 'CARD';
  static String get cards => isAmharic ? 'ካርቴላዎች' : 'CARDS';
  static String get youWon => isAmharic ? '🎉 አሸንፈዋል!' : '🎉 YOU WON!';

  // ── Bingo Card ───────────────────────────────────────────────────────────
  static String get invalidCardData => isAmharic ? 'ልክ ያልሆነ የቢንጎ ካርታ መረጃ' : 'Invalid Bingo Card Data';
  static String get notStartedYet => isAmharic ? 'ጨዋታው እስካሁን ቁጥሮችን መሳብ አልጀመረም!' : 'Game hasn\'t started drawing numbers yet!';
  static String get buyingPhaseOnly => isAmharic ? 'መመዝገብ የሚቻለው በካርታ መግዣ ሰዓት ላይ ብቻ ነው!' : 'Registration is only allowed during the Buying Phase!';

  // ── Live Board / Recent Numbers ──────────────────────────────────────────
  static String get last => isAmharic ? 'የመጨረሻው: ' : 'LAST:';

  // ── Session Card ─────────────────────────────────────────────────────────
  static String get session => isAmharic ? 'ሴሽን' : 'Session';
  static String get cardPrice => isAmharic ? 'የካርታ ዋጋ' : 'CARD PRICE';
  static String get yourCards => isAmharic ? 'የእርስዎ ካርታዎች' : 'YOUR CARDS';
  static String get prizePool => isAmharic ? 'የሽልማት ፈንድ' : 'PRIZE POOL';
  static String get buyingEndsIn => isAmharic ? 'መግዣው የሚያበቃው በ' : 'BUYING ENDS IN';
  static String get claimWindowLabel => isAmharic ? 'የቢንጎ ጥያቄ ሰዓት' : 'CLAIM WINDOW';

  // ── Wallet / Payment Page ────────────────────────────────────────────────
  static String get walletTitle => isAmharic ? 'ሂሳብ (ቦርሳ)' : 'WALLET';
  static String get availableBalance => isAmharic ? 'የሚገኝ ቀሪ ሂሳብ' : 'Available Balance';
  static String get deposit => isAmharic ? 'ገንዘብ ያስገቡ' : 'DEPOSIT';
  static String get withdraw => isAmharic ? 'ገንዘብ ያውጡ' : 'WITHDRAW';
  static String get retry => isAmharic ? 'በድጋሚ ይሞክሩ' : 'RETRY';
  static String get depositSubmitted => isAmharic ? 'ሂሳብ ማስገባትዎ በመረጋገጥ ላይ ነው…' : 'Deposit submitted — auto-matching in progress…';
  static String get withdrawalSubmitted => isAmharic ? 'ገንዘብ ማውጣት ጥያቄዎ ተልኳል!' : 'Withdrawal request submitted!';
  static String get rejected => isAmharic ? 'ተቀባይነት አላገኘም' : 'Rejected';
  static String get yourTxRejected => isAmharic ? 'የእርስዎ ' : 'Your';
  static String get ofAmountEtb => isAmharic ? ' ETB ውድቅ ተደርጓል።' : 'of X ETB was rejected.';
  static String get reason => isAmharic ? 'ምክንያት: ' : 'Reason:';
  static String get dismiss => isAmharic ? 'ዝጋ' : 'DISMISS';
  static String get depositRange => isAmharic ? 'የማስገቢያ መጠን: ' : 'Deposit range:';
  static String get copyAccountDetails => isAmharic ? 'የሂሳብ መረጃን ኮፒ ያድርጉ' : 'Copy Account Details';
  static String get noPaymentAccounts => isAmharic ? 'ምንም የክፍያ አማራጮች አልተዘጋጁም' : 'No payment accounts configured';
  static String get submitReference => isAmharic ? 'የማጣቀሻ ቁጥር ያስገቡ' : 'Submit Reference';
  static String get bankPaidTo => isAmharic ? 'የተከፈለበት ባንክ' : 'Bank Paid To';
  static String get amountSent => isAmharic ? 'የተላከው መጠን (ETB)' : 'Amount sent (ETB)';
  static String get transactionRef => isAmharic ? 'የግብይት ማጣቀሻ / FT ቁጥር' : 'Transaction reference / FT number';
  static String get submitDeposit => isAmharic ? 'ማስገቢያውን ላክ' : 'SUBMIT DEPOSIT';
  static String get depositHistory => isAmharic ? 'የማስገቢያ ታሪክ' : 'Deposit History';
  static String get withdrawalRange => isAmharic ? 'የማውጫ መጠን: ' : 'Withdrawal range:';
  static String get withdrawalDetails => isAmharic ? 'የማውጫ መረጃ' : 'Withdrawal Details';
  static String get withdrawalBank => isAmharic ? 'ማውጫ ባንክ' : 'Withdrawal Bank';
  static String get amount => isAmharic ? 'መጠን (ETB)' : 'Amount (ETB)';
  static String get accountPhone => isAmharic ? 'የሂሳብ / ስልክ ቁጥርዎ' : 'Your account / phone number';
  static String get requestWithdrawal => isAmharic ? 'ገንዘብ ማውጣትን ይጠይቁ' : 'REQUEST WITHDRAWAL';
  static String get withdrawalHistory => isAmharic ? 'የማውጫ ታሪክ' : 'Withdrawal History';
  static String get copied => isAmharic ? ' ኮፒ ተደርጓል' : 'copied';
  static String get unknown => isAmharic ? 'ያልታወቀ' : 'Unknown';

  // ── Profile ───────────────────────────────────────────────────────────────
  static String get balance => isAmharic ? 'ቀሪ ሂሳብ' : 'BALANCE';
  static String get account => isAmharic ? 'አካውንት' : 'ACCOUNT';
  static String get phoneNumberLabel => isAmharic ? 'ስልክ ቁጥር' : 'PHONE NUMBER';
  static String get signOut => isAmharic ? 'ውጣ' : 'SIGN OUT';

  // ── Settings Drawer ───────────────────────────────────────────────────────
  static String get settings => isAmharic ? 'ቅንብሮች' : 'Settings';
  static String get preferences => isAmharic ? 'ምርጫዎች' : 'PREFERENCES';
  static String get soundEffects => isAmharic ? 'የድምፅ ውጤቶች' : 'Sound Effects';
  static String get autoDaubSetting => isAmharic ? 'አውቶማቲክ ምልክት ማድረግ' : 'Auto-Daub';
  static String get support => isAmharic ? 'ድጋፍ' : 'SUPPORT';
  static String get contactSupport => isAmharic ? 'ድጋፍ ለማግኘት' : 'Contact Support';
  static String get callSupport => isAmharic ? 'ይደውሉ: +251978187178' : 'Call: +251978187178';
  static String get appVersion => isAmharic ? 'v1.1.0 · ቢንጎ MK' : 'App version';

  // ── Loading ───────────────────────────────────────────────────────────────
  static String get loading => isAmharic ? 'በመጫን ላይ…' : 'Loading…';

  // ── Winning Card Dialog ───────────────────────────────────────────────────
  static String get winningCard => isAmharic ? 'አሸናፊ ካርቴላ' : 'WINNING CARD';

  // ── Card Transparency Dialog ──────────────────────────────────────────────
  static String get close => isAmharic ? 'ዝጋ' : 'Close';

  // ── Game Patterns (Amharic names & descriptions) ────────────────────────
  // Pattern display names
  static String get patternFullHouse => isAmharic ? 'ሙሉ ቤት' : 'Full House';
  static String get patternSingleLine => isAmharic ? 'አንድ መስመር' : 'Single Line';
  static String get patternTwoLines => isAmharic ? 'ሁለት መስመር' : 'Two Lines';
  static String get patternTShape => isAmharic ? 'የ T ቅርፅ' : 'T Shape';
  static String get patternLShape => isAmharic ? 'የ L ቅርፅ' : 'L Shape';
  static String get patternXShape => isAmharic ? 'የ X ቅርፅ' : 'X Shape (diagonal cross)';
  static String get patternPlus => isAmharic ? 'የ + ቅርፅ' : 'Plus / Cross';
  static String get patternCorners => isAmharic ? 'አራቱ ማዕዘኖች' : 'Four Corners';
  static String get patternFrame => isAmharic ? 'ዙሪያ (ፍሬም)' : 'Frame / Border';

  // Pattern descriptions (shown in the help dialog)
  static const patternFullHouseDesc  = 'ለማሸነፍ ሁሉንም 25 የካርታዎን ቁጥሮች ምልክት ያድርጉ።';
  // Mark ALL 25 numbers on your card to win.
  static const patternSingleLineDesc = 'ለማሸነፍ ማንኛውንም 1 ሙሉ አግድም መስመር ምልክት ያድርጉ።';
  // Mark any 1 complete horizontal row to win. (Any row counts!)
  static const patternTwoLinesDesc   = 'ለማሸነፍ ማናቸውንም 2 ሙሉ አግድም መስመሮች ምልክት ያድርጉ።';
  // Mark any 2 complete horizontal rows to win.
  static const patternTShapeDesc     = 'የ T ቅርፅ ለመስራት የላይኛውን መስመር + መካከለኛውን አምድ ምልክት ያድርጉ።';
  // Mark the top row + middle column to form a T shape.
  static const patternLShapeDesc     = 'የ L ቅርፅ ለመስራት የግራውን አምድ + የታችኛውን መስመር ምልክት ያድርጉ።';
  // Mark the left column + bottom row to form an L shape.
  static const patternXShapeDesc     = 'የ X ቅርፅ ለመስራት ሁለቱንም ሰያፍ መስመሮች ምልክት ያድርጉ።';
  // Mark both diagonals (corner to corner) to form an X.
  static const patternPlusDesc       = 'የ + ቅርፅ ለመስራት መካከለኛውን መስመር + መካከለኛውን አምድ ምልክት ያድርጉ።';
  // Mark the middle row + middle column to form a Plus (+).
  static const patternCornersDesc    = 'ለማሸነፍ 4ቱንም የካርታዎን ማዕዘኖች ምልክት ያድርጉ።';
  // Mark all 4 corner cells of your card to win.
  static const patternFrameDesc      = 'ለማሸነፍ የካርታዎን ውጫዊ ዙሪያዎች በሙሉ ምልክት ያድርጉ።';
  // Mark all cells on the outer edge of your card.
  static const patternDefaultDesc    = 'ለማሸነፍ ጎልተው የሚታዩትን ሳጥኖች ምልክት ያድርጉ።';
  // Mark the highlighted cells on your card to win.

  /// Translates a raw [pattern] string (English, from Firestore/admin) into
  /// its Amharic display name.
  static String patternName(String rawPattern) {
    final p = rawPattern.toLowerCase().replaceAll(' ', '_');
    if (p.contains('full') || p.contains('house')) return patternFullHouse;
    if (p.contains('single') || p == 'line' || p == 'one_line') return patternSingleLine;
    if (p.contains('two') || p.contains('double')) return patternTwoLines;
    if (p == 't_shape' || p.contains('t_shape')) return patternTShape;
    if (p == 'l_shape' || p.contains('l_shape')) return patternLShape;
    if (p == 'x' || p.contains('diagonal')) return patternXShape;
    if (p.contains('plus') || p.contains('cross') || p.contains('+')) return patternPlus;
    if (p.contains('corner')) return patternCorners;
    if (p.contains('frame') || p.contains('border')) return patternFrame;
    return rawPattern.toUpperCase().replaceAll('_', ' '); // unknown: show as-is
  }

  /// Translates a raw [pattern] string into its Amharic description.
  static String patternDesc(String rawPattern) {
    final p = rawPattern.toLowerCase().replaceAll(' ', '_');
    if (p.contains('full') || p.contains('house')) return patternFullHouseDesc;
    if (p.contains('single') || p == 'line' || p == 'one_line') return patternSingleLineDesc;
    if (p.contains('two') || p.contains('double')) return patternTwoLinesDesc;
    if (p == 't_shape' || p.contains('t_shape')) return patternTShapeDesc;
    if (p == 'l_shape' || p.contains('l_shape')) return patternLShapeDesc;
    if (p == 'x' || p.contains('diagonal')) return patternXShapeDesc;
    if (p.contains('plus') || p.contains('cross') || p.contains('+')) return patternPlusDesc;
    if (p.contains('corner')) return patternCornersDesc;
    if (p.contains('frame') || p.contains('border')) return patternFrameDesc;
    return patternDefaultDesc;
  }

  // ── Terms of Service (full text) ─────────────────────────────────────────
  static const termsBody =
      'ይህንን የቢንጎ መጫወቻ በመጠቀም በሚከተሉት ደንቦች ተስማምተዋል:\n\n'
      '1. ለመጫወት ቢያንስ የዕድሜ ገደብ 18 ዓመት እና ከዚያ በላይ መሆን አለበት።\n\n'
      '2. ይህ ጨዋታ በእውነተኛ ገንዘብ የሚካሄድ ነው። ማጣት የሚችሉትን ያህል መጠን ብቻ ያስይዙ።\n\n'
      '3. ማናቸውም ሽልማቶች ከመከፈላቸው በፊት የአሸናፊነቱ ካርታ መረጋገጥ ይኖርበታል።\n\n'
      '4. የተጭበረበረ ጥያቄ ማቅረብ ሂሳብዎ እስከመጨረሻው እንዲታገድ ያደርጋል።\n\n'
      '5. ቴክኒካዊ ብልሽቶች ካጋጠሙ ኦፕሬተሩ ጨዋታውን የመሰረዝ እና ክፍያዎችን የመመለስ መብቱ የተጠበቀ ነው።\n\n'
      '6. አለመግባባቶች በሙሉ በኦፕሬተሩ የመጨረሻ ውሳኔ ይፈታሉ።';
}

