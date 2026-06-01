/// App-wide UI strings in Tigrinya (ትግርኛ) with English fallback keys.
///
/// Usage:
///   import 'package:bingo_mk/core/l10n/app_strings.dart';
///   Text(S.welcomeBack)
abstract class S {
  // ── Splash ──────────────────────────────────────────────────────────────
  static const authorizedOnly   = 'AUTHORIZED ACCESS ONLY';      // AUTHORIZED ACCESS ONLY
  static const bingo            = 'ቢንጎ';                    // BINGO
  static const mk               = 'MK';
  static const establishingSecurity = 'ESTABLISHING SECURITY…'; // ESTABLISHING SECURITY
  static const ready            = 'ተዳሊዩ';                  // READY
  static const enterLounge      = 'ናብ ቢንጎ እቶ';             // ENTER LOUNGE
  static const tagline          = 'ናይ ሞያዊ ቢንጎ ልዑል ተሞኩሮ ተቐበሎ።'; // Experience the height of professional bingo.

  // ── Login ────────────────────────────────────────────────────────────────
  static const vip              = 'VIP';
  static const accessOnly       = 'ፍቑዳት ጥራይ';             // ACCESS ONLY
  static const premiumGamingSuite = 'ፕሪሚየም ጌሚንግ ';     // PREMIUM GAMING SUITE
  static const welcomeBack      = 'እንቋዕ ደሓን ተመለስካ';       // Welcome Back
  static const accessAccount    = 'ሕሳብካ ክፈት';        // Access your high-stakes account
  static const phoneNumber      = 'ቁጽሪ ተሌፎን';             // Phone Number
  static const password         = 'Password';               // Password
  static const forgotPassword   = 'Forgot Password?';         // Forgot Password?
  static const or               = 'ወይ';                     // OR
  static const biometrics       = 'ባዮሜትሪክስ';               // Biometrics
  static const passkey          = 'ፓስኪ';                   // Passkey
  static const signIn           = 'እቶ';                     // SIGN IN
  static const noAccount        = 'ሕሳብ የብልካን?';            // Don't have an account?
  static const signUpNow        = 'ሕጂ ተመዝገብ';              // Sign Up Now

  // ── Sign Up ──────────────────────────────────────────────────────────────
  static const createAccount    = 'ሕሳብ ፍጠር';               // Create Account
  static const joinCommunity    = 'ናብ ቢንጎ መቐለ ማሕበረሰብ ተጸምበር'; // Join the Bingo Mekele community
  static const phoneHint        = 'ቁጽሪ ተሌፎን (ንምሳሌ 0912…)'; // Phone number (e.g. 0912…)
  static const passwordHint     = 'ሕስብ-ቃል';               // Password
  static const confirmPasswordHint = 'ሕስብ-ቃልካ ኣረጋጽ';      // Confirm password
  static const createAccountBtn = 'ሕሳብ ፍጠር';               // CREATE ACCOUNT
  static const alreadyHaveAccount = 'ሕሳብ ኣለካ?';            // Already have an account?
  static const signInLink       = 'እቶ';                     // Sign In
  static const confirmAge       = 'ዕድሚኡ 18+ ምዃኑ ኣረጋጽ';     // Please confirm you are 18+ and agree to the Terms
  static const iConfirmAge      = 'ዕድሚኤ ';
  static const years18OrOlder   = '18 ዓመትን ልዕሊኡን ምዃነይ ኣረጋጽ';
  static const andAgreeTo       = ' ፡ ናብ ';
  static const termsOfService   = 'ናይ ኣገልግሎት ውዕሊ';        // Terms of Service
  static const agreed           = ' ተሰማሚዐ።';

  // ── Validation ───────────────────────────────────────────────────────────
  static const enterValidPhone   = 'ቅኑዕ ቁጽሪ ተሌፎን ኣእቱ';    // Enter a valid phone number
  static const atLeast8Chars     = 'ቢያንስ 8 ፊደላት ኣድለዩ';     // At least 8 characters required
  static const passwordsNoMatch  = 'Passwords do not match';      // Passwords do not match
  static const phoneRequired     = 'ቁጽሪ ተሌፎን ኣድለዩ';        // Phone number required
  static const passwordRequired  = 'Password required';          // Password required
  static const confirmPassRequired = 'Please confirm password';       // Please confirm password
  static const enterValidNumber  = 'ቅኑዕ ቁጽሪ ኣቑም';           // Enter a valid number
  static const insufficientBalance = 'Insufficient balance';          // Insufficient balance
  static const referenceRequired = 'Reference ኣድለዩ';            // Reference required
  static const accountRequired   = 'CBE Account ቁጽሪ ኣድለዩ';         // Account required

  // ── Dashboard ────────────────────────────────────────────────────────────
  static const playNow          = 'ሕጂ ተጻወት';               // PLAY NOW
  static const wallet           = 'ገንዘብ';              // Wallet
  static const logout           = 'ውጺእ';                    // Logout
  static const signInBtn        = 'እቶ';                     // SIGN IN
  static const signUpBtn        = 'ተመዝገብ';                  // SIGN UP

  // ── Bottom Nav ───────────────────────────────────────────────────────────
  static const play             = 'ተጻወት';                   // Play
  static const profile          = 'ፕሮፋይል';                 // Profile

  // ── Game Page ────────────────────────────────────────────────────────────
  static const winners          = 'ተዓወትቲ';                   // WINNERS
  static const pending          = 'ዝጽበ';                    // PENDING
  static const claims           = 'ጠለባት';                   // CLAIMS
  static const blocked          = 'ዝተዓጽወ';                  // BLOCKED
  static const autoDaub         = 'AUTO ምልክት';            // AUTO-DAUB
  static const compact          = 'ሓጺር';                    // COMPACT
  static const fullBoard        = 'ምሉእ ሰሌዳ';               // FULL BOARD
  static const claimWindow      = 'ናይ ጠለብ ሰዓት: ';          // CLAIM WINDOW:
  static const buyCards         = 'ካርታ ዕዘዝ';               // BUY CARDS
  static const buyCartelas      = 'ካርታ ዕዘዝ';               // BUY CARTELAS
  static const maxCardsMsg      = 'Max 25 ካርታ ይፍቀድ — '; // Max 25 cards per session —
  static const ownedSuffix      = ' ዝተዓደጉ';                 // owned
  static const card             = 'ካርቴላ';                    // CARD
  static const cards            = 'ካርቴላታት';                  // CARDS
  static const youWon           = '🎉 ተዓዊትካ!';               // 🎉 YOU WON!

  // ── Bingo Card ───────────────────────────────────────────────────────────
  static const invalidCardData  = 'ዘይቅኑዕ ናይ ቢንጎ ካርታ';     // Invalid Bingo Card Data
  static const notStartedYet    = 'ቁጽሪ ምስሳብ ገና ኣይጀመረን!';  // Game hasn't started drawing numbers yet!
  static const buyingPhaseOnly  = 'ምምዝጋብ ኣብ ናይ ምዕዳግ ሰዓት ጥራይ ይፍቀድ!'; // Registration is only allowed during the Buying Phase!

  // ── Live Board / Recent Numbers ──────────────────────────────────────────
  static const last             = 'ዳሕረዋይ: ';               // LAST:

  // ── Session Card ─────────────────────────────────────────────────────────
  static const session          = 'ሴሽን';                    // Session
  static const cardPrice        = 'ዋጋ ካርቴላ';                // CARD PRICE
  static const yourCards        = 'ካርቴላታትካ';                // YOUR CARDS
  static const prizePool        = 'ሽልማት';              // PRIZE POOL
  static const buyingEndsIn     = 'ምዕዳግ ዝወዳእ ኣብ';          // BUYING ENDS IN
  static const claimWindowLabel = 'ናይ ቢንጎ ሰዓት';            // CLAIM WINDOW

  // ── Wallet / Payment Page ────────────────────────────────────────────────
  static const walletTitle      = 'ገንዘብ';              // WALLET
  static const availableBalance = 'ዝርከብ ገንዘብ';              // Available Balance
  static const deposit          = 'ኣእቱ';                    // DEPOSIT
  static const withdraw         = 'ውሰድ';                    // WITHDRAW
  static const retry            = 'ደጋጊምካ ፈትን';             // RETRY
  static const depositSubmitted = 'ምእታው ይረጋገፅ ኣሎ…'; // Deposit submitted — auto-matching in progress…
  static const withdrawalSubmitted = 'ገንዘብ ወፃኢ ጠይቅካ!';     // Withdrawal request submitted!
  static const rejected         = 'ተነፊጉ';                  // Rejected
  static const yourTxRejected   = 'ናትካ ';                   // Your
  static const ofAmountEtb      = ' ETB ተነፊጉ።';            // of X ETB was rejected.
  static const reason           = 'ምኽንያት: ';               // Reason:
  static const dismiss          = 'ኣይተሳክዐን';                     // DISMISS
  static const depositRange     = 'ናይ ምእታው ዓቐን: ';         // Deposit range:
  static const copyAccountDetails = 'ናይ ሕሳብ ዝርዝር ቅዳሕ';    // Copy Account Details
  static const noPaymentAccounts = 'ናይ ክፍሊያን ሕሳብ ኣይቀረበን'; // No payment accounts configured
  static const submitReference  = 'ማጣቀሻ ኣቕርብ';             // Submit Reference
  static const bankPaidTo       = 'ዝተኸፈለሉ ባንክ';            // Bank Paid To
  static const amountSent       = 'ዝተኸፈለ ብዝሒ (ETB)';       // Amount sent (ETB)
  static const transactionRef   = 'ናይ ክፍሊያን ማጣቀሻ / FT ቁጽሪ'; // Transaction reference / FT number
  static const submitDeposit    = 'ምእታው ኣቕርብ';             // SUBMIT DEPOSIT
  static const depositHistory   = 'ናይ ምእታው ታሪኽ';          // Deposit History
  static const withdrawalRange  = 'ናይ ምውሳድ ዓቐን: ';         // Withdrawal range:
  static const withdrawalDetails = 'ናይ ምውሳድ ዝርዝር';         // Withdrawal Details
  static const withdrawalBank   = 'ናይ ምውሳድ ባንክ';           // Withdrawal Bank
  static const amount           = 'ብዝሒ (ETB)';              // Amount (ETB)
  static const accountPhone     = 'ናይ ሕሳብ / ቁጽሪ ተሌፎን';    // Your account / phone number
  static const requestWithdrawal = 'ምውሳድ ሕተት';             // REQUEST WITHDRAWAL
  static const withdrawalHistory = 'ናይ ምውሳድ ታሪኽ';         // Withdrawal History
  static const copied           = ' ተቐዲሑ';                  // copied
  static const unknown          = 'ዘይፍለጥ';                  // Unknown

  // ── Profile ───────────────────────────────────────────────────────────────
  static const balance          = 'ቀሪ ገንዘብ';                    // BALANCE
  static const account          = 'ሕሳብ';                    // ACCOUNT
  static const phoneNumberLabel = 'ቁጽሪ ተሌፎን';             // PHONE NUMBER
  static const signOut          = 'ውጺእ';                    // SIGN OUT

  // ── Settings Drawer ───────────────────────────────────────────────────────
  static const settings         = 'መቐያዪ';                   // Settings
  static const preferences      = 'ምርጫታት';                  // PREFERENCES
  static const soundEffects     = 'ናይ ድምጺ ጸለዋ';            // Sound Effects
  static const autoDaubSetting  = 'Auto ምልክት';            // Auto-Daub
  static const support          = 'ደገፍ';                    // SUPPORT
  static const contactSupport   = 'ደገፍ ርኸብ';               // Contact Support
  static const callSupport      = 'ደዉል: +251978187178';      // Call: +251978187178
  static const appVersion       = 'v1.0.0 · ቢንጎ መቐለ ብ Toti Tech'; // v1.0.0 · Bingo Mekele by Toti Tech

  // ── Loading ───────────────────────────────────────────────────────────────
  static const loading          = 'ይጽዓን…';                  // Loading…

  // ── Winning Card Dialog ───────────────────────────────────────────────────
  static const winningCard      = 'ዝዓወተ ካርቴላ';              // WINNING CARD

  // ── Card Transparency Dialog ──────────────────────────────────────────────
  static const close            = 'ዕፀ';                     // Close

  // ── Terms of Service (full text) ─────────────────────────────────────────
  static const termsBody =
      'ቢንጎ መቐለ ብምጥቃምካ ምስ ዝስዕቡ ትሰማማዕ:\n\n'
      '1. ንምጽዋት ቢያንስ ዕድሜኻ 18 ዓመት ክኸውን ኣለዎ።\n\n'
      '2. እዚ ብሓቂ ዝካየድ ጸወታ ገንዘብ እዩ። ናይ ምስዓር ተኽእሎ ዘለዎ ገንዘብ ጥራይ ኣቑም።\n\n'
      '3. ቅድሚ ክፍሊያን ናይ ዓወት ካርታ ምርግጋጽ ይሓትት።\n\n'
      '4. ሓሶት ዝሓዘ ጠለብ ሕሳብካ ምቁራጽ ይብጽሕ።\n\n'
      '5. ቴክኒካዊ ጌጋ እንተጋጠመ ኦፐሬተር ሴሽን ናይ ምስረዛን ኣቐዲሙ ዝተኸፈለ ክምለስ ይኽእል።\n\n'
      '6. ምፍልላያት ብፍሉይ ስልጣን ናይ ኦፐሬተር ይፍታሕ።';
}
