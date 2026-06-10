-- CalcX Supabase Patch v3: Credit System
-- Run this in your Supabase SQL Editor

-- 1. Add credit balance to profiles (defaults to 100 credits, cannot be negative)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS credits INTEGER DEFAULT 100 CHECK (credits >= 0);

-- 2. Create transactions tracking table
CREATE TABLE IF NOT EXISTS public.credit_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  amount INTEGER NOT NULL, -- positive for credits added, negative for deducted
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Enable RLS on credit transactions
ALTER TABLE public.credit_transactions ENABLE ROW LEVEL SECURITY;

-- 4. Set RLS Policies
CREATE POLICY "Users can view own transactions" 
  ON public.credit_transactions FOR SELECT 
  TO authenticated 
  USING (auth.uid() = user_id);

-- 5. Safe stored procedure to place a game wager (subtracts credits & creates transaction logs)
CREATE OR REPLACE FUNCTION place_bet(player_id UUID, bet_amount INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  current_balance INTEGER;
BEGIN
  -- Obtain exclusive row lock on profile balance
  SELECT credits INTO current_balance 
  FROM public.profiles 
  WHERE id = player_id 
  FOR UPDATE;
  
  IF current_balance >= bet_amount THEN
    -- Deduct balance
    UPDATE public.profiles 
    SET credits = credits - bet_amount 
    WHERE id = player_id;
    
    -- Insert transaction log
    INSERT INTO public.credit_transactions (user_id, amount, description)
    VALUES (player_id, -bet_amount, 'Bet Wager Placed');
    
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Safe stored procedure to payout winner (adds credits & creates transaction logs)
CREATE OR REPLACE FUNCTION reward_winner(player_id UUID, reward_amount INTEGER, game_name TEXT)
RETURNS VOID AS $$
BEGIN
  -- Add balance
  UPDATE public.profiles 
  SET credits = credits + reward_amount 
  WHERE id = player_id;
  
  -- Insert transaction log
  INSERT INTO public.credit_transactions (user_id, amount, description)
  VALUES (player_id, reward_amount, CONCAT('Winner Payout: ', game_name));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Add credit_transactions to the realtime publication
DO $$
BEGIN
  IF EXISTS (
      SELECT 1 FROM pg_class WHERE relname = 'credit_transactions' AND relnamespace = 'public'::regnamespace
  ) AND NOT EXISTS (
      SELECT 1 FROM pg_publication_rel pr 
      JOIN pg_publication p ON p.oid = pr.prpubid 
      JOIN pg_class c ON c.oid = pr.prrelid 
      WHERE p.pubname = 'supabase_realtime' AND c.relname = 'credit_transactions'
  ) THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.credit_transactions;
  END IF;
END $$;
