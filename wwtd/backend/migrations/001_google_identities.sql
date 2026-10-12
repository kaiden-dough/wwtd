CREATE TABLE IF NOT EXISTS public.google_identities (
  supabase_user_id VARCHAR(36) PRIMARY KEY,
  profile_id VARCHAR(36) NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE
);
ALTER TABLE public.google_identities ENABLE ROW LEVEL SECURITY;
