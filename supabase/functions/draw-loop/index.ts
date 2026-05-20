import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    const loopId = Math.random().toString(36).substring(2, 10)
    console.log(`Starting Deno draw loop with ID: ${loopId}`)

    const endTime = Date.now() + 55000
    
    while (Date.now() < endTime) {
      // 1. Fetch live game state
      const { data: game, error: gameError } = await supabaseAdmin
        .from('games')
        .select('*')
        .eq('id', 'live')
        .single()

      if (gameError || !game) {
        console.error("Live game session not found.")
        break
      }

      // Case A: Game has ended and needs reset after 15 seconds
      if (game.status === 'won' || game.status === 'finished') {
        if (game.end_time) {
          const end = new Date(game.end_time).getTime()
          if (Date.now() - end >= 15 * 1000) {
            console.log("Resetting game for a new session...")
            const nextSession = (game.session_id || 1000) + 1

            // Pre-shuffled sequence of 75 numbers
            const drawSequence = Array.from({ length: 75 }, (_, i) => i + 1)
            for (let i = drawSequence.length - 1; i > 0; i--) {
              const j = Math.floor(Math.random() * (i + 1));
              [drawSequence[i], drawSequence[j]] = [drawSequence[j], drawSequence[i]]
            }

            // Perform atomic reset in Postgres
            await supabaseAdmin.rpc('reset_game_session', {
              p_next_session: nextSession,
              p_draw_sequence: drawSequence
            })
          }
        }
        await new Promise(resolve => setTimeout(resolve, 5000))
        continue
      }

      // Case B: Game in buying phase - auto start after 120 seconds
      if (game.status === 'buying') {
        const startTime = game.start_time ? new Date(game.start_time).getTime() : Date.now()
        if (Date.now() - startTime >= 120 * 1000) {
          console.log(`Game starting automatically for session ${game.session_id}`)
          await supabaseAdmin
            .from('games')
            .update({
              status: 'active',
              status_message: "Game started! Drawing numbers..."
            })
            .eq('id', 'live')
        } else {
          console.log("Game is in buying phase. Waiting for players...")
        }
        await new Promise(resolve => setTimeout(resolve, 5000))
        continue
      }

      // Case C: Game paused and claim deadline is over - auto-finalize
      if (game.status === 'paused' && game.claim_deadline) {
        const deadline = new Date(game.claim_deadline).getTime()
        if (Date.now() > deadline) {
          console.log("Grace period over. Auto-finalizing claim...")

          const pending = game.pending_claims || []
          const confirmed = game.confirmed_winners || []
          const allWinners = [...confirmed, ...pending]

          if (allWinners.length > 0) {
            // Atomic payout RPC function in PostgreSQL
            const { error: payoutError } = await supabaseAdmin.rpc('payout_winners', {
              p_winners: allWinners,
              p_drawn_numbers: game.drawn_numbers,
              p_cards_sold: game.cards_sold,
              p_prize_pool: game.prize_pool,
              p_session_id: game.session_id
            })

            if (payoutError) console.error("Error paying out winners:", payoutError.message)
          } else {
            // Resume if no claims
            await supabaseAdmin
              .from('games')
              .update({
                status: 'active',
                is_paused: false,
                claim_deadline: null,
                status_message: "No valid claims. Resuming game..."
              })
              .eq('id', 'live')
          }
        } else {
          console.log("Game paused. Waiting for grace period to end...")
        }
        await new Promise(resolve => setTimeout(resolve, 2000))
        continue
      }

      const pendingClaims = game.pending_claims || []
      if (game.status !== 'active' || pendingClaims.length > 0) {
        await new Promise(resolve => setTimeout(resolve, 2000))
        continue
      }

      // Case D: Active game - drawing loop
      const activeHeartbeat = game.heartbeat ? new Date(game.heartbeat).getTime() : 0
      const activeLoopId = game.loop_id || ''

      if (activeHeartbeat && (Date.now() - activeHeartbeat < 3500) && activeLoopId !== loopId) {
        console.log(`[Lock] Another active drawing loop (${activeLoopId}) is running. Exiting loop ${loopId}.`)
        break
      }

      const drawnNumbers = game.drawn_numbers || []
      const drawSequence = game.draw_sequence || []

      if (drawnNumbers.length >= 75) {
        console.log("No more numbers available. Finishing game.")
        await supabaseAdmin
          .from('games')
          .update({
            status: 'finished',
            end_time: new Date().toISOString()
          })
          .eq('id', 'live')
      } else {
        const nextIndex = drawnNumbers.length
        const newNumber = drawSequence[nextIndex]
        drawnNumbers.push(newNumber)

        console.log(`Drawing number: ${newNumber}. Total drawn: ${drawnNumbers.length}`)

        const updates: any = {
          current_number: newNumber,
          drawn_numbers: drawnNumbers,
          last_draw_time: new Date().toISOString(),
          heartbeat: new Date().toISOString(),
          loop_id: loopId
        }

        if (game.status_message === "Waiting for players...") {
          updates.status_message = "Numbers are being drawn..."
        }

        await supabaseAdmin
          .from('games')
          .update(updates)
          .eq('id', 'live')
      }

      await new Promise(resolve => setTimeout(resolve, 2000))
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
