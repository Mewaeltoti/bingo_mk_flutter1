-- SQL Script to enable Admin Web access to Supabase tables
-- Run this in the Supabase SQL Editor to grant admin roles the necessary permissions.

-- 0. Schema updates for Admin Web support
ALTER TABLE public.withdrawals ADD COLUMN IF NOT EXISTS payout_ref TEXT;

-- Create payment_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.payment_settings (
    id TEXT PRIMARY KEY DEFAULT 'current',
    accounts JSONB DEFAULT '[]'::jsonb
);

-- Enable RLS on payment_settings
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view payment settings" ON public.payment_settings;
CREATE POLICY "Anyone can view payment settings" ON public.payment_settings 
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can update payment settings" ON public.payment_settings;
CREATE POLICY "Admins can update payment settings" ON public.payment_settings
    FOR ALL
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

-- RPC for manual deposit approval
CREATE OR REPLACE FUNCTION public.approve_deposit_manual(
    p_deposit_id UUID,
    p_user_id UUID,
    p_amount NUMERIC,
    p_reference TEXT
)
RETURNS VOID AS $$
BEGIN
    -- 1. Credit user wallet
    UPDATE public.profiles
    SET balance = balance + p_amount
    WHERE id = p_user_id;

    -- 2. Update deposit status
    UPDATE public.deposits
    SET status = 'approved',
        verified_at = NOW(),
        matched_via = 'admin_manual_approval'
    WHERE id = p_deposit_id;

    -- 3. Update bank notification if reference is provided
    IF p_reference IS NOT NULL AND p_reference != '' THEN
        INSERT INTO public.bank_notifications (reference, amount, bank, sender, text, status, user_id, deposit_id)
        VALUES (p_reference, p_amount, 'MANUAL', 'ADMIN', 'Manually approved by admin', 'matched', p_user_id, p_deposit_id)
        ON CONFLICT (reference) DO UPDATE
        SET status = 'matched',
            user_id = p_user_id,
            deposit_id = p_deposit_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 1. Profiles Table Policies
DROP POLICY IF EXISTS "Admins can update any profile" ON public.profiles;
CREATE POLICY "Admins can update any profile" ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    )
    WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

-- 2. Deposits Table Policies
DROP POLICY IF EXISTS "Admins can view all deposits" ON public.deposits;
CREATE POLICY "Admins can view all deposits" ON public.deposits
    FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

DROP POLICY IF EXISTS "Admins can update deposits" ON public.deposits;
CREATE POLICY "Admins can update deposits" ON public.deposits
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    )
    WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

-- 3. Withdrawals Table Policies
DROP POLICY IF EXISTS "Admins can view all withdrawals" ON public.withdrawals;
CREATE POLICY "Admins can view all withdrawals" ON public.withdrawals
    FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

DROP POLICY IF EXISTS "Admins can update withdrawals" ON public.withdrawals;
CREATE POLICY "Admins can update withdrawals" ON public.withdrawals
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    )
    WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

-- 4. Bank Notifications Table Policies
DROP POLICY IF EXISTS "Admins can view all bank_notifications" ON public.bank_notifications;
CREATE POLICY "Admins can view all bank_notifications" ON public.bank_notifications
    FOR SELECT
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

DROP POLICY IF EXISTS "Admins can update bank_notifications" ON public.bank_notifications;
CREATE POLICY "Admins can update bank_notifications" ON public.bank_notifications
    FOR UPDATE
    TO authenticated
    USING (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    )
    WITH CHECK (
        (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );
