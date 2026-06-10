-- Create game_sessions table for real-time multiplayer games
CREATE TABLE IF NOT EXISTS public.game_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID REFERENCES public.rooms(id) ON DELETE CASCADE,
  game_type TEXT NOT NULL, -- 'ludo', 'skribbl', 'xo'
  game_state JSONB NOT NULL DEFAULT '{}', -- Synced moves/turns/players
  status TEXT DEFAULT 'active', -- 'active', 'finished'
  winner_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(room_id, status)
);

-- Enable RLS
ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;

-- Basic Policies
CREATE POLICY "Users can view active game sessions" 
  ON public.game_sessions FOR SELECT 
  USING (true);

CREATE POLICY "Users can insert game sessions" 
  ON public.game_sessions FOR INSERT 
  WITH CHECK (true);

CREATE POLICY "Users can update game sessions" 
  ON public.game_sessions FOR UPDATE 
  USING (true);

-- Enable real-time updates for game_sessions
ALTER PUBLICATION supabase_realtime ADD TABLE game_sessions;
