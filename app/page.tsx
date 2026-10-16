'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Activity, ArrowRight, CheckCircle2, ClipboardCheck, KeyRound, LockKeyhole, Mail, Search, ShieldCheck, Smartphone, Store, Wrench } from 'lucide-react';
import { supabase, isSupabaseConfigured } from '../lib/supabase/client';

type Portal = 'owner' | 'technician';
export default function Home() {
  const router = useRouter();
  const [portal, setPortal] = useState<Portal>('owner');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [trackingId, setTrackingId] = useState('');
  const [phone, setPhone] = useState('');
  const [status, setStatus] = useState('');
  const [trackResult, setTrackResult] = useState<any>(null);
  const [busy, setBusy] = useState(false);

  async function login(e: FormEvent) {
    e.preventDefault(); setStatus('');
    if (!supabase || !isSupabaseConfigured) return setStatus('Supabase is not configured. Add the project URL and publishable key to .env.local or Vercel environment variables.');
    setBusy(true);
    try {
      const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
      if (error) throw error;
      if (!data.user) throw new Error('Sign-in could not be completed.');
      const { data: members, error: memberError } = await supabase.from('shop_members').select('role,status,shop_id,shops!inner(status)').eq('user_id', data.user.id).eq('role', portal).order('created_at', { ascending: false }).limit(1);
      if (memberError) throw memberError;
      const membership = members?.[0] as any;
      if (!membership) { await supabase.auth.signOut(); throw new Error(portal === 'owner' ? 'No shop-owner application is linked to this account. Register your shop first.' : 'No technician application is linked to this account. Create a technician account and select your shop ID.'); }
      if (membership.status !== 'APPROVED' || membership.shops?.status !== 'ACTIVE') throw new Error(`Your ${portal === 'owner' ? 'shop' : 'technician'} access is ${membership.status.toLowerCase()}. Approval is required before you can enter the workspace.`);
      router.push('/account');
    } catch (err) { setStatus(err instanceof Error ? err.message : 'Unable to sign in.'); }
    finally { setBusy(false); }
  }
  async function sendPasswordReset() {
    setStatus('');
    if (!supabase || !isSupabaseConfigured) return setStatus('Supabase is not configured.');
    if (!email.trim()) return setStatus('Enter your account email first.');
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim().toLowerCase(), { redirectTo: `${window.location.origin}/auth/callback?next=/reset-password` });
    setStatus(error ? error.message : 'If the account exists, a password recovery email has been requested. Check your inbox.');
  }
  async function track(e: FormEvent) {
    e.preventDefault(); setTrackResult(null); setStatus('');
    if (!supabase || !isSupabaseConfigured) return setStatus('Repair tracking will be available after Supabase is configured.');
    const digits = phone.replace(/\D/g, '');
    if (!trackingId.trim() || digits.length < 10) return setStatus('Enter the repair tracking ID and the registered mobile number.');
    setBusy(true);
    try {
      const { data, error } = await supabase.rpc('track_repair', { p_tracking_id: trackingId.trim(), p_phone: digits.slice(-10) });
      if (error) throw error;
      if (!data?.length) throw new Error('No matching repair was found. Check the tracking ID and registered mobile number.');
      setTrackResult(data[0]);
    } catch (err) { setStatus(err instanceof Error ? err.message : 'Unable to find this repair.'); }
    finally { setBusy(false); }
  }
  const input = 'w-full rounded-xl border border-slate-200 bg-white px-3.5 py-3 text-sm outline-none transition focus:border-blue-500 focus:ring-4 focus:ring-blue-50';
  return <main className="min-h-screen bg-[#f4f8ff] text-slate-900">
    <header className="border-b border-blue-100 bg-white"><div className="mx-auto flex max-w-7xl items-center justify-between px-5 py-4"><a href="/" className="flex items-center gap-3"><span className="grid h-11 w-11 place-items-center rounded-2xl bg-blue-700 text-white"><Smartphone size={23}/></span><span><b className="block text-lg tracking-tight">FoneZone</b><span className="block text-xs text-slate-500">Mobile repair management</span></span></a><span className="hidden rounded-full bg-blue-50 px-3 py-1.5 text-xs font-semibold text-blue-700 sm:inline-flex">Simple. Secure. Traceable.</span></div></header>
    <section className="mx-auto grid max-w-7xl gap-8 px-5 py-10 lg:grid-cols-[1.08fr_.92fr] lg:py-16">
      <div className="flex flex-col justify-center"><div className="inline-flex w-fit items-center gap-2 rounded-full border border-blue-100 bg-white px-3 py-1.5 text-xs font-semibold text-blue-700"><ShieldCheck size={15}/> Built for repair shops</div><h1 className="mt-6 max-w-2xl text-4xl font-bold leading-tight tracking-tight sm:text-5xl">Every repair, <span className="text-blue-700">under control.</span></h1><p className="mt-5 max-w-xl text-base leading-7 text-slate-600">Manage repair jobs, technicians, spare parts and repair certificates from one clear workspace. Customers can check repair progress without creating an account.</p><div className="mt-8 grid max-w-xl gap-3 sm:grid-cols-3">{[{icon:ClipboardCheck,title:'Repair tracking',text:'Clear status updates'},{icon:Activity,title:'Audit history',text:'SHA-256 tamper evidence'},{icon:CheckCircle2,title:'Certificate records',text:'Public lookup and hash display'}].map(x=><div key={x.title} className="rounded-2xl border border-blue-100 bg-white p-4"><x.icon className="text-blue-700" size={20}/><b className="mt-3 block text-sm">{x.title}</b><span className="mt-1 block text-xs leading-5 text-slate-500">{x.text}</span></div>)}</div><div className="mt-8 flex items-center gap-2 text-xs text-slate-500"><LockKeyhole size={14}/> Role-based access · Shop data isolation · No blockchain dependency</div></div>
      <div className="space-y-5">
        <div className="rounded-3xl border border-blue-100 bg-white p-5 shadow-sm sm:p-7"><div className="mb-6"><p className="text-xs font-bold uppercase tracking-[.18em] text-blue-700">Team portal</p><h2 className="mt-2 text-2xl font-bold">Sign in to FoneZone</h2><p className="mt-1 text-sm text-slate-500">Choose your account type to continue.</p></div><div className="grid grid-cols-2 gap-3"><button onClick={()=>{setPortal('owner');setStatus('')}} className={`rounded-2xl border p-4 text-left transition ${portal==='owner'?'border-blue-600 bg-blue-50 ring-1 ring-blue-600':'border-slate-200 hover:border-blue-300'}`}><Store size={22} className={portal==='owner'?'text-blue-700':'text-slate-500'}/><b className="mt-3 block text-sm">Shop Owner</b><span className="mt-1 block text-xs text-slate-500">Manage your shop</span></button><button onClick={()=>{setPortal('technician');setStatus('')}} className={`rounded-2xl border p-4 text-left transition ${portal==='technician'?'border-blue-600 bg-blue-50 ring-1 ring-blue-600':'border-slate-200 hover:border-blue-300'}`}><Wrench size={22} className={portal==='technician'?'text-blue-700':'text-slate-500'}/><b className="mt-3 block text-sm">Technician</b><span className="mt-1 block text-xs text-slate-500">Work on assigned jobs</span></button></div><form onSubmit={login} className="mt-5 space-y-4"><label className="block"><span className="mb-1.5 block text-xs font-semibold text-slate-700">Email address</span><span className="relative block"><Mail size={16} className="absolute left-3.5 top-3.5 text-slate-400"/><input className={`${input} pl-10`} type="email" autoComplete="email" required value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com"/></span></label><label className="block"><span className="mb-1.5 block text-xs font-semibold text-slate-700">Password</span><span className="relative block"><KeyRound size={16} className="absolute left-3.5 top-3.5 text-slate-400"/><input className={`${input} pl-10`} type="password" autoComplete="current-password" required value={password} onChange={e=>setPassword(e.target.value)} placeholder="Your password"/></span></label>{status&&<p role="alert" className="rounded-xl border border-amber-200 bg-amber-50 p-3 text-xs leading-5 text-amber-900">{status}</p>}<button disabled={busy} className="flex w-full items-center justify-center gap-2 rounded-xl bg-blue-700 px-4 py-3.5 text-sm font-semibold text-white transition hover:bg-blue-800 disabled:opacity-60">{busy?'Please wait…':'Sign in'}<ArrowRight size={16}/></button></form><div className="mt-5 flex flex-wrap items-center justify-center gap-x-4 gap-y-2 text-sm"><span className="text-slate-500">New to FoneZone? <a className="font-semibold text-blue-700 hover:underline" href={`/signup?type=${portal}`}>Apply as {portal==='owner'?'a shop owner':'a technician'}</a></span><button type="button" onClick={sendPasswordReset} className="text-xs font-semibold text-blue-700 underline">Forgot password?</button></div>{portal==='owner'&&<p className="mt-2 text-center text-xs"><a className="text-slate-500 underline hover:text-blue-700" href="/recover-owner">Recover owner account with recovery code</a></p>}<p className="mt-4 text-center text-[11px] text-slate-400">Platform administration uses a separate private entry.</p></div>
        <div className="rounded-3xl border border-blue-100 bg-gradient-to-br from-blue-700 to-blue-900 p-5 text-white sm:p-6"><div className="flex items-center gap-3"><span className="grid h-10 w-10 place-items-center rounded-xl bg-white/15"><Search size={20}/></span><div><h2 className="font-bold">Track a repair</h2><p className="text-xs text-blue-100">No customer account required</p></div></div><form onSubmit={track} className="mt-4 grid gap-3 sm:grid-cols-[1fr_1fr_auto]"><input className="min-w-0 rounded-xl border border-white/20 bg-white px-3 py-3 text-sm text-slate-900 outline-none focus:ring-4 focus:ring-blue-300/40" value={trackingId} onChange={e=>setTrackingId(e.target.value)} placeholder="Tracking ID" required/><input className="min-w-0 rounded-xl border border-white/20 bg-white px-3 py-3 text-sm text-slate-900 outline-none focus:ring-4 focus:ring-blue-300/40" type="tel" inputMode="numeric" value={phone} onChange={e=>setPhone(e.target.value.replace(/[^0-9+ ]/g,'').slice(0,14))} placeholder="Registered mobile" required/><button disabled={busy} className="rounded-xl bg-white px-4 py-3 text-sm font-bold text-blue-800 hover:bg-blue-50 disabled:opacity-60">Track</button></form>{trackResult&&<div className="mt-4 rounded-2xl bg-white p-4 text-slate-900"><div className="flex items-start justify-between gap-3"><div><p className="text-xs text-slate-500">{trackResult.tracking_id}</p><b className="mt-1 block">{trackResult.shop_name}</b><p className="mt-1 text-sm text-slate-600">{trackResult.device_description}</p></div><span className="rounded-full bg-blue-50 px-2.5 py-1 text-xs font-bold text-blue-700">{trackResult.status}</span></div><p className="mt-3 text-xs text-slate-500">Last updated: {new Date(trackResult.updated_at).toLocaleString()}</p></div>}{status&&<p role="alert" className="mt-3 rounded-xl bg-white/10 p-3 text-xs leading-5 text-white">{status}</p>}</div>
      </div>
    </section><footer className="border-t border-blue-100 bg-white"><div className="mx-auto flex max-w-7xl flex-col gap-2 px-5 py-5 text-xs text-slate-500 sm:flex-row sm:items-center sm:justify-between"><span>© {new Date().getFullYear()} FoneZone · Repair operations</span><span>Blue-and-white interface · Secure access · Verifiable records</span></div></footer>
  </main>;
}
