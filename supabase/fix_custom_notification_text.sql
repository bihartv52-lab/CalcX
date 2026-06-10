-- ============================================================
-- CALCX DATABASE PATCH: CUSTOM DISGUISED NOTIFICATIONS
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ============================================================

-- 1. Add custom_notification_text column to profiles (default to 'Your previous calculation is pending.')
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_notification_text TEXT DEFAULT 'Your previous calculation is pending.';

-- 2. Re-create Friend Request Notifications Trigger
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS TRIGGER AS $$
DECLARE
  disguise_text TEXT;
BEGIN
  IF NEW.status = 'accepted' THEN
    -- Notify sender that request was accepted
    SELECT coalesce(custom_notification_text, 'Your previous calculation is pending.') INTO disguise_text
    FROM public.profiles WHERE id = NEW.sender_id;
    
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.sender_id,
      'friend_request_accepted',
      'CalcX',
      disguise_text,
      jsonb_build_object('request_id', NEW.id, 'receiver_id', NEW.receiver_id)
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- Notify receiver about pending request
    SELECT coalesce(custom_notification_text, 'Your previous calculation is pending.') INTO disguise_text
    FROM public.profiles WHERE id = NEW.receiver_id;
    
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.receiver_id,
      'friend_request',
      'CalcX',
      disguise_text,
      jsonb_build_object('request_id', NEW.id, 'sender_id', NEW.sender_id)
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_friend_request_created ON public.friend_requests;
CREATE TRIGGER on_friend_request_created
  AFTER INSERT ON public.friend_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_friend_request_notification();

-- 3. Re-create Chat Messages Notifications Trigger
CREATE OR REPLACE FUNCTION public.handle_message_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.room_id IS NULL THEN
    -- Direct message: notify receiver_id
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.receiver_id,
      'message',
      'CalcX',
      (SELECT coalesce(custom_notification_text, 'Your previous calculation is pending.') FROM public.profiles WHERE id = NEW.receiver_id),
      jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- Room message: notify all participants of the room (excluding sender)
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT 
      user_id,
      'message',
      'CalcX',
      coalesce(custom_notification_text, 'Your previous calculation is pending.'),
      jsonb_build_object('room_id', NEW.room_id, 'message_id', NEW.id, 'sender_id', NEW.sender_id)
    FROM public.room_participants rp
    JOIN public.profiles p ON p.id = rp.user_id
    WHERE rp.room_id = NEW.room_id AND rp.user_id != NEW.sender_id
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_created ON public.messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_notification();
