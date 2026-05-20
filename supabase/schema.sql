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
        new.phone,
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

