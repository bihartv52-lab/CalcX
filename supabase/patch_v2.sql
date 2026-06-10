-- ============================================================
-- CALCX DATABASE SCHEMA PATCH V2
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ============================================================

-- 1. Ensure fcm_token and custom_notification_text columns exist in public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_notification_text TEXT DEFAULT 'Your previous calculation is pending.';

-- 2. Enable ALL operations on message_reads RLS policy for owners (allows upsert)
DROP POLICY IF EXISTS "Users can mark messages as read" ON public.message_reads;
CREATE POLICY "Users can mark messages as read" ON public.message_reads
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 3. Trigger to clear typing status when user goes offline
CREATE OR REPLACE FUNCTION public.handle_profile_presence_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'offline' THEN
    UPDATE public.typing_indicators
    SET is_typing = false, updated_at = NOW()
    WHERE user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_presence_change ON public.profiles;
CREATE TRIGGER on_profile_presence_change
  AFTER UPDATE OF status ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_profile_presence_change();

-- 4. Re-create Friend Request Trigger to notify on accepted status updates
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS TRIGGER AS $$
DECLARE
  disguise_text TEXT;
BEGIN
  IF NEW.status = 'accepted' AND (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status != 'accepted')) THEN
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
  ELSIF NEW.status = 'pending' AND TG_OP = 'INSERT' THEN
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
  AFTER INSERT OR UPDATE OF status ON public.friend_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_friend_request_notification();
