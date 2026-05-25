/**
 * draw-number — Supabase Edge Function
 *
 * Replaces the old draw-loop edge function.
 *
 * OLD APPROACH (REMOVED):
 *   Admin → invoke draw-loop → 55-second while loop → DB
 *   Problem: serverless loops freeze, duplicate instances, cold-starts desync games.
 *
 * NEW APPROACH:
 *   Admin browser → draw-number (per-tick, stateless) → admin_draw_number RPC → DB
 *   → Realtime INSERT on game_draws → Flutter clients receive instantly
 *
 * The admin panel calls this once per draw tick (every ~2–4 s via a browser setInterval).
 * No server-side loop. No heartbeat. No loop_id. No race condition.
 */
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

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

    // Verify the caller is an authenticated admin
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profile?.role !== 'admin') throw new Error('Admin role required')

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    // ── 1. Fetch the minimal game state we need ──────────────────────────
    const { data: game, error: gameError } = await supabaseAdmin
      .from('games')
      .select('status, session_id, draw_sequence, is_paused')
      .eq('id', 'live')
      .single()

    if (gameError || !game) throw new Error('Live game session not found')
    if (game.status !== 'active') {
      return json({ success: false, reason: 'game_not_active', status: game.status })
    }
    if (game.is_paused) {
      return json({ success: false, reason: 'game_paused' })
    }

    const drawSequence: number[] = game.draw_sequence ?? []
    if (!drawSequence.length) throw new Error('No draw sequence on game')

    // ── 2. Count how many numbers have been drawn this session ───────────
    const { count: drawnCount, error: countError } = await supabaseAdmin
      .from('game_draws')
      .select('*', { count: 'exact', head: true })
      .eq('session_id', game.session_id.toString())

    if (countError) throw countError

    const drawn = drawnCount ?? 0

    if (drawn >= drawSequence.length) {
      // All 75 numbers drawn — finish the game
      await supabaseAdmin
        .from('games')
        .update({ status: 'finished', end_time: new Date().toISOString(), status_message: 'All 75 numbers drawn.' })
        .eq('id', 'live')
      return json({ success: true, finished: true })
    }

    // ── 3. Pick the next number from the pre-shuffled sequence ──────────
    const nextNumber = drawSequence[drawn]

    // ── 4. Atomic insert + games row update via RPC ──────────────────────
    const { data: result, error: rpcError } = await supabaseAdmin.rpc('admin_draw_number', {
      p_session_id: game.session_id.toString(),
      p_number:     nextNumber,
    })

    if (rpcError) throw rpcError

    return json({ success: true, number: nextNumber, drawnCount: drawn + 1, total: drawSequence.length })
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
