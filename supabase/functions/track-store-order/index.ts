import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const allowedOrigin = "https://mirnaselect-droid.github.io";
const corsHeaders = {
  "Access-Control-Allow-Origin": allowedOrigin,
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}
function digits(value: unknown) {
  return String(value ?? "").replace(/\D/g, "");
}
function getKeyFromJsonEnv(name: string) {
  const raw = Deno.env.get(name);
  if (!raw) return "";
  try {
    const parsed = JSON.parse(raw);
    return String(parsed.default || "");
  } catch {
    return "";
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const origin = req.headers.get("origin");
  if (origin && origin !== allowedOrigin) return json({ error: "Origin not allowed" }, 403);

  const publishableKey = getKeyFromJsonEnv("SUPABASE_PUBLISHABLE_KEYS") || Deno.env.get("SUPABASE_ANON_KEY") || "";
  if (!publishableKey || req.headers.get("apikey") !== publishableKey) {
    return json({ error: "Unauthorized" }, 401);
  }

  let body: { order_number?: unknown; phone?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "بيانات الطلب غير صحيحة." }, 400);
  }

  const orderNumber = String(body.order_number ?? "").trim().toUpperCase();
  const phone = digits(body.phone);
  if (!/^BL-[A-F0-9]{8}$/i.test(orderNumber) || phone.length < 6 || phone.length > 20) {
    return json({ error: "اكتبي رقم الطلب ورقم الهاتف المسجلين عند الطلب." }, 400);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || getKeyFromJsonEnv("SUPABASE_SECRET_KEYS");
  if (!supabaseUrl || !secretKey) return json({ error: "خدمة التتبع غير متاحة مؤقتًا." }, 500);

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin
    .from("orders")
    .select("order_number, customer_phone, status, created_at, updated_at")
    .eq("order_number", orderNumber)
    .maybeSingle();

  if (error) {
    console.error("Order tracking lookup failed", error.message);
    return json({ error: "تعذر البحث عن الطلب حاليًا. حاولي مرة أخرى." }, 500);
  }

  if (!data || digits(data.customer_phone) !== phone) {
    return json({ found: false, error: "ملقيناش طلب مطابق للبيانات دي. راجعي رقم الطلب ورقم الهاتف." }, 404);
  }

  const allowedStatuses = new Set(["new", "confirmed", "preparing", "ready", "out_for_delivery", "delivered", "cancelled"]);
  const status = allowedStatuses.has(String(data.status)) ? String(data.status) : "new";
  return json({
    found: true,
    order: {
      order_number: data.order_number,
      status,
      created_at: data.created_at,
      updated_at: data.updated_at,
    },
  });
});
