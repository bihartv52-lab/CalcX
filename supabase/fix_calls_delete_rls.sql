-- ==========================================================
-- Fix Calls Table DELETE Row Level Security (RLS) Policy
-- Enables users to delete individual or all calls from their call history
-- ==========================================================

-- Drop existing delete policy if present
DROP POLICY IF EXISTS "Users can delete their calls" ON public.calls;

-- Enable DELETE on calls for caller or receiver
CREATE POLICY "Users can delete their calls"
  ON public.calls
  FOR DELETE
  USING (
    auth.uid() = caller_id OR auth.uid() = receiver_id
  );
