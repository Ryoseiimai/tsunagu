// つなぐ紹介リンク短縮Worker
// 長いbase64付きリンクを短いコードに変換してKVに保存し、/s/<code>で302リダイレクトする

const GITHUB_PAGES_BASE = "https://ryoseiimai.github.io/tsunagu/";
// 紛らわしい l, o, 0, 1 を除いた文字集合
const CODE_CHARS = "abcdefghijkmnpqrstuvwxyz23456789";
const CODE_LENGTH = 4;
const MAX_RETRY = 5;
// security-fix-20261010-tsunagu: 認証なし・無制限・無期限の書き込みを防ぐための上限。
// s/ref/byの文字数上限（2,000文字あれば想定データは十分収まる）と、保存の有効期限（90日）。
const MAX_FIELD_LENGTH = 2000;
const LINK_TTL_SECONDS = 60 * 60 * 24 * 90;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS_HEADERS },
  });
}

function generateCode() {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
  }
  return code;
}

function friendlyNotFoundPage() {
  return new Response(
    `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>リンクが見つかりません - つなぐ</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", sans-serif; background:#f7f7f9; color:#333; display:flex; align-items:center; justify-content:center; min-height:100vh; margin:0; padding:24px; box-sizing:border-box; }
  .card { background:#fff; border-radius:16px; padding:32px; max-width:420px; text-align:center; box-shadow:0 4px 20px rgba(0,0,0,0.08); }
  h1 { font-size:20px; margin-bottom:12px; }
  p { font-size:15px; line-height:1.6; color:#555; }
  a.btn { display:inline-block; margin-top:20px; padding:12px 24px; background:#2f7d5c; color:#fff; text-decoration:none; border-radius:999px; font-weight:bold; }
</style>
</head>
<body>
  <div class="card">
    <h1>このリンクは見つかりませんでした</h1>
    <p>リンクの有効期限が切れているか、URLが間違っている可能性があります。<br>「つなぐ」アプリのご紹介ページはこちらからご覧いただけます。</p>
    <a class="btn" href="${GITHUB_PAGES_BASE}">つなぐ を見る</a>
  </div>
</body>
</html>`,
    { status: 404, headers: { "content-type": "text/html; charset=utf-8" } }
  );
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    // HEADはリンクプレビュー・クローラが多用するため、GETと同じ経路を通してからボディだけ落とす
    const isHead = request.method === "HEAD";

    if (url.pathname === "/" && (request.method === "GET" || isHead)) {
      const res = Response.redirect(GITHUB_PAGES_BASE, 302);
      return isHead ? new Response(null, { status: res.status, headers: res.headers }) : res;
    }

    if (url.pathname === "/api/shorten" && request.method === "POST") {
      let payload;
      try {
        payload = await request.json();
      } catch (err) {
        return jsonResponse({ error: "invalid_json" }, 400);
      }

      const { s, ref, by } = payload || {};
      if (!s || typeof s !== "string") {
        return jsonResponse({ error: "missing_s" }, 400);
      }
      // security-fix-20261010-tsunagu: 無制限サイズの書き込みを拒否する
      if (s.length > MAX_FIELD_LENGTH) {
        return jsonResponse({ error: "s_too_long" }, 400);
      }
      if (ref !== undefined && ref !== null && (typeof ref !== "string" || ref.length > MAX_FIELD_LENGTH)) {
        return jsonResponse({ error: "ref_too_long" }, 400);
      }
      if (by !== undefined && by !== null && (typeof by !== "string" || by.length > MAX_FIELD_LENGTH)) {
        return jsonResponse({ error: "by_too_long" }, 400);
      }

      let code = null;
      for (let attempt = 0; attempt < MAX_RETRY; attempt++) {
        const candidate = generateCode();
        const existing = await env.TSUNAGU_LINKS.get(candidate);
        if (existing === null) {
          code = candidate;
          break;
        }
      }
      if (!code) {
        return jsonResponse({ error: "code_exhausted" }, 500);
      }

      const record = { s, ref: ref || "", by: by || "" };
      // security-fix-20261010-tsunagu: 永久保存をやめ、90日で自動的に消えるようにする
      await env.TSUNAGU_LINKS.put(code, JSON.stringify(record), { expirationTtl: LINK_TTL_SECONDS });

      return jsonResponse({ code, url: `https://tsunagu.densalon.com/s/${code}` });
    }

    const match = url.pathname.match(/^\/s\/([a-zA-Z0-9]+)$/);
    if (match && (request.method === "GET" || isHead)) {
      const code = match[1];
      const raw = await env.TSUNAGU_LINKS.get(code);
      if (!raw) {
        const res = friendlyNotFoundPage();
        return isHead ? new Response(null, { status: res.status, headers: res.headers }) : res;
      }
      let record;
      try {
        record = JSON.parse(raw);
      } catch (err) {
        const res = friendlyNotFoundPage();
        return isHead ? new Response(null, { status: res.status, headers: res.headers }) : res;
      }
      const dest = new URL(GITHUB_PAGES_BASE);
      dest.searchParams.set("s", record.s);
      if (record.ref) dest.searchParams.set("ref", record.ref);
      if (record.by) dest.searchParams.set("by", record.by);
      const res = Response.redirect(dest.toString(), 302);
      return isHead ? new Response(null, { status: res.status, headers: res.headers }) : res;
    }

    return jsonResponse({ error: "not_found" }, 404);
  },
};
