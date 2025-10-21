//+------------------------------------------------------------------+
//| DataCollectorRebuild - Minimal MT5 Data Ingestion EA             |
//| Fresh implementation based on docs in /docs/api (no decompiling) |
//+------------------------------------------------------------------+
#property copyright "(c) 2025"
#property version   "1.00"
#property strict

// ---------------------- Inputs ----------------------
input group "=== API ===";
// EDGE RELAY: Envie para localhost (baixa latência) e o relay encaminha ao servidor remoto com fila
input string API_URL   = "http://127.0.0.1:18001/ingest"; // Base ingest endpoint (use localhost com edge-relay)
input string API_KEY   = "mt5_trading_secure_key_2025_prod";  // X-API-Key value (não verificado pelo relay local)
input int    API_TimeoutMs = 5000;                              // Request timeout
input bool   API_LogDebug  = true;                              // Log headers/body snippets
input bool   API_LogVerbose = true;                              // Extra details: body and headers fully

input group "=== COLLECTION ===";
input ENUM_TIMEFRAMES COLLECTION_TF = PERIOD_M1;                // Timeframe to collect
input int    COLLECTION_INTERVAL_S  = 60;                       // Seconds between scans
input bool   USE_MARKET_WATCH       = true;                     // Collect for all symbols in Market Watch
input bool   ONLY_LAST_CLOSED_BAR   = true;                     // Send last closed bar (recommended)
input bool   SEND_BATCH             = true;                     // Batch multiple items into one POST

input group "=== TICK STREAM ===";
enum ENUM_TICK_MODE { TICK_PER_TICK=0, TICK_BATCHED=1 };
input bool   ENABLE_TICK_STREAM     = true;                     // Enable tick streaming for chart symbol
input ENUM_TICK_MODE TICK_MODE      = TICK_BATCHED;             // Immediate or batched
input int    TICK_FLUSH_INTERVAL_MS = 1000;                     // Flush buffer every X ms (if not empty)
input int    TICK_BATCH_MAX         = 200;                      // Max ticks per batch payload
input int    TICK_MAX_RPS           = 20;                       // Limit direct sends per second (per-tick mode)
input string API_TICK_URL           = "http://127.0.0.1:18001/ingest/tick"; // Tick endpoint (use localhost)
input bool   TICK_ALL_SYMBOLS       = true;                     // Stream ticks from all Market Watch symbols
input int    TICK_POLL_INTERVAL_MS  = 200;                      // Poll interval for multi-symbol tick capture
input int    TICK_MAX_BUFFER        = 5000;                     // Max ticks to buffer while offline
input int    TICK_AUTO_PAUSE_FAILS  = 15;                       // Auto-pause after N consecutive flush failures

input group "=== IDENTIFICATION ===";
input bool   UA_AutoGenerate  = true;                           // Generate rich User-Agent automatically
input string UA_Custom        = "PDC-Rebuild/1.0";             // Used when UA_AutoGenerate=false

input group "=== AUTH/HEADERS ===";
input bool   API_Use_Bearer        = false;                     // If true, send Authorization: Bearer <token>
input string API_Bearer_Token      = "";                        // Bearer token value
input string API_Extra_Header1     = "";                        // e.g. "X-Env: prod"
input string API_Extra_Header2     = "";                        // e.g. "X-Trace: abc123"

input group "=== FALLBACK / SPLIT ===";
input bool   Fallback_To_File      = true;                      // Save failed payload to JSONL
input bool   Split_On_413_414      = true;                      // Split batch on payload too large

input group "=== METRICS ===";
input bool   METRICS_ENABLE        = true;                      // Enable periodic metrics print
input int    METRICS_EVERY_EVENTS  = 20;                        // Print metrics every N send events
input int    METRICS_SUMMARY_INTERVAL_S = 60;                   // Time-based summary interval (seconds)

// ---------------------- Globals ----------------------
string  G_Symbols[];                 // Symbols we will collect
datetime G_LastBarTime[];            // Per-symbol last seen bar open time
ulong   G_LastTickMS[];              // Per-symbol last seen tick time_msc
string  G_TickBuffer[];              // Tick buffer for batched sending
uint    G_TickLastFlushMs = 0;       // Last flush timestamp
int     G_TickConsecFails = 0;       // Consecutive tick flush failures
bool    G_TickPaused      = false;   // Auto-pause tick streaming when failures persist
uint    G_ReqCounter      = 0;       // Incremental request id for logs
int     G_ContextItemsCount = 0;     // Contextual number of items in current send
// Metrics counters: ingest_ok counts items; ingest_fail counts failed requests
int     G_IngestOk = 0;
int     G_IngestFail = 0;
// Tick metrics: tick_ok counts ticks delivered; tick_fail counts failed send/flush events
int     G_TickOk = 0;
int     G_TickFail = 0;
int     G_MetricsEvents = 0;         // Total send events considered for periodic printing
// Queue counters
int     G_QueuedIngest = 0;          // Number of ingest posts that were queued by relay
int     G_QueuedTick   = 0;          // Number of tick posts that were queued by relay
// Per-period (summary-window) counters
int     G_PeriodIngestOk = 0;
int     G_PeriodQueuedIngest = 0;
int     G_PeriodTickOk = 0;
int     G_PeriodQueuedTick = 0;
datetime G_LastSummaryTs = 0;
// Split counters
int     G_SplitEvents = 0;
int     G_PeriodSplitEvents = 0;

// ---------------------- Helpers (decl) ----------------------
string TFToString(ENUM_TIMEFRAMES tf);
string ISO8601(datetime t);
bool   BuildCandleItem(const string sym, ENUM_TIMEFRAMES tf, string &out_json_item, string &out_ts, bool &out_has_item);
bool   SendBatchJSON(const string body, int &out_code, string &out_resp, string &out_resp_headers);
bool   SendJSONToURL(const string body, const string url, int &out_code, string &out_resp, string &out_resp_headers);
string BuildUserAgent();
int    LoadSymbols(string &out_syms[]);
int    ParseHttpCode(const string &hdrs);
bool   AppendUTF8LineCommon(const string fname, const string line);
void   WriteFallbackJSONL(const string body);
bool   SendItemsOrSplit(string &items[], int start, int end, int &out_code, string &out_resp, string &out_hdrs);
string BuildTickItemJSON(const string sym, const MqlTick &tick);
bool   TickBufferAppend(const string item);
bool   TickBufferFlush(const string reason);
void   PollTicksAllSymbols();
string UrlPath(const string url);
string ErrorHint(const int last_err, const int http_code);
bool   JsonFindInt(const string json, const string key, int &out_val);
string BuildHeaders(const uint req_id=0);
void   PrintMetrics();
void   MaybePrintTimeSummary(const datetime now);

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("DataCollectorRebuild - START");
   PrintFormat("API: %s | TF: %s | Interval(s): %d", API_URL, TFToString(COLLECTION_TF), COLLECTION_INTERVAL_S);
   int tbuild = (int)TerminalInfoInteger(TERMINAL_BUILD);
   bool tconn = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   PrintFormat("Terminal: build=%d connected=%s", tbuild, tconn?"yes":"no");
   Print("Obs: Adicione a URL em Tools > Options > Expert Advisors > Allow WebRequest");
   Print("========================================");

   int n = LoadSymbols(G_Symbols);
   ArrayResize(G_LastBarTime, n);
   for(int i=0;i<n;i++) G_LastBarTime[i]=0;
   PrintFormat("Symbols to collect: %d", n);

   // Initialize last tick times to current to avoid historical backlog
   ArrayResize(G_LastTickMS, n);
   for(int i=0;i<n;i++){
      MqlTick t; if(SymbolInfoTick(G_Symbols[i], t)) G_LastTickMS[i] = (ulong)t.time_msc; else G_LastTickMS[i]=0;
   }

   // Timer strategy: if multi-symbol ticks enabled, use millisecond timer and schedule candles inside OnTimer
   if(ENABLE_TICK_STREAM && TICK_ALL_SYMBOLS){
      int poll = MathMax(20, MathMin(5000, TICK_POLL_INTERVAL_MS));
      EventSetMillisecondTimer(poll);
      PrintFormat("Using millisecond timer = %d ms for tick polling", poll);
   } else {
      if(COLLECTION_INTERVAL_S < 1) {
         Print("Interval too small; forcing to 1s");
         EventSetTimer(1);
      } else {
         EventSetTimer(COLLECTION_INTERVAL_S);
      }
   }
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   // Emergency flush of pending ticks
   if(ArraySize(G_TickBuffer)>0) TickBufferFlush("deinit");
}

//+------------------------------------------------------------------+
//| Timer: collect candles and send                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 1) Multi-symbol tick polling (if enabled)
   if(ENABLE_TICK_STREAM && TICK_ALL_SYMBOLS && !G_TickPaused){
      PollTicksAllSymbols();
      // Flush by interval/size
      uint nowMs = GetTickCount();
      if(ArraySize(G_TickBuffer) >= TICK_BATCH_MAX) TickBufferFlush("max");
      else if(nowMs - G_TickLastFlushMs >= (uint)MathMax(0, TICK_FLUSH_INTERVAL_MS)) TickBufferFlush("interval");
   }

   // 2) Candle collection scheduling
   static datetime lastCandleRun = 0;
   datetime now = TimeCurrent();
   if(lastCandleRun==0 || (now - lastCandleRun) >= MathMax(1, COLLECTION_INTERVAL_S)){
      lastCandleRun = now;
      
      int n = ArraySize(G_Symbols);
      if(n<=0) return;

      string items[];
      int items_count = 0;
      ENUM_TIMEFRAMES tf=(COLLECTION_TF==PERIOD_CURRENT ? (ENUM_TIMEFRAMES)_Period : COLLECTION_TF);

      for(int i=0;i<n;i++){
         string sym = G_Symbols[i];
         if(sym=="") continue;

         // Detect close of previous bar by comparing bar[0] time
         datetime cur_bar_time = iTime(sym, tf, 0);
         if(cur_bar_time==0) continue;
         bool have_prev_closed = (G_LastBarTime[i]!=0 && cur_bar_time!=G_LastBarTime[i]) || !ONLY_LAST_CLOSED_BAR;
         G_LastBarTime[i] = cur_bar_time;

         if(!have_prev_closed && ONLY_LAST_CLOSED_BAR) continue;

         string item, ts;
         bool has_item=false;
         if(BuildCandleItem(sym, tf, item, ts, has_item) && has_item){
            int k = ArraySize(items);
            ArrayResize(items, k+1);
            items[k] = item;
         }
         // small pacing to avoid spike of requests
         Sleep(10);
      }

      items_count = ArraySize(items);
      if(items_count<=0) return;

      int code=0; string resp="", hdrs="";
      bool ok=false;
      if(SEND_BATCH){
         G_ContextItemsCount = items_count;
         ok = SendItemsOrSplit(items, 0, items_count, code, resp, hdrs);
      } else {
         string body = items[0];
         G_ContextItemsCount = 1;
         ok = SendBatchJSON(body, code, resp, hdrs);
         if(!ok && Fallback_To_File) WriteFallbackJSONL(body);
      }
      // Try to detect relay 'queued' signal from response for better visibility
      bool queued = (StringFind(resp, "\"queued\":true")>=0);
      if(ok){
         PrintFormat("[INGEST] ok code=%d items=%d queued=%s", code, items_count, queued?"true":"false");
         G_IngestOk += items_count;
         G_PeriodIngestOk += items_count;
         if(queued){ G_QueuedIngest++; G_PeriodQueuedIngest++; }
      } else {
         PrintFormat("[INGEST] fail code=%d items=%d", code, items_count);
         G_IngestFail++;
      }
      if(METRICS_ENABLE){ G_MetricsEvents++; if(METRICS_EVERY_EVENTS>0 && (G_MetricsEvents % METRICS_EVERY_EVENTS)==0) PrintMetrics(); }
      MaybePrintTimeSummary(TimeCurrent());
   } // Close the if(lastCandleRun...) block
}

//+------------------------------------------------------------------+
//| Tick events: stream ticks from chart symbol                      |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!ENABLE_TICK_STREAM || TICK_ALL_SYMBOLS || G_TickPaused) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   string item = BuildTickItemJSON(_Symbol, t);

   // Per-tick immediate mode with simple RPS limiting
   if(TICK_MODE==TICK_PER_TICK){
      static uint rps_window_start = 0; static int rps_count = 0;
      uint nowMs = GetTickCount();
      if(nowMs < rps_window_start || nowMs - rps_window_start >= 1000){ rps_window_start = nowMs; rps_count = 0; }

      bool sent_now = false;
      if(TICK_MAX_RPS<=0 || rps_count < TICK_MAX_RPS){
         string body = StringFormat("{\"ticks\":[%s]}", item);
         int code=0; string resp="", hdrs="";
         G_ContextItemsCount = 1;
         bool ok = SendJSONToURL(body, API_TICK_URL, code, resp, hdrs);
         if(ok){
            sent_now = true; rps_count++;
            G_TickOk += 1;
            bool q = (StringFind(resp, "\"queued\":true")>=0);
            if(q){ G_QueuedTick++; G_PeriodQueuedTick++; }
            G_PeriodTickOk += 1;
            if(METRICS_ENABLE){ G_MetricsEvents++; if(METRICS_EVERY_EVENTS>0 && (G_MetricsEvents % METRICS_EVERY_EVENTS)==0) PrintMetrics(); }
            MaybePrintTimeSummary(TimeCurrent());
         } else {
            // immediate send failed -> fall back to buffer; count as a failed tick event
            G_TickFail++;
            if(METRICS_ENABLE){ G_MetricsEvents++; if(METRICS_EVERY_EVENTS>0 && (G_MetricsEvents % METRICS_EVERY_EVENTS)==0) PrintMetrics(); }
            MaybePrintTimeSummary(TimeCurrent());
         }
      }
      if(!sent_now){
         TickBufferAppend(item);
         // Try flush by size or interval
         uint now2 = GetTickCount();
         if(ArraySize(G_TickBuffer) >= TICK_BATCH_MAX) TickBufferFlush("max");
         else if(now2 - G_TickLastFlushMs >= (uint)MathMax(0, TICK_FLUSH_INTERVAL_MS)) TickBufferFlush("interval");
      }
      return;
   }

   // Batched mode: accumulate and flush by policy
   TickBufferAppend(item);
   uint nowMs2 = GetTickCount();
   if(ArraySize(G_TickBuffer) >= TICK_BATCH_MAX) TickBufferFlush("max");
   else if(nowMs2 - G_TickLastFlushMs >= (uint)MathMax(0, TICK_FLUSH_INTERVAL_MS)) TickBufferFlush("interval");
}

//+------------------------------------------------------------------+
//| Poll ticks for all Market Watch symbols                         |
//+------------------------------------------------------------------+
void PollTicksAllSymbols()
{
   int n = ArraySize(G_Symbols);
   if(n<=0) return;

   for(int i=0;i<n;i++){
     string sym = G_Symbols[i];
     if(sym=="") continue;

     MqlTick ticks[];
     ulong from_msc = (i<ArraySize(G_LastTickMS) && G_LastTickMS[i]>0) ? (G_LastTickMS[i]+1) : 0;
     int copied = CopyTicksRange(sym, ticks, COPY_TICKS_ALL, from_msc, 0);
     if(copied<=0) continue;

     ulong last = (i<ArraySize(G_LastTickMS)) ? G_LastTickMS[i] : 0;
     for(int k=0;k<copied;k++){
        if((ulong)ticks[k].time_msc > last){
           string item = BuildTickItemJSON(sym, ticks[k]);
           TickBufferAppend(item);
           last = (ulong)ticks[k].time_msc;
        }
     }
     G_LastTickMS[i] = last;
   }
}

//+------------------------------------------------------------------+
//| Build one candle item JSON                                       |
//+------------------------------------------------------------------+
bool BuildCandleItem(const string sym, ENUM_TIMEFRAMES tf, string &out_json_item, string &out_ts, bool &out_has_item)
{
   out_has_item=false;
   MqlRates rates[];
   int need = ONLY_LAST_CLOSED_BAR ? 2 : 1;
   int nr = CopyRates(sym, tf, 0, need, rates);
   if(nr<=0){ if(API_LogDebug) Print("CopyRates failed for ", sym, " tf=", (int)tf, " nr=", nr); return false; }

   int idx = ONLY_LAST_CLOSED_BAR ? 1 : 0; // [1] previous closed, else [0]
   if(idx>=nr) return false;

   int  dg  = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   long vol = (long)rates[idx].tick_volume;

   string ts_iso = ISO8601(rates[idx].time);
   string tf_str = TFToString(tf);

   // Build JSON object: keep numeric fields unquoted
   out_json_item = StringFormat(
      "{\"ts\":\"%s\",\"symbol\":\"%s\",\"timeframe\":\"%s\",\"open\":%s,\"high\":%s,\"low\":%s,\"close\":%s,\"volume\":%d}",
      ts_iso,
      sym,
      tf_str,
      DoubleToString(rates[idx].open,  dg),
      DoubleToString(rates[idx].high,  dg),
      DoubleToString(rates[idx].low,   dg),
      DoubleToString(rates[idx].close, dg),
      (int)vol
   );

   out_ts = ts_iso;
   out_has_item=true;
   return true;
}

//+------------------------------------------------------------------+
//| Send JSON to API                                                 |
//+------------------------------------------------------------------+
bool SendBatchJSON(const string body, int &out_code, string &out_resp, string &out_resp_headers)
{
   char post[];
   int n = StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(n>0) ArrayResize(post, n-1); // remove null terminator

   char result[];
   ResetLastError();
   uint req_id = (++G_ReqCounter);
   string headers = BuildHeaders(req_id);
   uint t0 = GetTickCount();
   int sz = WebRequest("POST", API_URL, headers, API_TimeoutMs, post, result, out_resp_headers);
   uint dt = GetTickCount() - t0;
   int httpCode = ParseHttpCode(out_resp_headers);
   // Fallback: some servers (e.g., uvicorn) may not expose status in headers string returned to MQL5
   // If we received a body (sz>=0) but couldn't parse the status (httpCode==0), assume success (200)
   if(httpCode==0 && sz>=0) httpCode = 200;
   out_code = httpCode;

   int last_err = GetLastError();
   if(API_LogDebug){
      // Limit body debug to 512 chars to avoid flooding
      string r = CharArrayToString(result, 0, (int)ArraySize(result), CP_UTF8);
      if(StringLen(r) > 512 && !API_LogVerbose) r = StringSubstr(r, 0, 512) + "...";
      string h = out_resp_headers; if(StringLen(h) > 512) h = StringSubstr(h, 0, 512) + "...";
      string hint = ErrorHint(last_err, httpCode);
      int payloadB = (int)ArraySize(post);
      string path = UrlPath(API_URL);
      bool queued = (StringFind(r, "\"queued\":true")>=0);
      int ins=-1, dup=-1, tot=-1;
      if(JsonFindInt(r, "inserted", ins) || JsonFindInt(r, "duplicates", dup) || JsonFindInt(r, "total", tot)){
         PrintFormat("[HTTP#%u ingest] server-stats inserted=%d duplicates=%d total=%d", req_id, ins, dup, tot);
      }
      PrintFormat("[HTTP#%u ingest] code=%d sz=%d err=%d hint=%s ms=%u url=%s payload=%dB items=%d queued=%s", req_id, httpCode, sz, last_err, hint, dt, path, payloadB, (int)G_ContextItemsCount, queued?"true":"false");
      if(API_LogVerbose){
         PrintFormat("[HTTP#%u ingest] body=%s", req_id, r);
         PrintFormat("[HTTP#%u ingest] headers=%s", req_id, h);
      }
      out_resp = r;
   }

   return (httpCode>=200 && httpCode<300);
}

// Generic sender for an arbitrary URL (used by tick endpoint)
bool SendJSONToURL(const string body, const string url, int &out_code, string &out_resp, string &out_resp_headers)
{
   char post[]; int n = StringToCharArray(body, post, 0, WHOLE_ARRAY, CP_UTF8);
   if(n>0) ArrayResize(post, n-1);
   char result[]; ResetLastError();
   uint req_id = (++G_ReqCounter);
   string headers = BuildHeaders(req_id);
   uint t0 = GetTickCount();
   int sz = WebRequest("POST", url, headers, API_TimeoutMs, post, result, out_resp_headers);
   uint dt = GetTickCount() - t0;
   int httpCode = ParseHttpCode(out_resp_headers);
   // Fallback for missing HTTP status in headers: assume 200 when body is present
   if(httpCode==0 && sz>=0) httpCode = 200;
   out_code = httpCode;

   if(API_LogDebug){
      string r = CharArrayToString(result, 0, (int)ArraySize(result), CP_UTF8);
      if(StringLen(r) > 512 && !API_LogVerbose) r = StringSubstr(r, 0, 512) + "...";
      string h = out_resp_headers; if(StringLen(h) > 512) h = StringSubstr(h, 0, 512) + "...";
      int last_err = GetLastError();
      string hint = ErrorHint(last_err, httpCode);
      int payloadB = (int)ArraySize(post);
      string path = UrlPath(url);
      bool queued = (StringFind(r, "\"queued\":true")>=0);
      int ins=-1, dup=-1, tot=-1;
      if(JsonFindInt(r, "inserted", ins) || JsonFindInt(r, "duplicates", dup) || JsonFindInt(r, "total", tot)){
         PrintFormat("[HTTP#%u tick] server-stats inserted=%d duplicates=%d total=%d", req_id, ins, dup, tot);
      }
      PrintFormat("[HTTP#%u tick] code=%d sz=%d err=%d hint=%s ms=%u url=%s payload=%dB items=%d queued=%s", req_id, httpCode, sz, last_err, hint, dt, path, payloadB, (int)G_ContextItemsCount, queued?"true":"false");
      if(API_LogVerbose){
         PrintFormat("[HTTP#%u tick] body=%s", req_id, r);
         PrintFormat("[HTTP#%u tick] headers=%s", req_id, h);
      }
      out_resp = r;
   }
   if(!(httpCode>=200 && httpCode<300) && Fallback_To_File) WriteFallbackJSONL(body);
   return (httpCode>=200 && httpCode<300);
}

//+------------------------------------------------------------------+
//| Build HTTP headers                                               |
//+------------------------------------------------------------------+
string BuildHeaders(const uint req_id)
{
   string hdr = "Content-Type: application/json\r\n";
   hdr += "Accept: application/json\r\n";
   hdr += "Connection: keep-alive\r\n";
   // Diagnostics
   if(req_id>0) hdr += "X-Client-ReqId: " + IntegerToString((int)req_id) + "\r\n";
   hdr += "X-Client-Items: " + IntegerToString((int)G_ContextItemsCount) + "\r\n";
   string tiso = ISO8601(TimeCurrent());
   hdr += "X-Client-Time: " + tiso + "\r\n";
   hdr += "X-Client-Build: " + IntegerToString((int)TerminalInfoInteger(TERMINAL_BUILD)) + "\r\n";

   // Auth
   if(API_Use_Bearer && StringLen(API_Bearer_Token)>0)
      hdr += "Authorization: Bearer " + API_Bearer_Token + "\r\n";
   else if(StringLen(API_KEY)>0)
      hdr += "X-API-Key: " + API_KEY + "\r\n";

   // User-Agent
   string ua = UA_AutoGenerate ? BuildUserAgent() : UA_Custom;
   hdr += "User-Agent: " + ua + "\r\n";
   if(StringLen(API_Extra_Header1)>0) hdr += API_Extra_Header1 + "\r\n";
   if(StringLen(API_Extra_Header2)>0) hdr += API_Extra_Header2 + "\r\n";
   return hdr;
}

//+------------------------------------------------------------------+
//| Generate detailed User-Agent                                     |
//+------------------------------------------------------------------+
string BuildUserAgent()
{
   long  account = AccountInfoInteger(ACCOUNT_LOGIN);
   string server  = AccountInfoString(ACCOUNT_SERVER);
   int   build    = (int)TerminalInfoInteger(TERMINAL_BUILD);
   int   syms     = ArraySize(G_Symbols);
   return StringFormat("PDC-Rebuild/1.0 (Account:%I64d; Server:%s; Build:%d; Symbols:%d)", account, server, build, syms);
}

//+------------------------------------------------------------------+
//| Load symbols to collect                                          |
//+------------------------------------------------------------------+
int LoadSymbols(string &out_syms[])
{
   ArrayResize(out_syms,0);
   if(USE_MARKET_WATCH){
      int total = SymbolsTotal(true);
      for(int i=0;i<total;i++){
         string s = SymbolName(i, true);
         if(s=="") continue;
         // Optionally filter to Forex-like (base/profit present and different)
         string base="", profit="";
         bool okb = SymbolInfoString(s, SYMBOL_CURRENCY_BASE, base);
         bool okp = SymbolInfoString(s, SYMBOL_CURRENCY_PROFIT, profit);
         if(okb && okp && base!="" && profit!="" && base!=profit){
            int k = ArraySize(out_syms);
            ArrayResize(out_syms, k+1);
            out_syms[k]=s;
         }
      }
      if(ArraySize(out_syms)==0){
         // Fallback to chart symbol
         int k=ArraySize(out_syms); ArrayResize(out_syms, k+1); out_syms[k]=_Symbol;
      }
   } else {
      int k=ArraySize(out_syms); ArrayResize(out_syms, k+1); out_syms[k]=_Symbol;
   }
   return ArraySize(out_syms);
}

//+------------------------------------------------------------------+
//| Timeframe to string                                              |
//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf)
{
   switch(tf){
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return IntegerToString((int)tf);
   }
}

//+------------------------------------------------------------------+
//| ISO8601 UTC string (YYYY-MM-DDTHH:MM:SSZ)                        |
//+------------------------------------------------------------------+
string ISO8601(datetime t)
{
   string s = TimeToString(t, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   StringReplace(s, ".", "-");
   StringReplace(s, " ", "T");
   return s + "Z";
}

//+------------------------------------------------------------------+
//| Build tick item JSON                                             |
//+------------------------------------------------------------------+
string BuildTickItemJSON(const string sym, const MqlTick &tick)
{
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double spread = tick.ask - tick.bid;
   string ts_iso = ISO8601((datetime)tick.time);
   string meta = "{\"ea\":\"PDC-Rebuild\",\"ver\":\"1.00\",\"src\":\"tick\"}";
   
   string s = "{";
   s += "\"ts\":\"" + ts_iso + "\",";
   s += "\"symbol\":\"" + sym + "\",";
   s += "\"bid\":" + DoubleToString(tick.bid, dg) + ",";
   s += "\"ask\":" + DoubleToString(tick.ask, dg) + ",";
   s += "\"last\":" + DoubleToString(tick.last, dg) + ",";
   s += "\"volume\":" + IntegerToString((int)tick.volume) + ",";
   s += "\"flags\":" + IntegerToString((int)tick.flags) + ",";
   s += "\"digits\":" + IntegerToString(dg) + ",";
   s += "\"spread\":" + DoubleToString(spread, dg) + ",";
   s += "\"meta\":" + meta;
   s += "}";
   return s;
}

//+------------------------------------------------------------------+
//| Tick buffer functions                                            |
//+------------------------------------------------------------------+
bool TickBufferAppend(const string item)
{
   if(G_TickPaused) return false;

   // Cap buffer growth when offline; dump to fallback if enabled
   int cur = ArraySize(G_TickBuffer);
   if(cur >= TICK_MAX_BUFFER){
      if(Fallback_To_File && cur>0){
         string dump = "{\"ticks\":[";
         for(int i=0;i<cur;i++){
            if(i>0) dump += ",";
            dump += G_TickBuffer[i];
         }
         dump += "]}";
         WriteFallbackJSONL(dump);
         if(API_LogDebug) PrintFormat("[TICK] buffer cap reached (%d) -> dumped to fallback and cleared", cur);
      } else {
         if(API_LogDebug) PrintFormat("[TICK] buffer cap reached (%d) -> dropping buffered ticks", cur);
      }
      ArrayResize(G_TickBuffer, 0);
      G_TickLastFlushMs = GetTickCount();
   }

   int k = ArraySize(G_TickBuffer);
   ArrayResize(G_TickBuffer, k+1);
   G_TickBuffer[k] = item;
   return true;
}

bool TickBufferFlush(const string reason)
{
   int n = ArraySize(G_TickBuffer);
   if(n<=0) return true;
   string body = "{\"ticks\":[";
   for(int i=0;i<n;i++){
      if(i>0) body += ",";
      body += G_TickBuffer[i];
   }
   body += "]}";

   int code=0; string resp="", hdrs="";
   G_ContextItemsCount = n;
   bool ok = SendJSONToURL(body, API_TICK_URL, code, resp, hdrs);
   if(ok){
      ArrayResize(G_TickBuffer, 0);
      G_TickLastFlushMs = GetTickCount();
      if(G_TickConsecFails>0) G_TickConsecFails = 0;
      if(G_TickPaused){
         G_TickPaused = false;
         Print("[TICK] auto-resumed after successful flush");
      }
      G_TickOk += n;
      G_PeriodTickOk += n;
      bool q = (StringFind(resp, "\"queued\":true")>=0);
      if(q){ G_QueuedTick++; G_PeriodQueuedTick++; }
      if(METRICS_ENABLE){ G_MetricsEvents++; if(METRICS_EVERY_EVENTS>0 && (G_MetricsEvents % METRICS_EVERY_EVENTS)==0) PrintMetrics(); }
      if(API_LogDebug) PrintFormat("[TICK] flush ok (%s) n=%d code=%d", reason, n, code);
      MaybePrintTimeSummary(TimeCurrent());
   } else {
      G_TickConsecFails++;
      G_TickFail++;
      if(METRICS_ENABLE){ G_MetricsEvents++; if(METRICS_EVERY_EVENTS>0 && (G_MetricsEvents % METRICS_EVERY_EVENTS)==0) PrintMetrics(); }
      if(API_LogDebug) PrintFormat("[TICK] flush fail (%s) n=%d code=%d fails=%d", reason, n, code, G_TickConsecFails);
      if(G_TickConsecFails >= TICK_AUTO_PAUSE_FAILS){
         G_TickPaused = true;
         PrintFormat("[TICK] auto-paused after %d consecutive failures. Check API availability and MT5 WebRequest whitelist.", G_TickConsecFails);
      }
      MaybePrintTimeSummary(TimeCurrent());
   }
   return ok;
}

//+------------------------------------------------------------------+
//| Parse HTTP status code from headers                              |
//+------------------------------------------------------------------+
int ParseHttpCode(const string &hdrs)
{
   int p = StringFind(hdrs, "HTTP/");
   if(p>=0){
      int sp = StringFind(hdrs, " ", p);
      if(sp>=0){
         string code3 = StringSubstr(hdrs, sp+1, 3);
         int code = (int)StringToInteger(code3);
         if(code>=100 && code<=599) return code;
      }
   }
   int ps = StringFind(hdrs, "Status:");
   if(ps>=0){
      int sp2 = StringFind(hdrs, " ", ps);
      if(sp2>=0){
         string code32 = StringSubstr(hdrs, sp2+1, 3);
         int code2 = (int)StringToInteger(code32);
         if(code2>=100 && code2<=599) return code2;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Append UTF-8 line to JSONL in FILE_COMMON                        |
//+------------------------------------------------------------------+
bool AppendUTF8LineCommon(const string fname, const string line)
{
   int h = FileOpen(fname, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE) return false;
   FileSeek(h, 0, SEEK_END);
   string with_nl = line + "\r\n";
   FileWriteString(h, with_nl);
   FileClose(h);
   return true;
}

void WriteFallbackJSONL(const string body)
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   string fname = StringFormat("PDC_fallback_%04d%02d%02d.jsonl", dt.year, dt.mon, dt.day);
   AppendUTF8LineCommon(fname, body);
}

//+------------------------------------------------------------------+
//| Send items with auto-split on 413/414                            |
//+------------------------------------------------------------------+
bool SendItemsOrSplit(string &items[], int start, int end, int &out_code, string &out_resp, string &out_hdrs)
{
   int count = end - start;
   if(count<=0) return true;

   string body = "{\"items\":[";
   for(int i=start;i<end;i++){
     if(i>start) body += ",";
     body += items[i];
   }
   body += "]}";

   int code=0; string resp="", hdrs="";
   bool ok = SendBatchJSON(body, code, resp, hdrs);
   out_code = code; out_resp = resp; out_hdrs = hdrs;
   if(ok) return true;

   if(Split_On_413_414 && (code==413 || code==414) && count>1){
      int mid = start + count/2;
      PrintFormat("[INGEST] split triggered code=%d total=%d -> left=%d right=%d", code, count, (mid-start), (end-mid));
      G_SplitEvents++;
      G_PeriodSplitEvents++;
      bool left  = SendItemsOrSplit(items, start, mid, out_code, out_resp, out_hdrs);
      bool right = SendItemsOrSplit(items, mid,   end, out_code, out_resp, out_hdrs);
      return left && right;
   }

   if(Fallback_To_File) WriteFallbackJSONL(body);
   return false;
}

//+------------------------------------------------------------------+
//| Extract path from URL for concise logging                        |
//+------------------------------------------------------------------+
string UrlPath(const string url)
{
   int p = StringFind(url, "://");
   int start = (p>=0) ? (p+3) : 0;
   int s = StringFind(url, "/", start);
   if(s>=0) return StringSubstr(url, s);
   return "/";
}

//+------------------------------------------------------------------+
//| Provide simple hint based on last_err/http code                  |
//+------------------------------------------------------------------+
string ErrorHint(const int last_err, const int http_code)
{
   if(http_code==0 && last_err==0) return "no HTTP status in headers (MQL5 parse)";
   if(last_err==4006) return "WebRequest not authorized? Check Tools>Options>Expert Advisors>Allow WebRequest";
   if(http_code==413) return "payload too large (split)";
   if(http_code==414) return "URI too long (split)";
   if(http_code>=500) return "server error";
   if(http_code==401 || http_code==403) return "auth/permission";
   return "";
}

//+------------------------------------------------------------------+
//| Simple JSON integer field finder                                |
//+------------------------------------------------------------------+
bool JsonFindInt(const string json, const string key, int &out_val)
{
   string pat = "\"" + key + "\":";
   int p = StringFind(json, pat);
   if(p<0) return false;
   int i = p + StringLen(pat);
   // skip whitespace
   while(i < StringLen(json)){
      int ch = StringGetCharacter(json, i);
      if(ch==' ' || ch=='\t' || ch=='\r' || ch=='\n') i++;
      else break;
   }
   bool neg=false;
   if(i < StringLen(json) && StringGetCharacter(json,i)=='-'){ neg=true; i++; }
   if(i >= StringLen(json)) return false;
   int start=i; int len=0;
   while(i < StringLen(json)){
      int ch = StringGetCharacter(json, i);
      if(ch>='0' && ch<='9'){ i++; len++; }
      else break;
   }
   if(len==0) return false;
   string num = StringSubstr(json, start, len);
   int val = (int)StringToInteger(num);
   out_val = neg ? -val : val;
   return true;
}

//+------------------------------------------------------------------+
//| Periodic metrics printing                                        |
//+------------------------------------------------------------------+
void PrintMetrics()
{
   PrintFormat("[METRICS] ingest_ok=%d ingest_fail=%d tick_ok=%d tick_fail=%d", G_IngestOk, G_IngestFail, G_TickOk, G_TickFail);
}

//+------------------------------------------------------------------+
//| Time-based summary printing (queued vs ok)                       |
//+------------------------------------------------------------------+
void MaybePrintTimeSummary(const datetime now)
{
   if(!METRICS_ENABLE) return;
   if(METRICS_SUMMARY_INTERVAL_S<=0) return;
   if(G_LastSummaryTs==0 || (now - G_LastSummaryTs) >= METRICS_SUMMARY_INTERVAL_S){
      PrintFormat(
         "[SUMMARY %ds] ingest_ok=%d queued_ing=%d tick_ok=%d queued_tick=%d split=%d (fails: ingest=%d tick=%d)",
         METRICS_SUMMARY_INTERVAL_S,
         G_PeriodIngestOk,
         G_PeriodQueuedIngest,
         G_PeriodTickOk,
         G_PeriodQueuedTick,
         G_PeriodSplitEvents,
         G_IngestFail,
         G_TickFail
      );
      // reset period counters
      G_PeriodIngestOk = 0;
      G_PeriodQueuedIngest = 0;
      G_PeriodTickOk = 0;
      G_PeriodQueuedTick = 0;
      G_PeriodSplitEvents = 0;
      G_LastSummaryTs = now;
   }
}

//+------------------------------------------------------------------+
//| End of file                                                      |
//+------------------------------------------------------------------+
