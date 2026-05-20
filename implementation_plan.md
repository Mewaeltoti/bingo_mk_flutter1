# Implementation Plan - Migrating Backend to Supabase

This plan outlines the complete architecture and step-by-step implementation roadmap to migrate the **Bingo MK** mobile application and its backend from Firebase (Firestore, Cloud Functions, and Firebase Auth) to **Supabase** (PostgreSQL Database with ACID-safe balance and reconciliation triggers, Deno Edge Functions, and Supabase Auth).

---

## User Review Required

> [!IMPORTANT]
> **Key Architectural Transitions & Enhancements**
> 1. **PostgreSQL Relational Schema & ACID Triggers**: Instead of separate Firebase document collections and asynchronous Firestore Cloud Function triggers (which suffered from lag and race conditions), we will use strong PostgreSQL tables, constraints, and database triggers. Specifically:
>    * **Atomic Registration**: The purchase/registration of card numbers is protected via a database-level transaction function (`register_card`) with row-level locks on user profiles.
>    * **ACID-Compliant Wallet & Reconciliation Triggers**: We will implement PostgreSQL triggers that automatically handle balance reservation for withdrawals, refunding upon rejection, and matching pending deposits against bank notifications (SMS records) atomically.
> 2. **Deno Edge Functions replacing Cloud Functions**: written in TypeScript, running globally at the edge. We will implement `buy-card`, `register-card`, `claim-bingo`, `draw-loop`, and `sms-webhook`.
> 3. **Real-time Live Game Engine**: Instead of listening to Firestore snapshots, the client will subscribe to Supabase Realtime changes on the single live row of the `games` table where `id = 'live'`.
> 4. **Supabase Auth**: Replacing Firebase Auth with a clean repository interface that returns generic user credentials to decouple the UI and state layers.

---

## Open Questions

> [!WARNING]
> **Clarifications & Design Options**
> 1. **2-Second Background Game Loop Execution**:
>    * *Proposed Strategy*: A Deno Edge Function (`draw-loop`) loops internally for 55 seconds when triggered, drawing a number every 2 seconds and updating the `games` table. We will schedule it to run every minute using **pg_cron** (built into Supabase). To avoid a 60-second start lag when the game starts, a Supabase Database Webhook will call this edge function instantly when the status in `games` changes to `active`.
>    * *Please confirm*: Does this cron + webhook strategy align with your requirements?
> 2. **Firebase Cleanup**:
>    * *Proposed Strategy*: We will backup the existing `functions/` directory and Firebase config files into a dedicated folder `firebase_backup/` to keep history safe while ensuring the active project codebase remains clean and simple.

---

## Proposed Changes

### 1. 🗄️ Database Schema, Triggers, & Security (PostgreSQL on Supabase)

We will execute an SQL script in the Supabase SQL Editor to define all tables, triggers, RPCs, and RLS policies.

#### [NEW] [schema.sql](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/supabase/schema.sql)
We will expand the existing `schema.sql` to fully implement the core data models plus the wallet and payment reconciliation system:

* **Profiles**: Users, role, and wallet balance.
* **Games**: The active game session state (`id = 'live'`).
* **Cards**: Purchased and registered cards.
* **Cards Pool**: Seeding table of pre-generated card numbers.
* **Deposits, Withdrawals, & Bank Notifications**: New tables representing the payment system:
  * **`public.deposits`**: `id`, `user_id`, `amount`, `reference`, `status`, `created_at`, `verified_at`, `matched_via`, `rejection_reason`.
  * **`public.withdrawals`**: `id`, `user_id`, `amount`, `status`, `is_reserved`, `created_at`, `reserved_at`, `refunded_at`, `rejection_reason`.
  * **`public.bank_notifications`**: `reference` (PK), `amount`, `bank`, `sender`, `text`, `status`, `user_id`, `deposit_id`, `created_at`.

* **Database Triggers (ACID Wallet & Auto-Reconciliation)**:
  * **`handle_deposit_created`**: Executes when a deposit is created.
    * Rejects the deposit immediately if the reference is already used/approved.
    * Automatically matches the reference against `bank_notifications`. If a matches is found, marks both as `approved` / `matched`, and instantly adds the amount to the user's wallet balance.
    * Auto-rejects if the bank notification is missing or does not match (maintaining system safety).
  * **`handle_withdrawal_created`**: Runs before inserting a withdrawal. Checks user balance, locks the profile row, and automatically deducts the withdrawal amount from their balance while marking the funds as reserved.
  * **`handle_withdrawal_updated`**: Runs when a withdrawal status changes. If it is changed to `rejected`, it refunds the reserved amount back to the player's profile balance.

---

### 2. ⚡ Deno TypeScript Edge Functions

We will write edge functions inside the `supabase/functions/` directory.

#### [NEW] `supabase/functions/claim-bingo/index.ts`
* Replaces the `claimBingo` Firebase Callable.
* Validates user card numbers locally against the active `drawn_numbers` list loaded from `games`.
* If winner, pauses the game, sets a 20-second grace deadline for other players, and marks card as `claiming`.

#### [NEW] `supabase/functions/draw-loop/index.ts`
* Replaces the scheduled `drawNumberLoopHandler` and `onGameUpdatedHandler` loop.
* Runs a loop that checks the `heartbeat` lock, draws a number from `draw_sequence` every 2 seconds, and updates `current_number`, `drawn_numbers`, and `heartbeat` directly inside Postgres.
* Handles auto-resetting after won/finished games, auto-starting after buying timeout, and auto-finalizing claims when the deadline passes.

#### [NEW] `supabase/functions/sms-webhook/index.ts`
* Replaces Firebase HTTP function `smsWebhook`.
* Receives API-token authenticated forwarded banking SMS text, parses CBE/Telebirr credit transactions, and upserts rows into the `bank_notifications` table.

---

### 3. 📱 Client-Side Re-architecture (Flutter)

We will rewrite our repository implementations to fully use Supabase.

#### [MODIFY] [pubspec.yaml](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/pubspec.yaml)
* Add `supabase_flutter: ^2.8.0` package.
* Remove obsolete packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_database`, `cloud_functions`, `google_sign_in`.

#### [MODIFY] [lib/main.dart](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/lib/main.dart)
* Replace Firebase initialization with Supabase initialization:
  ```dart
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  ```

#### [NEW] [lib/data/repositories/auth_repository_supabase.dart](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/lib/data/repositories/auth_repository_supabase.dart)
* Implement `AuthRepository` by wrapping `Supabase.instance.client.auth`:
  * Returns generic models (`String?` userId) rather than leaking Firebase `User` objects to make the implementation decoupled and clean.
  * `signInWithEmail` maps to `client.auth.signInWithPassword`.
  * `signUpWithEmail` maps to `client.auth.signUp`.
  * `signOut` maps to `client.auth.signOut`.
  * `userIdStream` maps to `client.auth.onAuthStateChange` mapping to a string.

#### [NEW] [lib/data/repositories/bingo_repository_supabase.dart](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/lib/data/repositories/bingo_repository_supabase.dart)
* Implement `BingoRepository` wrapping the Supabase Client:
  * `streamGame(gameId)` -> `client.from('games').stream(primaryKey: ['id']).eq('id', 'live').map(...)`
  * `streamDrawnNumbers(gameId)` -> Real-time streams map.
  * `buyCartelas(...)` -> Call Supabase Edge Function `buy-card`.
  * `claimBingo(...)` -> Call Supabase Edge Function `claim-bingo`.
  * `getDeposits`, `getWithdrawals`, `createDeposit`, `createWithdrawal` -> Direct PostgreSQL CRUD via `client.from(...)`.
  * `streamBalance` -> Subscription using real-time channels or select streams.

#### [MODIFY] [lib/core/services/service_locator.dart](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/lib/core/services/service_locator.dart)
* Update registrations to use `AuthRepositorySupabase` and `BingoRepositorySupabase`.

#### [MODIFY] [lib/presentation/blocs/auth_cubit.dart](file:///C:/Users/3040/Downloads/Me/bingo_mk_flutter/lib/presentation/blocs/auth_cubit.dart)
* Update references to use clean `String?` user stream instead of `User?` Firebase stream.

---

## Verification Plan

### Automated Tests & Compilation
* Run `flutter pub get` and verify compilation using `flutter analyze` to ensure there are no compilation errors in repositories or Blocs.
* Serve and validate Edge Functions locally using Supabase CLI (`supabase start`, `supabase functions serve`).

### Manual Verification
* Register a new user in the app using Supabase Auth.
* Buy cards, see balance deduct in real-time, start a session, and verify that numbers are drawn smoothly every 2 seconds via Supabase Realtime streams!
