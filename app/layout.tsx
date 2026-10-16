import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'FoneZone | Repair Operations Platform', description: 'Multi-shop mobile repair management, inventory, customer approvals and verifiable repair records.' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body className="min-h-screen antialiased">{children}</body></html>; }
