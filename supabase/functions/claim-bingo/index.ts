/**
 * claim-bingo — Supabase Edge Function (v2)
 *
 * CHANGED: Claims are now written to the normalized `claims` table
 * instead of the `pending_claims` JSONB[] array on the games row.
 * Uses the admin_insert_claim RPC for atomicity.
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

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error('Unauthorized')

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    const body = await req.json().catch(() => ({}))
    const { cardIds, markedCellsMap = {} } = body

    if (!cardIds || !Array.isArray(cardIds) || cardIds.length === 0) {
      throw new Error('cardIds array is required')
    }

    const cardId = cardIds[0]

    // ── 1. Fetch slim game state ─────────────────────────────────────────
    const { data: game, error: gameError } = await supabaseAdmin
      .from('games')
      .select('status, session_id, is_paused, claim_deadline, drawn_numbers, game_pattern')
      .eq('id', 'live')
      .single()

    if (gameError || !game) throw new Error('Live game session not found')
    if (game.status !== 'active' && game.status !== 'paused') {
      throw new Error('Game is not active or paused')
    }

    if (game.status === 'paused' && game.claim_deadline) {
      if (Date.now() > new Date(game.claim_deadline).getTime()) {
        throw new Error('The claim period has ended')
      }
    }

    // ── 2. Fetch the card ────────────────────────────────────────────────
    const { data: card, error: cardError } = await supabaseAdmin
      .from('cards')
      .select('id, card_no, numbers, session_id')
      .eq('id', cardId)
      .eq('user_id', user.id)
      .eq('session_id', game.session_id.toString())
      .single()

    if (cardError || !card) throw new Error('Card not found in this session')

    // ── 3. Server-side validation ────────────────────────────────────────
    const drawnNumbers: number[] = game.drawn_numbers ?? []
    const pattern = (game.game_pattern ?? 'full_house').toLowerCase().replace(/[\s_]/g, '')
    const validationResult = validateBingo(card.numbers, drawnNumbers, pattern)

    if (!validationResult.isWinner) {
      return json({
        success: false,
        message: `Invalid claim. Pattern required: ${game.game_pattern ?? 'Full House'}.`,
        missing: validationResult.missing,
      })
    }

    // ── 4. Fetch phone ───────────────────────────────────────────────────
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('phone')
      .eq('id', user.id)
      .single()

    const phone       = profile?.phone ?? ''
    const markedCells = (markedCellsMap[cardId] ?? []) as string[]

    // ── 5. Insert claim + pause game atomically via RPC ──────────────────
    const { data: rpcResult, error: rpcError } = await supabaseAdmin.rpc('admin_insert_claim', {
      p_session_id:   game.session_id.toString(),
      p_user_id:      user.id,
      p_card_no:      card.card_no,
      p_card_id:      card.id,
      p_phone:        phone,
      p_numbers:      card.numbers,
      p_marked_cells: markedCells,
    })

    if (rpcError) throw rpcError

    if (rpcResult?.reason === 'already_claimed') {
      throw new Error('Already claimed for this card')
    }

    return json({ success: true, message: 'Bingo claimed! Verification in progress...' })
  } catch (error: any) {
    return json({ success: false, error: error.message }, 400)
  }
})

// ── Validation (unchanged logic) ────────────────────────────────────────────
function validateBingo(cardNumbers: number[], drawnNumbers: number[], pattern: string) {
  const drawn = new Set(drawnNumbers.map(Number))
  const missing: any[] = []

  const isMarked = (row: number, col: number) => {
    if (row === 2 && col === 2) return true
    const num = Number(cardNumbers[row * 5 + col])
    const ok  = drawn.has(num)
    if (!ok) missing.push({ row, col, num })
    return ok
  }

  const check = (fn: () => boolean) => { missing.length = 0; return fn() }

  let isWinner = false

  switch (pattern) {
    case 'fullhouse':
      isWinner = check(() => {
        let ok = true
        for (let r = 0; r < 5; r++)
          for (let c = 0; c < 5; c++)
            if (!isMarked(r, c)) ok = false
        return ok
      })
      break

    case 'singleline':
      for (let r = 0; r < 5 && !isWinner; r++) {
        if (check(() => { let ok = true; for (let c = 0; c < 5; c++) if (!isMarked(r, c)) ok = false; return ok })) isWinner = true
      }
      for (let c = 0; c < 5 && !isWinner; c++) {
        if (check(() => { let ok = true; for (let r = 0; r < 5; r++) if (!isMarked(r, c)) ok = false; return ok })) isWinner = true
      }
      if (!isWinner && check(() => { let ok = true; for (let i = 0; i < 5; i++) if (!isMarked(i, i)) ok = false; return ok })) isWinner = true
      if (!isWinner && check(() => { let ok = true; for (let i = 0; i < 5; i++) if (!isMarked(i, 4 - i)) ok = false; return ok })) isWinner = true
      break

    case 'fourcorners':
      isWinner = check(() => isMarked(0,0) && isMarked(0,4) && isMarked(4,0) && isMarked(4,4))
      break

    default:
      isWinner = false
  }

  return { isWinner, missing: isWinner ? [] : missing }
}

function json(body: unknown, status = 200) {
  return new Response(
    JSON.stringify(body),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status }
  )
}
