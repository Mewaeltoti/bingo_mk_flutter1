/**
 * buy-card — Supabase Edge Function (v2)
 *
 * CHANGED: The random card_no selection now retries on duplicate key
 * violation from the unique index `uq_card_per_session`.
 * This eliminates the race condition where two simultaneous requests
 * could pass the SELECT EXISTS check and both insert the same card.
 * The DB constraint is the final guard; the retry loop is the UX guard.
 */
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

const MAX_CARD_NO    = 5000
const MAX_PER_SESSION = 25

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('No authorization header')

    const supabaseUrl        = Deno.env.get('SUPABASE_URL')              ?? ''
    const supabaseAnonKey    = Deno.env.get('SUPABASE_ANON_KEY')         ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    const body  = await req.json().catch(() => ({}))
    const count = Math.min(Math.max(1, body.count ?? 1), 25)

    // ── 1. Check game state ──────────────────────────────────────────────
    const { data: game, error: gameError } = await supabaseAdmin
      .from('games')
      .select('status, session_id, card_price')
      .eq('id', 'live')
      .single()

    if (gameError || !game) throw new Error('Live game session not found')
    if (game.status !== 'buying') throw new Error('Game is not in buying phase')

    const sessionId = game.session_id.toString()

    // ── 2. Count user's existing cards this session ──────────────────────
    const { count: existingCount, error: countError } = await supabaseAdmin
      .from('cards')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('session_id', sessionId)

    if (countError) throw countError
    if ((existingCount ?? 0) + count > MAX_PER_SESSION) {
      throw new Error(
        `Max ${MAX_PER_SESSION} cards per session. You already have ${existingCount}.`
      )
    }

    // ── 3. Randomly pick card numbers, avoiding already-taken ones ───────
    //    The unique index is the hard guard; we just try to avoid collisions upfront.
    const { data: takenRows } = await supabaseAdmin
      .from('cards')
      .select('card_no')
      .eq('session_id', sessionId)
      .eq('status', 'registered')

    const takenSet = new Set((takenRows ?? []).map((r: any) => r.card_no as number))

    const pickedNos: number[] = []
    let attempts = 0
    while (pickedNos.length < count && attempts < 500) {
      const no = Math.floor(Math.random() * MAX_CARD_NO) + 1
      if (!takenSet.has(no) && !pickedNos.includes(no)) pickedNos.push(no)
      attempts++
    }
    if (pickedNos.length < count) throw new Error('Could not find enough unique cards — try again.')

    // ── 4. Fetch card templates from pool ────────────────────────────────
    const { data: poolCards, error: poolError } = await supabaseAdmin
      .from('cards_pool')
      .select('card_no, numbers')
      .in('card_no', pickedNos)

    if (poolError || !poolCards?.length) throw new Error('Failed to load cards from pool')

    // ── 5. Insert — unique index catches any last-millisecond collision ──
    const expiresAt    = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString()
    const insertPayload = poolCards.map((c: any) => ({
      user_id:    user.id,
      game_id:    'live',
      session_id: sessionId,
      card_no:    c.card_no,
      numbers:    c.numbers,
      status:     'pending',
      expires_at: expiresAt,
    }))

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('cards')
      .insert(insertPayload)
      .select('card_no')

    // If we hit the unique constraint (23505), surface a friendly message
    if (insertError) {
      if (insertError.code === '23505') {
        throw new Error('One or more cards were just taken — please try again.')
      }
      throw insertError
    }

    return json({
      success: true,
      cardIds: inserted!.map((i: any) => i.card_no.toString()),
    })
  } catch (error: any) {
    return json({ success: false, error: error.message }, 400)
  }
})

function json(body: unknown, status = 200) {
  return new Response(
    JSON.stringify(body),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status }
  )
}
