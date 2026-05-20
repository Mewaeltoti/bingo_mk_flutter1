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
    const count = body.count ?? 1
    const requestedCount = Math.min(Math.max(1, count), 25)

    const { data: game, error: gameError } = await supabaseAdmin
      .from('games')
      .select('status, session_id')
      .eq('id', 'live')
      .single()

    if (gameError || !game) throw new Error("Live game session not found.")
    if (game.status !== 'buying') throw new Error("Game is not in buying phase.")

    const sessionId = game.session_id.toString()

    const { count: existingCount, error: countError } = await supabaseAdmin
      .from('cards')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('session_id', sessionId)

    if (countError) throw countError
    if ((existingCount ?? 0) + requestedCount > 25) {
      throw new Error(`You can only own a maximum of 25 cards per session. You already have ${existingCount} cards.`)
    }

    const selectedCards = []
    for (let i = 0; i < requestedCount; i++) {
      const randomCardNo = Math.floor(Math.random() * 5000) + 1
      selectedCards.push(randomCardNo)
    }

    const { data: poolCards, error: poolError } = await supabaseAdmin
      .from('cards_pool')
      .select('card_no, numbers')
      .in('card_no', selectedCards)

    if (poolError || !poolCards || poolCards.length === 0) {
      throw new Error("Failed to load cards from pool.")
    }

    const expiresAt = new Date(Date.now() + 2 * 60 * 60 * 1000).toISOString()
    const insertPayload = poolCards.map(c => ({
      user_id: user.id,
      game_id: 'live',
      session_id: sessionId,
      card_no: c.card_no,
      numbers: c.numbers,
      status: 'pending',
      expires_at: expiresAt
    }))

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from('cards')
      .insert(insertPayload)
      .select('card_no')

    if (insertError) throw insertError

    return new Response(
      JSON.stringify({ success: true, cardIds: inserted.map(i => i.card_no.toString()) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
