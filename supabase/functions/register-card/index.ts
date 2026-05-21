import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

    const body = await req.json().catch(() => ({}))
    const { cardId } = body
    if (!cardId) throw new Error("cardId is required")

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    // Fetch card price from live game
    const { data: game, error: gameError } = await supabaseAdmin
      .from('games')
      .select('card_price')
      .eq('id', 'live')
      .single()

    if (gameError || !game) throw new Error("Live game not found.")
    const price = game.card_price || 10.0

    // Invoke atomic register_card RPC
    const { data: result, error: rpcError } = await supabaseAdmin.rpc('register_card', {
      p_user_id: user.id,
      p_card_no: Number(cardId),
      p_price: price
    })

    if (rpcError) throw rpcError

    if (result && result.success === false) {
      throw new Error(result.error || "Failed to register card")
    }

    return new Response(
      JSON.stringify({ success: true, message: result.message || "Card registered successfully." }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
