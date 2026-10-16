import { createClient } from '@supabase/supabase-js';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
export const isSupabaseConfigured = Boolean(url && anonKey);
// Intentionally null until real credentials are supplied; never fall back to placeholder credentials.
export const supabase = isSupabaseConfigured ? createClient(url!, anonKey!) : null;
