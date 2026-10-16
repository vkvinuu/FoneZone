'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, CheckCircle2, KeyRound, Store, Wrench } from 'lucide-react';
import { supabase, isSupabaseConfigured } from '../../lib/supabase/client';

type SignupType = 'owner' | 'technician';
type ShopOption = { id: string; shop_code: string; name: string; status: string };
export default function SignupPage() {
  const router = useRouter();
  const [type, setType] = useState<SignupType>('owner');
  const [name, setName] = useState(''); const [shopName, setShopName] = useState(''); const [shopCode, setShopCode] = useState('');
  const [email, setEmail] = useState(''); const [phone, setPhone] = useState(''); const [password, setPassword] = useState(''); const [confirm, setConfirm] = useState('');
  const [shops, setShops] = useState<ShopOption[]>([]); const [message, setMessage] = useState(''); const [success, setSuccess] = useState(false); const [busy, setBusy] = useState(false); const [recoveryCode, setRecoveryCode] = useState('');
  useEffect(() => { const requested = new URLSearchParams(window.location.search).get('type'); setType(requested === 'technician' ? 'technician' : 'owner'); }, []);
  useEffect(() => { let alive = true; async function load() { if (!supabase || !isSupabaseConfigured) return; const { data } = await supabase.from('shops').select('id,shop_code,name,status').eq('status','ACTIVE').order('shop_code'); if (alive && data) setShops(data as ShopOption[]); } void load(); return () => { alive = false; }; }, []);
  async function submit(e: FormEvent) {
    e.preventDefault(); setMessage(''); setSuccess(false);
    if (!supabase || !isSupabaseConfigured) return setMessage('Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY.');
    const digits = phone.replace(/\D/g,'').slice(-10);
    if (!name.trim()) return setMessage('Enter your full name.');
    if (!/^[6-9]\d{9}$/.test(digits)) return setMessage('Enter a valid 10-digit Indian mobile number.');
    if (type === 'owner' && shopName.trim().length < 2) return setMessage('Enter your shop name.');
    if (type === 'technician' && !shopCode) return setMessage('Choose the shop you want to join.');
    if (password.length < 8) return setMessage('Use a password with at least 8 characters.');
    if (password !== confirm) return setMessage('The passwords do not match.');
    setBusy(true);
    try {
      const selected = shops.find(s => s.shop_code === shopCode);
      let ownerCode = '';
      let ownerCodeHash = '';
      if (type === 'owner') {
        const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
        const bytes = crypto.getRandomValues(new Uint8Array(12));
        ownerCode = Array.from(bytes, b => alphabet[b % alphabet.length]).join('');
        ownerCodeHash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(ownerCode)).then(hash => Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2,'0')).join(''));
      }
      const { data, error } = await supabase.auth.signUp({ email: email.trim().toLowerCase(), password, options: { emailRedirectTo: `${window.location.origin}/auth/callback`, data: { full_name: name.trim(), phone: `+91${digits}`, account_type: type, shop_name: type === 'owner' ? shopName.trim() : null, shop_code: type === 'technician' ? selected?.shop_code : null, recovery_code_hash: ownerCodeHash || null } } });
      if (error) throw error;
      if (!data.user || (data.user.identities && data.user.identities.length === 0)) throw new Error('This email may already be registered. Try signing in or use password recovery.');
      setSuccess(true);
      if (ownerCode) setRecoveryCode(ownerCode);
      setMessage(data.session ? (type === 'owner' ? 'Account created. Your shop is pending Platform Admin approval. Save the recovery code shown below now; it will not be shown again.' : 'Account created. The selected shop owner must approve your technician membership.') : 'Registration received. If email confirmation is enabled, confirm your email. Save the recovery code below now; it will not be shown again. Your access stays pending until approval.');
    } catch (err) { setMessage(err instanceof Error ? err.message : 'Registration failed. Please try again.'); }
    finally { setBusy(false); }
  }
  const input = 'w-full rounded-xl border border-slate-200 px-3.5 py-3 text-sm outline-none focus:border-blue-500 focus:ring-4 focus:ring-blue-50';
  return <main className="min-h-screen bg-[#f4f8ff] px-4 py-10 text-slate-900"><div className="mx-auto max-w-xl"><button onClick={() => router.push('/')} className="mb-6 flex items-center gap-2 text-sm text-slate-600 hover:text-blue-700"><ArrowLeft size={16}/> Back to FoneZone</button><section className="rounded-3xl border border-blue-100 bg-white p-6 shadow-sm sm:p-8"><div className="flex items-center gap-3"><span className="grid h-12 w-12 place-items-center rounded-2xl bg-blue-700 text-white">{type === 'owner' ? <Store/> : <Wrench/>}</span><div><p className="text-xs font-bold uppercase tracking-[.16em] text-blue-700">Join FoneZone</p><h1 className="mt-1 text-2xl font-bold">{type === 'owner' ? 'Apply as a shop owner' : 'Join as a technician'}</h1></div></div><p className="mt-3 text-sm leading-6 text-slate-500">{type === 'owner' ? 'Your shop application will be reviewed by the FoneZone Platform Admin.' : 'Choose an active shop. Its owner must approve your membership before you can access shop data.'}</p><div className="mt-6 grid grid-cols-2 gap-3"><button type="button" onClick={() => {setType('owner');setMessage('')}} className={`rounded-xl border p-3 text-sm font-semibold ${type==='owner'?'border-blue-600 bg-blue-50 text-blue-800':'border-slate-200 text-slate-600'}`}>Shop Owner</button><button type="button" onClick={() => {setType('technician');setMessage('')}} className={`rounded-xl border p-3 text-sm font-semibold ${type==='technician'?'border-blue-600 bg-blue-50 text-blue-800':'border-slate-200 text-slate-600'}`}>Technician</button></div><form onSubmit={submit} className="mt-5 space-y-4"><label className="block"><span className="mb-1.5 block text-xs font-semibold">Full name</span><input className={input} value={name} onChange={e=>setName(e.target.value)} autoComplete="name" required placeholder="Your full name"/></label>{type==='owner'?<label className="block"><span className="mb-1.5 block text-xs font-semibold">Shop name</span><input className={input} value={shopName} onChange={e=>setShopName(e.target.value)} autoComplete="organization" required placeholder="e.g. SS Mobile"/></label>:<label className="block"><span className="mb-1.5 block text-xs font-semibold">Select active shop</span><select className={input} value={shopCode} onChange={e=>setShopCode(e.target.value)} required><option value="">Choose a shop</option>{shops.map(s=><option key={s.id} value={s.shop_code}>{s.shop_code} · {s.name}</option>)}</select>{shops.length===0&&<span className="mt-1 block text-xs text-amber-700">No approved shops are currently available. Ask the shop owner to complete onboarding first.</span>}</label>}<label className="block"><span className="mb-1.5 block text-xs font-semibold">Email address</span><input className={input} type="email" value={email} onChange={e=>setEmail(e.target.value)} autoComplete="email" required placeholder="you@example.com"/></label><label className="block"><span className="mb-1.5 block text-xs font-semibold">Mobile number</span><input className={input} type="tel" inputMode="numeric" value={phone} onChange={e=>setPhone(e.target.value.replace(/\D/g,'').slice(-10))} autoComplete="tel-national" required maxLength={10} placeholder="10-digit Indian mobile"/></label><div className="grid gap-3 sm:grid-cols-2"><label className="block"><span className="mb-1.5 block text-xs font-semibold">Password</span><input className={input} type="password" minLength={8} value={password} onChange={e=>setPassword(e.target.value)} autoComplete="new-password" required placeholder="At least 8 characters"/></label><label className="block"><span className="mb-1.5 block text-xs font-semibold">Confirm password</span><input className={input} type="password" minLength={8} value={confirm} onChange={e=>setConfirm(e.target.value)} autoComplete="new-password" required placeholder="Repeat password"/></label></div>{message&&<div role="status" className={`rounded-xl border p-3 text-xs leading-5 ${success?'border-emerald-200 bg-emerald-50 text-emerald-900':'border-amber-200 bg-amber-50 text-amber-900'}`}>{message}</div>}{recoveryCode&&<div className="rounded-xl border border-blue-200 bg-blue-50 p-4"><p className="text-xs font-bold text-blue-900">Owner recovery code — save it now</p><p className="mt-2 break-all font-mono text-lg font-bold tracking-wider text-blue-950">{recoveryCode}</p><p className="mt-2 text-xs leading-5 text-blue-800">This is shown only once. Store it privately. It is not your password.</p><button type="button" onClick={()=>navigator.clipboard.writeText(recoveryCode)} className="mt-2 rounded-lg border border-blue-200 bg-white px-3 py-2 text-xs font-semibold text-blue-800">Copy recovery code</button></div>}<button disabled={busy} className="flex w-full items-center justify-center gap-2 rounded-xl bg-blue-700 px-4 py-3.5 text-sm font-semibold text-white hover:bg-blue-800 disabled:opacity-60">{busy?'Submitting…':type==='owner'?'Submit shop application':'Request technician access'}<KeyRound size={15}/></button></form><p className="mt-5 flex items-start gap-2 text-xs leading-5 text-slate-500"><CheckCircle2 size={15} className="mt-0.5 shrink-0 text-blue-700"/> FoneZone never allows public users to register themselves as Platform Admin. Access is granted only after the required approvals.</p></section></div></main>;
}
