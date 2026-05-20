-- Supabase PostgreSQL Schema Definition for Bingo MK

-- Disable RLS on public schema initially (just in case)
SET search_path = public;

-- --- TABLES SETUP ---

-- 1. Create Profiles table linked to Supabase Auth users
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    phone TEXT,
    role TEXT DEFAULT 'player',
    balance NUMERIC DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create Games table for active session state
CREATE TABLE IF NOT EXISTS public.games (
    id TEXT PRIMARY KEY DEFAULT 'live',
    status TEXT DEFAULT 'waiting',
    session_id INT DEFAULT 1000,
    drawn_numbers INT[] DEFAULT '{}',
    draw_sequence INT[] DEFAULT '{}',
    is_paused BOOLEAN DEFAULT FALSE,
    prize_pool NUMERIC DEFAULT 250.0,
    card_price NUMERIC DEFAULT 10.0,
    game_pattern TEXT DEFAULT 'full_house',
    current_number INT,
    last_draw_time TIMESTAMPTZ,
    heartbeat TIMESTAMPTZ,
    loop_id TEXT,
    winners TEXT[] DEFAULT '{}',
    winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    winning_card_no INT,
    winning_card_numbers INT[],
    status_message TEXT DEFAULT 'Waiting for players...',
    cards_sold INT DEFAULT 0,
    players_count INT DEFAULT 0,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    claim_deadline TIMESTAMPTZ,
    pending_claims JSONB[] DEFAULT '{}',
    confirmed_winners JSONB[] DEFAULT '{}'
);

-- 3. Create Cards table for user session card purchases
CREATE TABLE IF NOT EXISTS public.cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    game_id TEXT DEFAULT 'live',
    session_id TEXT NOT NULL,
    card_no INT NOT NULL,
    numbers INT[] NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ
);

-- 4. Create Pre-seeded Card Pool table
CREATE TABLE IF NOT EXISTS public.cards_pool (
    card_no INT PRIMARY KEY,
    numbers INT[] NOT NULL
);

-- 5. Create Game Winners table
CREATE TABLE IF NOT EXISTS public.game_winners (
    card_no TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    phone TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Create Game History table
CREATE TABLE IF NOT EXISTS public.game_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id TEXT NOT NULL,
    status TEXT NOT NULL,
    prize NUMERIC DEFAULT 0.0,
    drawn_numbers INT[] NOT NULL,
    cards_sold INT DEFAULT 0,
    winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    winner_name TEXT,
    winning_card_no INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Initialize default 'live' game session row if not exists
INSERT INTO public.games (id, status, session_id)
VALUES ('live', 'waiting', 1000)
ON CONFLICT (id) DO NOTHING;

-- --- PROFILE SYNC TRIGGER ---

-- Automatically create profile row when a new user signs up in Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, phone, role, balance)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.phone, new.raw_user_meta_data->>'phone'),
        'player',
        0.0
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Bind trigger to auth.users table
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- --- ROW LEVEL SECURITY (RLS) POLICIES ---

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cards_pool ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_winners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_history ENABLE ROW LEVEL SECURITY;

-- 1. Profiles Policies
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 2. Games Policies
DROP POLICY IF EXISTS "Games are viewable by everyone" ON public.games;
CREATE POLICY "Games are viewable by everyone" ON public.games FOR SELECT USING (true);

-- 3. Cards Policies
DROP POLICY IF EXISTS "Users can view their own cards" ON public.cards;
CREATE POLICY "Users can view their own cards" ON public.cards FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own cards" ON public.cards;
CREATE POLICY "Users can create their own cards" ON public.cards FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own cards" ON public.cards;
CREATE POLICY "Users can delete their own cards" ON public.cards FOR DELETE USING (auth.uid() = user_id);

-- 4. Cards Pool Policies
DROP POLICY IF EXISTS "Pool viewable by authenticated users" ON public.cards_pool;
CREATE POLICY "Pool viewable by authenticated users" ON public.cards_pool FOR SELECT USING (auth.role() = 'authenticated');

-- 5. Game Winners and History Policies
DROP POLICY IF EXISTS "Winners viewable by everyone" ON public.game_winners;
CREATE POLICY "Winners viewable by everyone" ON public.game_winners FOR SELECT USING (true);

DROP POLICY IF EXISTS "History viewable by everyone" ON public.game_history;
CREATE POLICY "History viewable by everyone" ON public.game_history FOR SELECT USING (true);

-- --- ATOMIC TRANSACTION RPC FUNCTIONS ---

-- Atomic card registration with balance deduction and duplicate verification
CREATE OR REPLACE FUNCTION public.register_card(
    p_user_id UUID,
    p_card_no INT,
    p_price NUMERIC
)
RETURNS JSONB AS $$
DECLARE
    v_balance NUMERIC;
    v_status TEXT;
    v_session_id INT;
    v_exists_another BOOLEAN;
    v_card_exists BOOLEAN;
    v_numbers INT[];
BEGIN
    -- 1. Check live game state
    SELECT status, session_id INTO v_status, v_session_id
    FROM public.games
    WHERE id = 'live';

    IF v_status IS NULL OR v_status != 'buying' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Game is not in buying phase.');
    END IF;

    -- 2. Check if this card already exists in registered state for ANOTHER player in this session
    SELECT EXISTS (
        SELECT 1 FROM public.cards
        WHERE card_no = p_card_no
          AND session_id = v_session_id::text
          AND status = 'registered'
          AND user_id != p_user_id
    ) INTO v_exists_another;

    IF v_exists_another THEN
        RETURN jsonb_build_object('success', false, 'error', 'This card number has already been purchased by another player!');
    END IF;

    -- 3. Check if player already registered this card
    SELECT EXISTS (
        SELECT 1 FROM public.cards
        WHERE card_no = p_card_no
          AND user_id = p_user_id
          AND session_id = v_session_id::text
          AND status = 'registered'
    ) INTO v_card_exists;

    IF v_card_exists THEN
        RETURN jsonb_build_object('success', true, 'message', 'Card already registered.');
    END IF;

    -- 4. Get numbers from card pool
    SELECT numbers INTO v_numbers
    FROM public.cards_pool
    WHERE card_no = p_card_no;

    IF v_numbers IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid card number. Not found in pool.');
    END IF;

    -- 5. Check user balance and lock the profile row to prevent concurrent race conditions
    SELECT balance INTO v_balance
    FROM public.profiles
    WHERE id = p_user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Player profile not found.');
    END IF;

    IF v_balance < p_price THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance.');
    END IF;

    -- 6. Deduct balance
    UPDATE public.profiles
    SET balance = balance - p_price
    WHERE id = p_user_id;

    -- 7. Check if a pending row exists to update, else insert
    SELECT EXISTS (
        SELECT 1 FROM public.cards
        WHERE card_no = p_card_no
          AND user_id = p_user_id
          AND session_id = v_session_id::text
    ) INTO v_card_exists;

    IF v_card_exists THEN
        UPDATE public.cards
        SET status = 'registered',
            numbers = v_numbers
        WHERE card_no = p_card_no
          AND user_id = p_user_id
          AND session_id = v_session_id::text;
    ELSE
        INSERT INTO public.cards (user_id, game_id, session_id, card_no, numbers, status)
        VALUES (p_user_id, 'live', v_session_id::text, p_card_no, v_numbers, 'registered');
    END IF;

    -- 8. Increment cards sold
    UPDATE public.games
    SET cards_sold = cards_sold + 1
    WHERE id = 'live';

    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- --- DEPOSITS, WITHDRAWALS & BANK NOTIFICATIONS TABLES ---

-- 8. Create Deposits table
CREATE TABLE IF NOT EXISTS public.deposits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    reference TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    matched_via TEXT,
    rejection_reason TEXT
);

-- 9. Create Withdrawals table
CREATE TABLE IF NOT EXISTS public.withdrawals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    status TEXT DEFAULT 'pending',
    is_reserved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reserved_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    rejection_reason TEXT
);

-- 10. Create Bank Notifications table (SMS records parsed from webhook)
CREATE TABLE IF NOT EXISTS public.bank_notifications (
    reference TEXT PRIMARY KEY,
    amount NUMERIC NOT NULL,
    bank TEXT NOT NULL,
    sender TEXT NOT NULL,
    text TEXT NOT NULL,
    status TEXT DEFAULT 'unmatched',
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    deposit_id UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --- ROW LEVEL SECURITY FOR DEPOSITS & WITHDRAWALS ---
ALTER TABLE public.deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bank_notifications ENABLE ROW LEVEL SECURITY;

-- Deposits policies: User can view and insert their own deposits
DROP POLICY IF EXISTS "Users can view their own deposits" ON public.deposits;
CREATE POLICY "Users can view their own deposits" ON public.deposits FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own deposits" ON public.deposits;
CREATE POLICY "Users can create their own deposits" ON public.deposits FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Withdrawals policies: User can view and insert their own withdrawals
DROP POLICY IF EXISTS "Users can view their own withdrawals" ON public.withdrawals;
CREATE POLICY "Users can view their own withdrawals" ON public.withdrawals FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create their own withdrawals" ON public.withdrawals;
CREATE POLICY "Users can create their own withdrawals" ON public.withdrawals FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Bank Notifications policies: Only service_role can access (by leaving policies empty with RLS enabled)

-- --- PAYMENT AND BALANCE RECONCILIATION TRIGGERS ---

-- Trigger 1: Auto-reconciliation of deposits with CBE/Telebirr notifications
CREATE OR REPLACE FUNCTION public.process_deposit()
RETURNS TRIGGER AS $$
DECLARE
    v_approved_exists BOOLEAN;
    v_bank_amount NUMERIC;
    v_bank_status TEXT;
BEGIN
    -- 1. Check for duplicate references in approved deposits
    SELECT EXISTS (
        SELECT 1 FROM public.deposits
        WHERE reference = NEW.reference
          AND status = 'approved'
          AND id != NEW.id
    ) INTO v_approved_exists;

    IF v_approved_exists THEN
        NEW.status := 'rejected';
        NEW.rejection_reason := 'This reference number has already been used for a successful deposit.';
        RETURN NEW;
    END IF;

    -- 2. Fetch matched bank record
    SELECT amount, status INTO v_bank_amount, v_bank_status
    FROM public.bank_notifications
    WHERE reference = NEW.reference;

    IF FOUND THEN
        IF v_bank_status = 'matched' THEN
            NEW.status := 'rejected';
            NEW.rejection_reason := 'This transaction reference has already been processed.';
            RETURN NEW;
        END IF;

        IF v_bank_status = 'unmatched' THEN
            IF v_bank_amount = NEW.amount THEN
                -- Reconcile instantly!
                NEW.status := 'approved';
                NEW.verified_at := NOW();
                NEW.matched_via := 'on_create_trigger';

                -- Update bank notification
                UPDATE public.bank_notifications
                SET status = 'matched',
                    user_id = NEW.user_id,
                    deposit_id = NEW.id
                WHERE reference = NEW.reference;

                -- Credit user wallet
                UPDATE public.profiles
                SET balance = balance + NEW.amount
                WHERE id = NEW.user_id;
            ELSE
                -- Amount mismatch
                UPDATE public.bank_notifications
                SET status = 'amount_mismatch'
                WHERE reference = NEW.reference;

                NEW.status := 'rejected';
                NEW.rejection_reason := 'Amount mismatch. Bank records show a different amount.';
            END IF;
        END IF;
    ELSE
        -- Bank record not found, automatically reject per requirements
        NEW.status := 'rejected';
        NEW.rejection_reason := 'Invalid reference number. Transaction not found in bank records.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_deposit_created ON public.deposits;
CREATE TRIGGER on_deposit_created
    BEFORE INSERT ON public.deposits
    FOR EACH ROW EXECUTE FUNCTION public.process_deposit();


-- Trigger 2: Withdrawal balance reservation
CREATE OR REPLACE FUNCTION public.process_withdrawal_creation()
RETURNS TRIGGER AS $$
DECLARE
    v_balance NUMERIC;
BEGIN
    IF NEW.amount IS NULL OR NEW.amount <= 0 THEN
        NEW.status := 'rejected';
        NEW.is_reserved := FALSE;
        NEW.rejection_reason := 'Invalid withdrawal amount requested.';
        RETURN NEW;
    END IF;

    -- Lock user profile row to prevent balance race condition
    SELECT balance INTO v_balance
    FROM public.profiles
    WHERE id = NEW.user_id
    FOR UPDATE;

    IF v_balance IS NULL THEN
        NEW.status := 'rejected';
        NEW.is_reserved := FALSE;
        NEW.rejection_reason := 'User profile not found.';
        RETURN NEW;
    END IF;

    IF v_balance < NEW.amount THEN
        NEW.status := 'rejected';
        NEW.is_reserved := FALSE;
        NEW.rejection_reason := 'Insufficient balance in your wallet.';
    ELSE
        -- Reserve balance
        UPDATE public.profiles
        SET balance = balance - NEW.amount
        WHERE id = NEW.user_id;

        NEW.status := 'pending';
        NEW.is_reserved := TRUE;
        NEW.reserved_at := NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_withdrawal_created ON public.withdrawals;
CREATE TRIGGER on_withdrawal_created
    BEFORE INSERT ON public.withdrawals
    FOR EACH ROW EXECUTE FUNCTION public.process_withdrawal_creation();


-- Trigger 3: Withdrawal refunding upon rejection
CREATE OR REPLACE FUNCTION public.process_withdrawal_update()
RETURNS TRIGGER AS $$
BEGIN
    -- If status transitioned to rejected and we had actually reserved the funds, refund
    IF OLD.status = 'pending' AND NEW.status = 'rejected' AND OLD.is_reserved = TRUE THEN
        -- Refund user balance
        UPDATE public.profiles
        SET balance = balance + OLD.amount
        WHERE id = OLD.user_id;

        NEW.is_reserved := FALSE;
        NEW.refunded_at := NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_withdrawal_updated ON public.withdrawals;
CREATE TRIGGER on_withdrawal_updated
    BEFORE UPDATE ON public.withdrawals
    FOR EACH ROW EXECUTE FUNCTION public.process_withdrawal_update();


-- --- GAME ENGINE ENGINE RPC FUNCTIONS ---

-- Atomic reset of the game session
CREATE OR REPLACE FUNCTION public.reset_game_session(
    p_next_session INT,
    p_draw_sequence INT[]
)
RETURNS VOID AS $$
BEGIN
    -- 1. Reset game state
    UPDATE public.games
    SET status = 'buying',
        session_id = p_next_session,
        drawn_numbers = '{}',
        draw_sequence = p_draw_sequence,
        is_paused = FALSE,
        winners = '{}',
        winner_id = NULL,
        winning_card_no = NULL,
        winning_card_numbers = NULL,
        status_message = 'Waiting for players...',
        cards_sold = 0,
        players_count = 0,
        start_time = NOW(),
        end_time = NULL,
        claim_deadline = NULL,
        pending_claims = '{}',
        confirmed_winners = '{}',
        current_number = NULL,
        last_draw_time = NULL,
        heartbeat = NULL,
        loop_id = NULL
    WHERE id = 'live';

    -- 2. Clear cards
    DELETE FROM public.cards;

    -- 3. Clear game winners
    DELETE FROM public.game_winners;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Atomic payout of winners and recording results
CREATE OR REPLACE FUNCTION public.payout_winners(
    p_winners JSONB[],
    p_drawn_numbers INT[],
    p_cards_sold INT,
    p_prize_pool NUMERIC,
    p_session_id INT
)
RETURNS VOID AS $$
DECLARE
    v_winner_count INT;
    v_prize_per_winner NUMERIC;
    v_winner JSONB;
    v_winner_user_id UUID;
    v_winner_card_no INT;
    v_winner_phone TEXT;
    v_primary_winner_id UUID := NULL;
    v_primary_winner_phone TEXT := NULL;
    v_primary_winning_card_no INT := NULL;
    v_winners_text TEXT[] := '{}';
BEGIN
    v_winner_count := array_length(p_winners, 1);
    IF v_winner_count IS NULL OR v_winner_count = 0 THEN
        RETURN;
    END IF;

    v_prize_per_winner := p_prize_pool / v_winner_count;

    -- Loop through winners to pay out and record winners
    FOR i IN 1..v_winner_count LOOP
        v_winner := p_winners[i];
        v_winner_user_id := (v_winner->>'userId')::UUID;
        v_winner_card_no := (v_winner->>'cardNo')::INT;
        v_winner_phone := v_winner->>'phone';
        v_winners_text := array_append(v_winners_text, v_winner_card_no::TEXT);

        IF i = 1 THEN
            v_primary_winner_id := v_winner_user_id;
            v_primary_winner_phone := v_winner_phone;
            v_primary_winning_card_no := v_winner_card_no;
        END IF;

        -- 1. Credit balance
        UPDATE public.profiles
        SET balance = balance + v_prize_per_winner
        WHERE id = v_winner_user_id;

        -- 2. Insert into game_winners
        INSERT INTO public.game_winners (card_no, session_id, user_id, phone, created_at)
        VALUES (v_winner_card_no::TEXT, p_session_id::TEXT, v_winner_user_id, v_winner_phone, NOW())
        ON CONFLICT (card_no) DO UPDATE
        SET session_id = EXCLUDED.session_id,
            user_id = EXCLUDED.user_id,
            phone = EXCLUDED.phone,
            created_at = NOW();
    END LOOP;

    -- 3. Insert into game history
    INSERT INTO public.game_history (session_id, status, prize, drawn_numbers, cards_sold, winner_id, winner_name, winning_card_no, created_at)
    VALUES (p_session_id::TEXT, 'won', p_prize_pool, p_drawn_numbers, p_cards_sold, v_primary_winner_id, v_primary_winner_phone, v_primary_winning_card_no, NOW());

    -- 4. Update game state
    UPDATE public.games
    SET status = 'won',
        winners = v_winners_text,
        winner_id = v_primary_winner_id,
        winning_card_no = v_primary_winning_card_no,
        end_time = NOW(),
        pending_claims = '{}',
        confirmed_winners = p_winners,
        claim_deadline = NULL,
        status_message = 'Game Over! Winners have been paid.'
    WHERE id = 'live';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- Atomic process bank notification from webhook
CREATE OR REPLACE FUNCTION public.process_bank_notification(
    p_amount NUMERIC,
    p_reference TEXT,
    p_bank TEXT,
    p_sender TEXT,
    p_text TEXT
)
RETURNS TEXT AS $$
DECLARE
    v_notification_status TEXT;
    v_deposit RECORD;
BEGIN
    -- 1. Check if reference already exists
    SELECT status INTO v_notification_status
    FROM public.bank_notifications
    WHERE reference = p_reference;

    IF FOUND THEN
        IF v_notification_status = 'matched' THEN
            RETURN 'already_matched';
        END IF;
        RETURN 'duplicate_unmatched';
    END IF;

    -- 2. Check if a pending deposit exists for this reference
    SELECT id, user_id, amount INTO v_deposit
    FROM public.deposits
    WHERE reference = p_reference
      AND status = 'pending'
    LIMIT 1;

    IF FOUND THEN
        -- Verify amount matches
        IF v_deposit.amount = p_amount THEN
            -- Insert as matched bank notification
            INSERT INTO public.bank_notifications (reference, amount, bank, sender, text, status, user_id, deposit_id)
            VALUES (p_reference, p_amount, p_bank, p_sender, p_text, 'matched', v_deposit.user_id, v_deposit.id);

            -- Approve deposit
            UPDATE public.deposits
            SET status = 'approved',
                verified_at = NOW(),
                matched_via = 'sms_webhook'
            WHERE id = v_deposit.id;

            -- Credit wallet
            UPDATE public.profiles
            SET balance = balance + p_amount
            WHERE id = v_deposit.user_id;

            RETURN 'matched_instantly';
        ELSE
            -- Save as amount_mismatch
            INSERT INTO public.bank_notifications (reference, amount, bank, sender, text, status)
            VALUES (p_reference, p_amount, p_bank, p_sender, p_text, 'amount_mismatch');

            RETURN 'amount_mismatch';
        END IF;
    ELSE
        -- Save as unmatched bank notification
        INSERT INTO public.bank_notifications (reference, amount, bank, sender, text, status)
        VALUES (p_reference, p_amount, p_bank, p_sender, p_text, 'saved_unmatched');

        RETURN 'saved_unmatched';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;




