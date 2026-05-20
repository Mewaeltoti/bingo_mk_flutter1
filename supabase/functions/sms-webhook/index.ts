import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Verify API Token
    const authHeader = req.headers.get('Authorization')
    const url = new URL(req.url)
    const queryToken = url.searchParams.get('token')

    const expectedToken = "BingoEthioSharedSecretToken2026"
    const hasValidHeader = authHeader === `Bearer ${expectedToken}`
    const hasValidQuery = queryToken === expectedToken

    if (!hasValidHeader && !hasValidQuery) {
      console.warn("Unauthorized SMS Webhook attempt blocked.")
      return new Response("Unauthorized: Invalid API Token", { status: 401 })
    }

    const body = await req.json().catch(() => ({}))
    const { sender, text } = body

    if (!sender || !text) {
      return new Response("Bad Request: Missing sender or text", { status: 400 })
    }

    console.log(`Received SMS from ${sender}: "${text}"`)

    // 2. Parse CBE or Telebirr notification
    const parsed = parseSmsNotification(sender, text)
    if (!parsed) {
      console.log("SMS does not match a Telebirr or CBE credit transaction template. Ignored.")
      return new Response("Ignored: Not a payment SMS", { status: 200 })
    }

    const { amount, reference, bank } = parsed
    console.log(`Parsed credit notification -> Bank: ${bank}, Amount: ${amount} ETB, Ref: ${reference}`)

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    // 3. Match and reconcile atomically in a Postgres RPC function
    const { data: result, error: rpcError } = await supabaseAdmin.rpc('process_bank_notification', {
      p_amount: amount,
      p_reference: reference,
      p_bank: bank,
      p_sender: sender,
      p_text: text
    })

    if (rpcError) throw rpcError

    console.log(`RPC reconciliation result: ${result}`)

    return new Response(
      JSON.stringify({ success: true, result }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error: any) {
    console.error("SMS webhook error:", error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    )
  }
})

function parseSmsNotification(sender: string, text: string) {
  const cleanText = text.replace(/\s+/g, ' ')
  const lowerSender = sender.toLowerCase()

  // 1. TELEBIRR PARSING
  if (lowerSender.includes("telebirr") || lowerSender.includes("802")) {
    const amountRegex = /(?:received|transferred)\s*([\d,.]+)\s*ETB/i
    const refRegex = /(?:Ref|reference|Trans\.Ref):\s*([a-zA-Z0-9]+)/i

    const amountMatch = cleanText.match(amountRegex)
    const refMatch = cleanText.match(refRegex)

    if (amountMatch && refMatch) {
      const amount = parseFloat(amountMatch[1].replace(/,/g, ''))
      const reference = refMatch[1].trim()
      return { amount, reference, bank: "Telebirr" }
    }
  }

  // 2. CBE PARSING
  if (lowerSender.includes("cbe") || lowerSender.includes("cbebirr") || lowerSender.includes("1000")) {
    const amountRegex = /(?:credited\s+with|received|transfer\s+of)\s*(?:ETB)?\s*([\d,.]+)/i
    const amountMatch = cleanText.match(amountRegex)

    const ftRegex = /(FT[A-Z0-9]{10})/i
    const refMatch = cleanText.match(ftRegex)

    if (amountMatch && refMatch) {
      const amount = parseFloat(amountMatch[1].replace(/,/g, ''))
      const reference = refMatch[1].trim()
      return { amount, reference, bank: "CBE" }
    }
  }

  // 3. GENERIC FALLBACK
  const genericAmountRegex = /(?:ETB|Birr)\s*([\d,.]+)/i
  const genericRefRegex = /(?:Ref|Txn|Reference):\s*([a-zA-Z0-9]+)/i

  const gAmountMatch = cleanText.match(genericAmountRegex)
  const gRefMatch = cleanText.match(genericRefRegex)

  if (gAmountMatch && gRefMatch) {
    const amount = parseFloat(gAmountMatch[1].replace(/,/g, ''))
    const reference = gRefMatch[1].trim()
    return { amount, reference, bank: "Generic" }
  }

  return null
}
