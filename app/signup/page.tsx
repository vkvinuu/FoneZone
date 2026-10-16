'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft, Store, UserRound, CheckCircle2 } from 'lucide-react';
import { supabase, isSupabaseConfigured } from '../../lib/supabase/client';

type SignupType = 'shop' | 'customer';

export default function Signup() {
  const router = useRouter();
  const [type, setType] = useState<SignupType>('customer');
  const [name, setName] = useState('');
  const [shop, setShop] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [terms, setTerms] = useState(false);
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState<'error' | 'success'>('error');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const requestedType = new URLSearchParams(window.location.search).get('type');
    setType(requestedType === 'shop' ? 'shop' : 'customer');
  }, []);

  // Accept a 10-digit Indian mobile number, optionally entered with country code +91.
  // Keep only digits and limit the input to 10 local digits (or 12 digits including 91).
  function handlePhoneChange(rawValue: string) {
    const digits = rawValue.replace(/\D/g, '');
    let localDigits = digits;
    if (digits.startsWith('91') && digits.length > 10) localDigits = digits.slice(2);
    setPhone(localDigits.slice(0, 10));
    setMessage('');
  }

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setMessage('');
    setMessageType('error');
    if (!isSupabaseConfigured || !supabase) {
      setMessage('Supabase is not configured. Check NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY in .env.local, then restart the server.');
      return;
    }
    if (!name.trim()) return setMessage('Please enter your full name.');
    if (type === 'shop' && !shop.trim()) return setMessage('Please enter your shop name.');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) return setMessage('Please enter a valid email address.');
    if (!/^[6-9]\d{9}$/.test(phone)) return setMessage('Enter a valid 10-digit Indian mobile number starting with 6, 7, 8 or 9.');
    if (password.length < 8) return setMessage('Password must contain at least 8 characters.');
    if (password !== confirm) return setMessage('Passwords do not match. Please enter the same password in both fields.');
    if (!terms) return setMessage('Please confirm the details are accurate and accept the terms.');
    setSubmitting(true);
    try {
      const { data, error } = await supabase.auth.signUp({
        email: email.trim().toLowerCase(),
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
          data: { full_name: name.trim(), phone: `+91${phone}`, account_type: type, shop_name: type === 'shop' ? shop.trim() : null }
        }
      });
      if (error) throw error;
      setMessageType('success');
      setMessage(data.session
        ? (type === 'shop' ? 'Account created. Your shop application has been recorded if the database trigger is installed. Shop activation requires platform approval.' : 'Account created successfully. You can now sign in.')
        : 'Registration received. Check your email to confirm your account, then sign in. Shop activation requires platform approval.');
    } catch (err) {
      setMessage(err instanceof Error ? err.message : 'Registration failed. Please try again.');
    } finally {
      setSubmitting(false);
    }
  }

  const inputClass = 'w-full rounded-lg border border-slate-200 px-3 py-3 text-sm outline-none transition focus:border-slate-500 focus:ring-2 focus:ring-slate-100';

  return (
    <main className="min-h-screen bg-[#f4f6f9] px-4 py-10">
      <div className="mx-auto max-w-lg">
        <button type="button" onClick={() => router.push('/')} className="mb-6 flex items-center gap-2 text-sm text-slate-600 hover:text-slate-900">
          <ArrowLeft size={16} /> Back to login
        </button>
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <div className="mb-6 flex items-center gap-3">
            <div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-slate-100">
              {type === 'shop' ? <Store /> : <UserRound />}
            </div>
            <div>
              <h1 className="text-xl font-semibold">{type === 'shop' ? 'Register your repair shop' : 'Create customer account'}</h1>
              <p className="mt-1 text-xs text-slate-500">{type === 'shop' ? 'Shop approval is required before activation.' : 'Book and track your repairs.'}</p>
            </div>
          </div>

          <form onSubmit={submit} noValidate className="space-y-4">
            <label className="block">
              <span className="mb-1.5 block text-xs font-semibold">{type === 'shop' ? 'Owner full name' : 'Full name'}</span>
              <input required autoComplete="name" value={name} onChange={e => { setName(e.target.value); setMessage(''); }} className={inputClass} />
            </label>

            {type === 'shop' && (
              <label className="block">
                <span className="mb-1.5 block text-xs font-semibold">Shop name</span>
                <input required autoComplete="organization" value={shop} onChange={e => { setShop(e.target.value); setMessage(''); }} className={inputClass} />
              </label>
            )}

            <label className="block">
              <span className="mb-1.5 block text-xs font-semibold">Email address</span>
              <input required type="email" autoComplete="email" value={email} onChange={e => { setEmail(e.target.value); setMessage(''); }} className={inputClass} />
            </label>

            <label className="block">
              <span className="mb-1.5 block text-xs font-semibold">Mobile number</span>
              <div className="flex rounded-lg border border-slate-200 focus-within:border-slate-500 focus-within:ring-2 focus-within:ring-slate-100">
                <span className="flex items-center border-r border-slate-200 px-3 text-sm text-slate-500">+91</span>
                <input
                  required
                  type="tel"
                  inputMode="numeric"
                  autoComplete="tel-national"
                  aria-describedby="mobile-help"
                  value={phone}
                  onChange={e => handlePhoneChange(e.target.value)}
                  onPaste={e => { e.preventDefault(); handlePhoneChange(e.clipboardData.getData('text')); }}
                  maxLength={10}
                  pattern="[6-9][0-9]{9}"
                  placeholder="10-digit mobile number"
                  className="min-w-0 flex-1 rounded-r-lg px-3 py-3 text-sm outline-none"
                />
              </div>
              <span id="mobile-help" className="mt-1 block text-[11px] text-slate-500">Enter 10 digits, starting with 6–9. Country code +91 is shown separately.</span>
            </label>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <label className="block min-w-0">
                <span className="mb-1.5 block text-xs font-semibold">Password</span>
                <input required autoComplete="new-password" minLength={8} type="password" value={password} onChange={e => { setPassword(e.target.value); setMessage(''); }} className={inputClass} />
              </label>
              <label className="block min-w-0">
                <span className="mb-1.5 block text-xs font-semibold">Confirm password</span>
                <input required autoComplete="new-password" minLength={8} type="password" value={confirm} onChange={e => { setConfirm(e.target.value); setMessage(''); }} className={inputClass} />
              </label>
            </div>

            <label className="flex items-start gap-2 text-xs leading-5 text-slate-600">
              <input type="checkbox" checked={terms} onChange={e => { setTerms(e.target.checked); setMessage(''); }} className="mt-1" />
              <span>I confirm the details are accurate and agree to the privacy and account terms.</span>
            </label>

            {message && (
              <div role="status" aria-live="polite" className={`rounded-lg border p-3 text-xs leading-5 ${messageType === 'success' ? 'border-emerald-200 bg-emerald-50 text-emerald-900' : 'border-rose-200 bg-rose-50 text-rose-900'}`}>
                {message}
              </div>
            )}

            <button type="submit" disabled={submitting} className="w-full rounded-lg bg-[#14263d] px-4 py-3 text-sm font-semibold text-white transition hover:bg-[#203954] disabled:cursor-wait disabled:opacity-60 focus:outline-none focus:ring-2 focus:ring-slate-400 focus:ring-offset-2">
              {submitting ? 'Creating account…' : type === 'shop' ? 'Submit shop application' : 'Create account'}
            </button>
          </form>

          <p className="mt-4 flex items-start gap-2 text-[11px] leading-5 text-slate-500">
            <CheckCircle2 size={14} className="mt-0.5 shrink-0" />
            Your account is protected by Supabase Authentication. Email confirmation may be required before sign-in.
          </p>
        </div>
      </div>
    </main>
  );
}
