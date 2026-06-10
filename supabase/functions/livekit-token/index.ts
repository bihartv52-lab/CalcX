// Supabase Edge Function for LiveKit Token Generation
// Deploy: supabase functions deploy livekit-token

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// LiveKit JWT generation (manual implementation)
function base64UrlEncode(str: string): string {
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')
}

async function generateLiveKitToken(
  apiKey: string,
  apiSecret: string,
  roomName: string,
  participantName: string,
  participantIdentity: string
): Promise<string> {
  // JWT Header
  const header = {
    alg: 'HS256',
    typ: 'JWT',
  }

  // JWT Payload
  const now = Math.floor(Date.now() / 1000)
  const payload = {
    exp: now + 3600, // Token expires in 1 hour
    iss: apiKey,
    nbf: now,
    sub: participantIdentity,
    video: {
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    },
    name: participantName,
  }

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header))
  const encodedPayload = base64UrlEncode(JSON.stringify(payload))

  // Create signature
  const message = `${encodedHeader}.${encodedPayload}`
  const encoder = new TextEncoder()
  const keyData = encoder.encode(apiSecret)
  const messageData = encoder.encode(message)

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  )

  const signature = await crypto.subtle.sign('HMAC', cryptoKey, messageData)
  const encodedSignature = base64UrlEncode(
    String.fromCharCode(...new Uint8Array(signature))
  )

  // Return JWT
  return `${message}.${encodedSignature}`
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    // Get LiveKit credentials from environment
    const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY')
    const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET')

    if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
      throw new Error('LiveKit credentials not configured')
    }

    // Verify user is authenticated
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      throw new Error('Unauthorized')
    }

    // Get request body
    const { room_name, participant_name } = await req.json()

    if (!room_name || !participant_name) {
      throw new Error('Missing room_name or participant_name')
    }

    // Generate LiveKit token
    const token = await generateLiveKitToken(
      LIVEKIT_API_KEY,
      LIVEKIT_API_SECRET,
      room_name,
      participant_name,
      user.id
    )

    return new Response(
      JSON.stringify({
        token,
        room_name,
        participant_name,
        participant_identity: user.id,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error.message,
      }),
      {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  }
})
