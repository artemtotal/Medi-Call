// app/api/health/route.ts
import { NextRequest } from 'next/server';

export async function GET(req: NextRequest) {
  return new Response('OK', { status: 200 });
}
