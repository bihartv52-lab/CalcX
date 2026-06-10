-- ============================================================
-- CALCX DATABASE PATCH: RLS POLICIES, NOTIFICATIONS & AUTO-ACCEPT
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard/project/ephrnrtnoykxggujbpgo/sql)
-- ============================================================

-- 1. Fix accepting friend requests (allow inserting friendship records for either party)
DROP POLICY IF EXISTS "Users can add friends" ON friends;
CREATE POLICY "Users can add friends"
  ON friends FOR INSERT
  WITH CHECK (auth.uid() = user_id OR auth.uid() = friend_id);

-- 2. Fix sync playback (allow room participants to update rooms)
DROP POLICY IF EXISTS "Hosts can update their rooms" ON rooms;
CREATE POLICY "Hosts can update their rooms"
  ON rooms FOR UPDATE
  USING (
    auth.uid() = host_id OR 
    EXISTS (
      SELECT 1 FROM room_participants 
      WHERE room_id = id AND user_id = auth.uid()
    )
  );

-- 3. Fix notifications RLS (allow authenticated users to insert notifications for other users)
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
CREATE POLICY "Users can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- 4. Add auto_accept_friends column to profiles (default to TRUE so it works out-of-the-box)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS auto_accept_friends BOOLEAN DEFAULT TRUE;

-- 5. Auto-accept Friend Requests Trigger
-- When a request is inserted, if receiver has auto-accept enabled, accept it immediately
-- and create friendship records automatically.
CREATE OR REPLACE FUNCTION public.handle_friend_request_insert()
RETURNS TRIGGER AS $$
DECLARE
  auto_accept BOOLEAN;
BEGIN
  -- Check if receiver has auto accept enabled (default to true)
  SELECT coalesce(auto_accept_friends, true) INTO auto_accept 
  FROM public.profiles 
  WHERE id = NEW.receiver_id;
  
  IF auto_accept THEN
    -- Update request status to accepted
    NEW.status := 'accepted';
    
    -- Create friendship rows (both directions)
    INSERT INTO public.friends (user_id, friend_id)
    VALUES 
      (NEW.sender_id, NEW.receiver_id),
      (NEW.receiver_id, NEW.sender_id)
    ON CONFLICT (user_id, friend_id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_friend_request_inserted ON public.friend_requests;
CREATE TRIGGER on_friend_request_inserted
  BEFORE INSERT ON public.friend_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_friend_request_insert();

-- 6. Friend Request Notifications Trigger
-- Send a notification when a request is inserted. If it was auto-accepted, notify the sender
-- that the request was accepted. Otherwise, notify the receiver about the pending request.
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    -- Notify sender that request was accepted
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.sender_id,
      'friend_request_accepted',
      'Friend Request Accepted',
      (SELECT username FROM public.profiles WHERE id = NEW.receiver_id) || ' is now your friend!',
      jsonb_build_object('request_id', NEW.id, 'receiver_id', NEW.receiver_id)
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- Notify receiver about pending request
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.receiver_id,
      'friend_request',
      'New Friend Request',
      (SELECT username FROM public.profiles WHERE id = NEW.sender_id) || ' sent you a friend request.',
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

-- 7. Chat Messages Notifications Trigger
-- Send a notification when a message is inserted. If it's a DM, notify the receiver.
-- If it's in a room, notify all other participants of that room.
CREATE OR REPLACE FUNCTION public.handle_message_notification()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.room_id IS NULL THEN
    -- Direct message: notify receiver_id
    INSERT INTO public.notifications (user_id, type, title, body, data)
    VALUES (
      NEW.receiver_id,
      'message',
      'New Message',
      (SELECT username FROM public.profiles WHERE id = NEW.sender_id) || ': ' || coalesce(NEW.content, 'Sent a media file'),
      jsonb_build_object('message_id', NEW.id, 'sender_id', NEW.sender_id)
    )
    ON CONFLICT (id) DO NOTHING;
  ELSE
    -- Room message: notify all participants of the room (excluding sender)
    INSERT INTO public.notifications (user_id, type, title, body, data)
    SELECT 
      user_id,
      'message',
      'New Message in Room',
      (SELECT username FROM public.profiles WHERE id = NEW.sender_id) || ': ' || coalesce(NEW.content, 'Sent a media file'),
      jsonb_build_object('room_id', NEW.room_id, 'message_id', NEW.id, 'sender_id', NEW.sender_id)
    FROM public.room_participants
    WHERE room_id = NEW.room_id AND user_id != NEW.sender_id
    ON CONFLICT (id) DO NOTHING;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_message_created ON public.messages;
CREATE TRIGGER on_message_created
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_notification();
