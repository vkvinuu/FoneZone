import { NextResponse } from 'next/server';

// Supabase email confirmation redirects here. The browser client exchanges the
// returned auth code on the destination page; this route safely forwards it.
export async function GET(request: Request) {
  const url = new URL(request.url);
  const next = url.searchParams.get('next');
  const safeNext = next && next.startsWith('/') && !next.startsWith('//') ? next : '/account';
  const destination = new URL(safeNext, url.origin);
  url.searchParams.forEach((value, key) => {
    if (key === 'code' || key === 'error' || key === 'error_description') destination.searchParams.set(key, value);
  });
  return NextResponse.redirect(destination);
}
