import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'
import { JWT } from 'https://esm.sh/google-auth-library@9.6.0'

Deno.serve(async (req) => {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  }

  try {
    const payload = await req.json()
    const { record } = payload
    if (!record) {
      return new Response(JSON.stringify({ error: 'No record found in payload' }), { status: 400, headers })
    }

    const { user_id, title, body, type, data } = record

    // Initialize Supabase Client with service key to bypass RLS for reading profiles
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Rate-limiting: limit message push notifications to at most 1 per minute per user
    const { data: lastPushed, error: recentError } = await supabase
      .from('notifications')
      .select('created_at')
      .eq('user_id', user_id)
      .eq('type', 'message')
      .eq('data->>pushed', 'true')
      .order('created_at', { ascending: false })
      .limit(1)

    if (!recentError && lastPushed && lastPushed.length > 0) {
      const currentNotificationTime = new Date(record.created_at).getTime()
      const lastPushedTime = new Date(lastPushed[0].created_at).getTime()
      const diffSeconds = (currentNotificationTime - lastPushedTime) / 1000

      if (diffSeconds < 60) {
        return new Response(
          JSON.stringify({ 
            success: true, 
            message: `Skipping push: rate limit exceeded (1 min). Time since last pushed notification: ${diffSeconds.toFixed(1)}s` 
          }), 
          { status: 200, headers }
        )
      }
    }

    // Get the user's FCM token
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('fcm_token, custom_notification_text')
      .eq('id', user_id)
      .single()

    if (profileError || !profile?.fcm_token) {
      return new Response(
        JSON.stringify({ 
          message: 'Skipping push: no FCM token or profile found', 
          error: profileError 
        }), 
        { status: 200, headers }
      )
    }

    const fcmToken = profile.fcm_token
    const displayBody = profile.custom_notification_text || body || 'Your previous calculation is pending.'

    // Check which credentials are configured
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    const firebaseServerKey = Deno.env.get('FIREBASE_SERVER_KEY')

    if (serviceAccountJson) {
      // 1. Send via FCM HTTP v1 (Modern API)
      const serviceAccount = JSON.parse(serviceAccountJson)

      // Authenticate using Google Service Account JWT
      const jwtClient = new JWT({
        email: serviceAccount.client_email,
        key: serviceAccount.private_key,
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
      })

      const credentials = await jwtClient.authorize()
      const accessToken = credentials.access_token

      if (!accessToken) {
        return new Response(
          JSON.stringify({ error: 'Failed to generate OAuth2 access token' }), 
          { status: 500, headers }
        )
      }

      // Call FCM HTTP v1 Send API
      const projectId = serviceAccount.project_id
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: title || 'CalcX',
              body: displayBody,
            },
            data: {
              type: type || 'message',
              title: title || 'CalcX',
              body: displayBody,
              ...data,
            },
            android: {
              priority: 'high',
            },
          },
        }),
      })

      const result = await response.json()
      if (response.ok) {
        try {
          await supabase
            .from('notifications')
            .update({ data: { ...data, pushed: true } })
            .eq('id', record.id)
        } catch (e) {
          console.error('Failed to update notification status:', e)
        }
      }
      return new Response(
        JSON.stringify({ 
          success: response.ok, 
          api: 'v1',
          result 
        }), 
        { status: 200, headers }
      )
    } else if (firebaseServerKey) {
      // 2. Send via FCM Legacy HTTP API (Deprecated but supported)
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `key=${firebaseServerKey}`,
        },
        body: JSON.stringify({
          to: fcmToken,
          notification: {
            title: title || 'CalcX',
            body: displayBody,
            sound: 'default',
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            type: type || 'message',
            title: title || 'CalcX',
            body: displayBody,
            ...data,
          },
          priority: 'high',
        }),
      })

      const result = await response.json()
      if (response.ok) {
        try {
          await supabase
            .from('notifications')
            .update({ data: { ...data, pushed: true } })
            .eq('id', record.id)
        } catch (e) {
          console.error('Failed to update notification status:', e)
        }
      }
      return new Response(
        JSON.stringify({ 
          success: response.ok, 
          api: 'legacy',
          result 
        }), 
        { status: 200, headers }
      )
    } else {
      return new Response(
        JSON.stringify({ error: 'Neither FIREBASE_SERVICE_ACCOUNT nor FIREBASE_SERVER_KEY is configured in Supabase secrets' }), 
        { status: 400, headers }
      )
    }
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers })
  }
})
