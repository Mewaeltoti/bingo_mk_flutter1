import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error("No authorization header")

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) throw new Error("Unauthorized")

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    const body = await req.json().catch(() => ({}))
    const { cardIds, markedCellsMap = {} } = body

    if (!cardIds || !Array.isArray(cardIds) || cardIds.length === 0) {
      throw new Error("cardIds array is required")
    }

    const cardId = cardIds[0]

    // 1. Fetch live game state
    const { data: game, error: gameError } = await supabaseAdmin
      .from('games')
      .select('*')
      .eq('id', 'live')
      .single()

    if (gameError || !game) throw new Error("Live game session not found.")
    if (game.status !== 'active' && game.status !== 'paused') {
      throw new Error("Game is not active or paused.")
    }

    const now = Date.now()
    if (game.status === 'paused' && game.claim_deadline && now > new Date(game.claim_deadline).getTime()) {
      throw new Error("The claim period has ended.")
    }

    // 2. Fetch card details
    const { data: card, error: cardError } = await supabaseAdmin
      .from('cards')
      .select('*')
      .eq('id', cardId)
      .eq('user_id', user.id)
      .eq('session_id', game.session_id.toString())
      .single()

    if (cardError || !card) throw new Error("Card not found in this session.")

    const pendingClaims = game.pending_claims || []
    if (pendingClaims.some((c: any) => c.cardId === cardId)) {
      throw new Error("Already claimed for this card.")
    }

    const cardNumbers = card.numbers || []
    const drawnNumbers = game.drawn_numbers || []
    const pattern = (game.game_pattern || 'full_house').toLowerCase().replace(/[\s_]/g, '')

    // SERVER-SIDE VALIDATION
    const validationResult = validateBingoWithDetails(cardNumbers, drawnNumbers, pattern)
    const isWinner = validationResult.isWinner

    if (isWinner) {
      // Fetch player phone/profile
      const { data: profile } = await supabaseAdmin
        .from('profiles')
        .select('phone')
        .eq('id', user.id)
        .single()

      const phone = profile?.phone || ''
      const markedCells = markedCellsMap[cardId] || []

      const newClaim = {
        cardId,
        userId: user.id,
        cardNo: card.card_no,
        phone,
        numbers: cardNumbers,
        markedCells,
        timestamp: new Date().toISOString()
      }

      const updatedClaims = [...pendingClaims, newClaim]
      const gameUpdates: any = {
        pending_claims: updatedClaims
      }

      if (game.status !== 'paused') {
        gameUpdates.status = 'paused'
        gameUpdates.is_paused = true
        gameUpdates.claim_deadline = new Date(Date.now() + 20000).toISOString()
        gameUpdates.status_message = "BINGO CLAIMED! 20s for other players to claim..."
      }

      // Update game inside transaction/atomically
      const { error: updateGameError } = await supabaseAdmin
        .from('games')
        .update(gameUpdates)
        .eq('id', 'live')

      if (updateGameError) throw updateGameError

      // Update card status to claiming
      const { error: updateCardError } = await supabaseAdmin
        .from('cards')
        .update({ status: 'claiming' })
        .eq('id', card.id)

      if (updateCardError) throw updateCardError

      return new Response(
        JSON.stringify({ success: true, message: "Bingo claimed! Verification in progress..." }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          message: `Invalid claim. Pattern required: ${game.game_pattern || 'Full House'}.`,
          missing: validationResult.missing
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

function validateBingoWithDetails(cardNumbers: number[], drawnNumbers: number[], pattern: string) {
  const drawn = new Set(drawnNumbers.map(Number))
  const missing: any[] = []

  const isMarked = (row: number, col: number) => {
    if (row === 2 && col === 2) return true // free space
    const index = row * 5 + col
    const num = Number(cardNumbers[index])
    const marked = drawn.has(num)
    if (!marked) {
      missing.push({ row, col, num })
    }
    return marked
  }

  let isWinner = false
  const checkMissing = (checkFn: () => boolean) => {
    missing.length = 0 // Reset missing for each check
    return checkFn()
  }

  switch (pattern) {
    case 'fullhouse':
      isWinner = checkMissing(() => {
        let ok = true
        for (let r = 0; r < 5; r++)
          for (let c = 0; c < 5; c++)
            if (!isMarked(r, c)) ok = false
        return ok
      })
      break;

    case 'singleline':
      // Check H lines
      for (let r = 0; r < 5; r++) {
        if (checkMissing(() => {
          let ok = true
          for (let c = 0; c < 5; c++) if (!isMarked(r, c)) ok = false
          return ok
        })) { isWinner = true; break; }
      }
      if (isWinner) break

      // Check V lines
      for (let c = 0; c < 5; c++) {
        if (checkMissing(() => {
          let ok = true
          for (let r = 0; r < 5; r++) if (!isMarked(r, c)) ok = false
          return ok
        })) { isWinner = true; break; }
      }
      if (isWinner) break

      // Check D lines
      if (checkMissing(() => {
        let ok = true
        for (let i = 0; i < 5; i++) if (!isMarked(i, i)) ok = false
        return ok
      })) { isWinner = true; break; }

      if (checkMissing(() => {
        let ok = true
        for (let i = 0; i < 5; i++) if (!isMarked(i, 4 - i)) ok = false
        return ok
      })) { isWinner = true; break; }
      break;

    case 'twolines': {
      let linesFound = 0
      const allMissing = []
      for (let r = 0; r < 5; r++) {
        if (checkMissing(() => {
          let ok = true
          for (let c = 0; c < 5; c++) if (!isMarked(r, c)) ok = false
          return ok
        })) linesFound++
        else allMissing.push(...missing)
      }
      // V lines
      for (let c = 0; c < 5; c++) {
        if (checkMissing(() => {
          let ok = true
          for (let r = 0; r < 5; r++) if (!isMarked(r, c)) ok = false
          return ok
        })) linesFound++
        else allMissing.push(...missing)
      }
      // D lines
      if (checkMissing(() => {
        let ok = true
        for (let i = 0; i < 5; i++) if (!isMarked(i, i)) ok = false
        return ok
      })) linesFound++
      else allMissing.push(...missing)

      if (checkMissing(() => {
        let ok = true
        for (let i = 0; i < 5; i++) if (!isMarked(i, 4 - i)) ok = false
        return ok
      })) linesFound++
      else allMissing.push(...missing)

      isWinner = linesFound >= 2
      if (!isWinner) missing.push(...allMissing)
      break
    }

    case 'fourcorners':
      isWinner = checkMissing(() => {
        return isMarked(0, 0) && isMarked(0, 4) && isMarked(4, 0) && isMarked(4, 4)
      })
      break

    default:
      isWinner = false
  }

  return { isWinner, missing: isWinner ? [] : missing }
}
