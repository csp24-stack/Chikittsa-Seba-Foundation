/* Chikittsa Seba Foundation: shared script for the form pages */
(function () {
  // ---- Supabase connection (same project as index.html). Use the publishable key only, never a secret key. ----
  var SUPABASE_URL = "https://uvhtootgcdhjkhihxbwx.supabase.co";
  var SUPABASE_KEY = "sb_publishable_PZBSj4gMgg4gda3DFF_90w_v4uzpEpT";

  var lang = "bn";
  try { lang = localStorage.getItem("lang") || "bn"; } catch (e) {}

  // plain-object headers and no AbortSignal: works in sandboxed previews too
  function safeFetch(url, opts) {
    var o = Object.assign({}, opts || {}); delete o.signal;
    if (o.headers && typeof o.headers.forEach === "function" && !Array.isArray(o.headers)) { var h = {}; o.headers.forEach(function (v, k) { h[k] = v; }); o.headers = h; }
    return fetch(url, o);
  }
  var db = null;
  try { if (window.supabase) db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, { global: { fetch: safeFetch } }); } catch (e) { console.error(e); }

  function applyLang() {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-en]").forEach(function (e) { e.textContent = e.dataset[lang]; });
    var b = document.getElementById("lang"); if (b) b.textContent = lang === "bn" ? "English" : "বাংলা";
  }
  var lb = document.getElementById("lang");
  if (lb) lb.onclick = function () { lang = lang === "bn" ? "en" : "bn"; try { localStorage.setItem("lang", lang); } catch (e) {} applyLang(); };
  applyLang();

  // ---- header dropdown ----
  var dd = document.getElementById("dd"), ddb = document.getElementById("ddb");
  if (dd && ddb) {
    ddb.onclick = function (e) { e.stopPropagation(); var o = dd.classList.toggle("open"); ddb.setAttribute("aria-expanded", o); };
    document.addEventListener("click", function (e) { if (!dd.contains(e.target)) { dd.classList.remove("open"); ddb.setAttribute("aria-expanded", "false"); } });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") { dd.classList.remove("open"); ddb.setAttribute("aria-expanded", "false"); } });
  }

  // ---- site settings: emergency banner, WhatsApp, contact details ----
  if (db) {
    db.from("site_settings").select("key,value").then(function (r) {
      var data = r && r.data; if (!data) return;
      var s = {}; data.forEach(function (x) { s[x.key] = x.value; });
      if (s.banner) { var b = document.getElementById("banner"); b.textContent = s.banner; b.style.display = "block"; }
      if (s.whatsapp) { var w = document.getElementById("wa"); w.href = "https://wa.me/" + s.whatsapp.replace(/\D/g, ""); w.style.display = "block"; }
      var set = function (id, v) { var e = document.getElementById(id); if (e && v) e.textContent = v; };
      set("ci-email", s.email); set("ci-phone", s.phone); set("ci-address", s.address);
      [["fb", s.facebook], ["yt", s.youtube]].forEach(function (p) { if (p[1] && /^https?:\/\//.test(p[1])) { var a = document.getElementById("ci-" + p[0]); if (a) { a.href = p[1]; document.getElementById("ci-" + p[0] + "-li").hidden = false; } } });
    }, function () {});
  }

  // ---- copy payment number (donation page) ----
  var cp = document.getElementById("paycp");
  if (cp) cp.onclick = function () {
    var n = "01850692597", btn = this, done = function (ok) { btn.textContent = ok ? (lang === "bn" ? "কপি হয়েছে" : "Copied") : n; setTimeout(applyLang, 1800); };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(n).then(function () { done(true); }, function () { done(false); }); else done(false);
  };

  // ---- form submit: validation, honeypot, insert into the table named in data-table ----
  function submitForm(form) {
    var box = form.querySelector(".msg"), btn = form.querySelector("button[type=submit]");
    function say(t, c) { box.className = "msg " + c; box.textContent = t; }
    if (btn.disabled) return;
    if (!form.reportValidity()) return;
    if (form.elements.hp_check && form.elements.hp_check.value) return; // honeypot: bots fill this
    if (!db) return say(lang === "bn" ? "Supabase এর সাথে সংযোগ হয়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।" : "Could not connect to Supabase. Check your connection and try again.", "err");
    var row = {};
    new FormData(form).forEach(function (v, k) { if (k !== "hp_check" && v !== "") row[k] = v; });
    form.querySelectorAll("input[type=checkbox]").forEach(function (c) { row[c.name] = c.checked; });
    ["amount", "age", "expected_participants"].forEach(function (k) { if (row[k]) row[k] = Number(row[k]); });
    btn.disabled = true; say(lang === "bn" ? "পাঠানো হচ্ছে..." : "Sending...", "ok");
    var timer, timeout = new Promise(function (_, rej) { timer = setTimeout(function () { rej(new Error("timeout")); }, 15000); });
    Promise.race([db.from(form.dataset.table).insert(row), timeout]).then(function (r) { return r; }, function (e) { return { error: e }; }).then(function (r) {
      clearTimeout(timer); btn.disabled = false;
      if (r && r.error) return say((lang === "bn" ? "জমা হয়নি: " : "Could not submit: ") + (r.error.message || "network error / timeout"), "err");
      form.reset(); say(lang === "bn" ? form.dataset.okBn : form.dataset.ok, "ok");
      box.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
  }
  document.querySelectorAll("form[data-table]").forEach(function (form) {
    form.addEventListener("submit", function (ev) { ev.preventDefault(); submitForm(form); });
  });
})();
