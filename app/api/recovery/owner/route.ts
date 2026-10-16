import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(request: Request) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) return NextResponse.json({ error: 'Owner recovery is not configured on the server.' }, { status: 503 });
  let body: { email?: string; recoveryCode?: string };
  try { body = await request.json(); } catch { return NextResponse.json({ error: 'Invalid request.' }, { status: 400 }); }
  const email = String(body.email || '').trim().toLowerCase();
  const code = String(body.recoveryCode || '').trim();
  if (!email || !/^[A-Za-z0-9]{12}$/.test(code)) return NextResponse.json({ error: 'Enter the account email and 12-character recovery code.' }, { status: 400 });
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(code));
  const hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, '0')).join('');
  const admin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: profile } = await admin.from('profiles').select('id,email').eq('email', email).maybeSingle();
  if (!profile) return NextResponse.json({ error: 'Recovery could not be verified. Check your details or use email recovery.' }, { status: 403 });
  const { data: ownerRows } = await admin.from('shop_members').select('id').eq('user_id', profile.id).eq('role', 'owner').eq('recovery_code_hash', hash).limit(1);
  if (!ownerRows?.length) return NextResponse.json({ error: 'Recovery could not be verified. Check your details or use email recovery.' }, { status: 403 });
  const { data: linkData, error } = await admin.auth.admin.generateLink({ type: 'recovery', email, options: { redirectTo: `${new URL(request.url).origin}/auth/callback?next=/reset-password` } });
  if (error || !linkData.properties?.action_link) return NextResponse.json({ error: 'Could not create a recovery link. Use the email recovery option.' }, { status: 500 });
  return NextResponse.json({ actionLink: linkData.properties.action_link });
}
