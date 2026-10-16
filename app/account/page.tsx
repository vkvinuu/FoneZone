'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { supabase, isSupabaseConfigured } from '../../lib/supabase/client';

export default function AccountPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [role, setRole] = useState('CUSTOMER');
  const [application, setApplication] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    async function load() {
      if (!isSupabaseConfigured || !supabase) { router.replace('/'); return; }
      const { data: { user }, error: authError } = await supabase.auth.getUser();
      if (authError || !user) { router.replace('/'); return; }
      if (!active) return;
      setEmail(user.email || '');
      setName(String(user.user_metadata?.full_name || ''));
      const { data: profile, error: profileError } = await supabase.from('profiles').select('full_name,platform_role').eq('id', user.id).maybeSingle();
      if (profileError) setError(`Could not load profile: ${profileError.message}`);
      if (profile) { setName(profile.full_name || String(user.user_metadata?.full_name || '')); setRole(profile.platform_role || 'CUSTOMER'); }
      const { data: apps, error: appError } = await supabase.from('shop_applications').select('shop_name,status,review_note,created_at').eq('applicant_user_id', user.id).order('created_at', { ascending: false }).limit(1);
      if (!appError && apps?.[0]) setApplication(`${apps[0].shop_name}: ${apps[0].status}${apps[0].review_note ? ` — ${apps[0].review_note}` : ''}`);
      if (appError) setError(`Could not load shop application: ${appError.message}`);
      setLoading(false);
    }
    void load();
    return () => { active = false; };
  }, [router]);

  async function signOut() { if (supabase) await supabase.auth.signOut(); router.replace('/'); }
  return <main className="min-h-screen bg-slate-50 p-5 text-slate-900"><section className="mx-auto max-w-2xl rounded-2xl border border-slate-200 bg-white p-6 shadow-sm"><div className="flex items-start justify-between gap-3"><div><p className="text-xs font-semibold uppercase tracking-widest text-slate-500">FoneZone account</p><h1 className="mt-2 text-2xl font-semibold">Account overview</h1></div><button onClick={signOut} className="rounded-lg border px-3 py-2 text-sm">Sign out</button></div>{loading ? <p className="mt-6 text-sm text-slate-500">Loading account…</p> : <div className="mt-6 space-y-4 text-sm"><div className="rounded-lg bg-slate-50 p-4"><p><b>Name:</b> {name || 'Not provided'}</p><p className="mt-2"><b>Email:</b> {email}</p><p className="mt-2"><b>Account role:</b> {role === 'PLATFORM_ADMIN' ? 'Platform administrator' : 'Customer account'}</p></div>{application && <div className="rounded-lg border border-slate-200 p-4"><h2 className="font-semibold">Shop application</h2><p className="mt-2">{application}</p></div>}{error && <p role="alert" className="rounded-lg bg-amber-50 p-3 text-amber-900">{error}</p>}<p className="text-xs leading-5 text-slate-500">Your account is authenticated by Supabase. Repair operations and shop administration are not exposed here until their database-backed workflows and authorization policies are connected and verified.</p></div>}</section></main>;
}
