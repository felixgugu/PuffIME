// Minimal headless harness for PuffIME.
//
// Loads C:\Program Files\Rime\weasel-0.17.4\rime.dll dynamically, initializes
// librime with the Weasel shared data and the Rime user directory, then feeds
// key events and prints commits / candidate lists.
//
// Build (from a VS2022 developer prompt):
//   cl /nologo /EHsc /std:c++17 /I tools tools\rime_harness.cpp /Fe:tools\rime_harness.exe
//
// Run:
//   tools\rime_harness.exe > tools\harness-output.txt
//
// Stop WeaselServer first (WeaselServer.exe /q) so it does not hold the user
// data directory.

#include <windows.h>
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <string>

#include "rime_api.h"

typedef RimeApi* (*RimeGetApiFn)(void);

static RimeApi* g_api = nullptr;
static FILE* g_out = nullptr;

static void out(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
}

static void out_w(const wchar_t* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfwprintf(g_out, fmt, ap);
    va_end(ap);
}

static int XK_Return = 0xFF0D;
static int XK_BackSpace = 0xFF08;
static int XK_Escape = 0xFF1B;
static int XK_grave = 0x60;

static void send_char(RimeSessionId session, int ch) {
    g_api->process_key(session, ch, 0);
}

static void send_string(RimeSessionId session, const std::string& s) {
    for (unsigned char ch : s) {
        send_char(session, ch);
    }
}

static std::string commit_text(RimeSessionId session) {
    RIME_STRUCT(RimeCommit, commit);
    std::string result;
    if (g_api->get_commit(session, &commit)) {
        if (commit.text) result = commit.text;
        g_api->free_commit(&commit);
    }
    return result;
}

static void print_context(RimeSessionId session) {
    RIME_STRUCT(RimeContext, ctx);
    if (!g_api->get_context(session, &ctx)) {
        out("    context: <none>\n");
        return;
    }
    out("    preedit: [%s] cursor=%d\n",
        ctx.composition.preedit ? ctx.composition.preedit : "",
        ctx.composition.cursor_pos);
    out("    highlighted: %d\n", ctx.menu.highlighted_candidate_index);
    out("    candidates (%d):", ctx.menu.num_candidates);
    for (int i = 0; i < ctx.menu.num_candidates && i < 12; ++i) {
        out(" %d:%s", i + 1,
            ctx.menu.candidates[i].text ? ctx.menu.candidates[i].text : "");
        if (ctx.menu.candidates[i].comment && ctx.menu.candidates[i].comment[0]) {
            out("(%s)", ctx.menu.candidates[i].comment);
        }
    }
    out("\n");
    g_api->free_context(&ctx);
}

static void run_case(const char* name, const char* keys, int final_key,
                     const char* expect) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    if (final_key) send_char(session, final_key);
    std::string committed = commit_text(session);
    bool ok = (committed == expect);
    out("CASE %-24s keys=[%s] final=%d => [%s] expect [%s] %s\n",
        name, keys, final_key, committed.c_str(), expect, ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

// Page through the menu and count every candidate.  RimeContext only exposes
// the current page, so this sends Page_Down until menu.is_last_page.
static void run_count_case(const char* name, const char* keys, int expect_count) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    int total = 0;
    bool last = false;
    for (int guard = 0; guard < 500 && !last; ++guard) {
        RIME_STRUCT(RimeContext, ctx);
        if (!g_api->get_context(session, &ctx)) {
            break;
        }
        total += ctx.menu.num_candidates;
        last = ctx.menu.is_last_page;
        g_api->free_context(&ctx);
        if (!last) {
            g_api->process_key(session, 0xFF56, 0);  // Page_Down
        }
    }
    bool ok = (total == expect_count);
    out("CASE %-24s keys=[%s] total=%d expect=%d %s\n",
        name, keys, total, expect_count, ok ? "OK" : "MISMATCH");
    g_api->destroy_session(session);
}

static void run_preedit_case(const char* name, const char* keys,
                             const char* expect) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    RIME_STRUCT(RimeContext, ctx);
    std::string preedit;
    if (g_api->get_context(session, &ctx)) {
        if (ctx.composition.preedit) preedit = ctx.composition.preedit;
        g_api->free_context(&ctx);
    }
    bool ok = (preedit == expect);
    out("CASE %-24s keys=[%s] preedit=[%s] expect [%s] %s\n",
        name, keys, preedit.c_str(), expect, ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

static void run_paged_case(const char* name, const char* keys, int pages,
                           int final_key, const char* expect) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    for (int i = 0; i < pages; ++i) {
        g_api->process_key(session, 0xFF56, 0);  // Page_Down
    }
    if (final_key) send_char(session, final_key);
    std::string committed = commit_text(session);
    bool ok = (committed == expect);
    out("CASE %-24s keys=[%s] pages=%d final=%d => [%s] expect [%s] %s\n",
        name, keys, pages, final_key, committed.c_str(), expect,
        ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

static void run_context_case(const char* name, const char* keys) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    out("CASE %-24s keys=[%s] (context only)\n", name, keys);
    print_context(session);
    g_api->destroy_session(session);
}

static void run_select_case(const char* name, const char* keys, int keycode,
                            int mask, const char* expect, bool then_enter = false) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    g_api->process_key(session, keycode, mask);
    if (then_enter) {
        g_api->process_key(session, XK_Return, 0);
    }
    std::string committed = commit_text(session);
    bool ok = (committed == expect);
    out("CASE %-24s keys=[%s] key=%d mask=%d => [%s] expect [%s] %s\n",
        name, keys, keycode, mask, committed.c_str(), expect, ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

static void run_symbol_case(const char* name, int cycles, const char* keys,
                            int final_key, const char* expect) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    for (int i = 0; i < cycles; ++i) {
        g_api->process_key(session, ' ', 1);  // Shift+Space
    }
    send_string(session, keys);
    g_api->process_key(session, final_key, 0);
    std::string committed = commit_text(session);
    bool ok = (committed == expect);
    out("CASE %-28s cycles=%d keys=[%s] final=%d => [%s] expect [%s] %s\n",
        name, cycles, keys, final_key, committed.c_str(), expect,
        ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

static void run_direct_case(const char* name, int cycles, int keycode,
                            int mask, const char* expect) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    for (int i = 0; i < cycles; ++i) {
        g_api->process_key(session, ' ', 1);  // Shift+Space
    }
    g_api->process_key(session, keycode, mask);
    std::string committed = commit_text(session);
    bool ok = (committed == expect);
    out("CASE %-28s cycles=%d key=%d mask=%d => [%s] expect [%s] %s\n",
        name, cycles, keycode, mask, committed.c_str(), expect,
        ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

static void run_commit_case(const char* name, const char* keys,
                            const char* expect) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    std::string committed = commit_text(session);
    bool ok = (committed == expect);
    out("CASE %-24s keys=[%s] => [%s] expect [%s] %s\n",
        name, keys, committed.c_str(), expect, ok ? "OK" : "MISMATCH");
    print_context(session);
    g_api->destroy_session(session);
}

static void run_highlight_case(const char* name, const char* keys) {
    RimeSessionId session = g_api->create_session();
    if (!session) {
        out("CASE %s: FAILED to create session\n", name);
        return;
    }
    g_api->select_schema(session, "puffime");
    send_string(session, keys);
    out("CASE %-24s (highlight only)\n", name);
    print_context(session);
    g_api->destroy_session(session);
}

int main() {
    // UTF-8 output file; the console may be cp950.
    const char* out_path = "tools\\harness-output.txt";
    g_out = fopen(out_path, "wb");
    if (!g_out) {
        printf("cannot open %s\n", out_path);
        return 1;
    }
    out("# PuffIME headless harness\n");

    const char* dll_path = "C:\\Program Files\\Rime\\weasel-0.17.4\\rime.dll";
    HMODULE dll = LoadLibraryExA(dll_path, NULL, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!dll) {
        out("LoadLibrary failed: %lu\n", GetLastError());
        fclose(g_out);
        return 2;
    }
    RimeGetApiFn get_api = (RimeGetApiFn)GetProcAddress(dll, "rime_get_api");
    if (!get_api) {
        out("rime_get_api not found\n");
        FreeLibrary(dll);
        fclose(g_out);
        return 3;
    }
    g_api = get_api();
    if (!g_api || g_api->data_size <= 0) {
        out("RimeGetApi returned null\n");
        FreeLibrary(dll);
        fclose(g_out);
        return 4;
    }
    out("RimeApi data_size=%d\n", g_api->data_size);

    RimeTraits traits = {0};
    RIME_STRUCT_INIT(RimeTraits, traits);
    static std::string user_data_dir =
        "C:\\Users\\felix\\AppData\\Roaming\\Rime";
    if (const char* env_user_dir = getenv("PUFF_RIME_USER_DIR")) {
        if (*env_user_dir) {
            user_data_dir = env_user_dir;
        }
    }
    traits.shared_data_dir = "C:\\Program Files\\Rime\\weasel-0.17.4\\data";
    traits.user_data_dir = user_data_dir.c_str();
    traits.distribution_name = "Weasel";
    traits.distribution_code_name = "weasel";
    traits.distribution_version = "0.17.4";
    traits.app_name = "rime.pufftest";
    traits.min_log_level = 2;  // ERROR

    g_api->setup(&traits);
    g_api->initialize(&traits);
    g_api->join_maintenance_thread();

    run_case("boshiamy-a", "a", ' ', "對");
    run_case("boshiamy-aa", "aa", ' ', "寸");
    // Prefix completion: a single code lists every character whose code
    // starts with it; each extra code narrows the list.  Completions are
    // ordered by essay frequency, not by code length.
    run_select_case("completion-a-2", "a", '2', 0, "也");
    run_select_case("completion-aa-3", "aa", '3', 0, "錢");
    run_select_case("completion-aaa-2", "aaa", '2', 0, "龘");
    run_case("completion-i-space", "i", ' ', "後");
    run_select_case("completion-i-2", "i", '2', 0, "我");
    run_select_case("completion-i-3", "i", '3', 0, "說");
    run_case("completion-out-space", "out", ' ', "嚅");
    // Count every page: each extra code must narrow the candidate list.
    // Totals include the English raw candidate.
    run_count_case("completion-count-a", "a", 877);
    run_count_case("completion-count-aa", "aa", 41);
    run_count_case("completion-count-aaa", "aaa", 4);
    run_count_case("completion-count-i", "i", 477);
    run_case("boshiamy-comma", ",", ' ', ",");
    run_case("boshiamy-bracket", "[", ' ', "「");
    run_case("boshiamy-yneu", "yneu", ' ', "殼");
    run_case("boshiamy-v-space", "v", ' ', "要");
    run_select_case("boshiamy-ak-v", "ak", 'v', 0, "鐵");
    run_context_case("context-ak", "ak");
    run_context_case("context-av", "av");
    run_case("english-the-enter", "the", XK_Return, "the");
    run_case("boshiamy-the-space", "the", ' ', "棫");
    run_case("english-was-space", "was", ' ', "");
    run_case("english-was-enter", "was", XK_Return, "was");
    run_case("english-hello-space", "hello", ' ', "");
    run_case("english-hello-enter", "hello", XK_Return, "hello");
    run_case("boshiamy-invalid-space", "zzzz", ' ', "");
    run_case("boshiamy-invalid-enter", "zzzz", XK_Return, "zzzz");
    // Continuous English: when only the raw candidate remains, Space is
    // pushed into the buffer (it shows in the preedit) and Enter commits the
    // whole sentence, spaces included.
    run_preedit_case("english-was-space-preedit", "was ", "was ");
    run_preedit_case("english-invalid-space-preedit", "zzzz ", "zzzz ");
    run_case("english-sentence-enter", "hello world", XK_Return, "hello world");
    run_case("english-sentence-trailing-space", "hello world ", XK_Return,
             "hello world ");
    // Digits are input while only raw English remains (they used to select
    // candidate 1 and commit).  Enter commits the whole buffer.
    run_preedit_case("english-was-digit-preedit", "was1", "was1");
    run_case("english-was-digit-enter", "was1", XK_Return, "was1");
    run_case("english-digits-enter", "hello123", XK_Return, "hello123");
    run_case("english-digits-space-enter", "test 42", XK_Return, "test 42");
    // A space after a digit must still join the English buffer (the tail is
    // a raw segment, not an abc segment).
    run_preedit_case("english-digit-space-preedit", "hello1 ", "hello1 ");
    run_case("english-digit-then-space-enter", "hello1 world", XK_Return,
             "hello1 world");
    // Zhuyin: Space is the first-tone key and never commits; Enter commits.
    run_case("zhuyin-su3-enter", "`su3", XK_Return, "你");
    run_case("zhuyin-su3-space-no-commit", "`su3", ' ', "");
    run_case("zhuyin-u-enter", "`u", XK_Return, "一");
    run_case("zhuyin-u-first-tone-enter", "`u ", XK_Return, "一");
    run_case("zhuyin-su3cl3-enter", "`su3cl3", XK_Return, "你好");
    run_case("zhuyin-ji3-enter", "`ji3", XK_Return, "我");
    run_case("zhuyin-wu0-enter", "`wu0", XK_Return, "天");
    run_case("zhuyin-w8-enter", "`w8", XK_Return, "他");
    run_case("zhuyin-ji3-2-enter", "`ji32", XK_Return, "婑");
    run_case("zhuyin-invalid-ji2-enter", "`ji2", XK_Return, "");
    // 稽 (ㄐㄧ first tone): Space narrows `ru` from all tones to first tone.
    run_case("zhuyin-ru-enter", "`ru", XK_Return, "給");
    run_case("zhuyin-ru-space-no-commit", "`ru", ' ', "");
    run_case("zhuyin-ru-first-tone-enter", "`ru ", XK_Return, "機");
    run_paged_case("zhuyin-ru-first-tone-ji", "`ru ", 2, XK_Return, "稽");
    run_case("zhuyin-ru-first-tone-digit", "`ru 1", XK_Return, "機");
    run_case("zhuyin-phrase-first-tone-enter", "`ru t86", XK_Return, "稽查");
    run_case("zhuyin-phrase-marked-both", "`rup wu0 ", XK_Return, "今天");
    run_case("zhuyin-phrase-normal-space", "`rupwu0 ", XK_Return, "今天");
    run_case("zhuyin-incomplete-space-noop", "`1 ", XK_Return, "不");

    // Context-only cases: check that the English candidate is present.
    run_context_case("context-the", "the");
    run_context_case("context-feba", "feba");
    run_context_case("context-was", "was");
    run_context_case("context-he", "he");
    run_context_case("context-completion-a", "a");
    run_context_case("context-completion-aa", "aa");
    run_context_case("context-completion-aaa", "aaa");
    run_context_case("context-completion-i", "i");
    run_context_case("context-zhuyin-su3", "`su3");
    run_preedit_case("zhuyin-preedit-initial-b", "`1", "ㄅ");
    run_preedit_case("zhuyin-preedit-initial-zh", "`5", "ㄓ");
    run_preedit_case("zhuyin-preedit-initial-b-vowel", "`1u", "ㄅㄧ");
    run_preedit_case("zhuyin-preedit-initial-b-tone", "`1u6", "ㄅㄧˊ");
    run_preedit_case("zhuyin-preedit-ba", "`18", "ㄅㄚ");
    run_context_case("context-zhuyin-ba", "`18");
    // An incomplete initial (no exact code) has no first-tone alias: Space is
    // swallowed and Enter commits the first prefix-completion candidate.
    run_case("zhuyin-initial-b-space", "`1", ' ', "");
    run_case("zhuyin-initial-b-enter", "`1", XK_Return, "不");
    run_context_case("context-zhuyin-initial-b", "`1");
    run_count_case("zhuyin-count-initial-b", "`1", 1908);
    // An exact syllable keeps its exact candidates first and appends the
    // frequency-ordered completions (之/只/至... then 中/這...).
    run_count_case("zhuyin-count-initial-zh", "`5", 2591);
    run_preedit_case("zhuyin-preedit-first-tone", "`ru ", "ㄐㄧˉ");
    run_preedit_case("zhuyin-preedit-partial-next-syllable", "`su3c",
                     "ㄋㄧˇㄏ");
    run_case("zhuyin-partial-next-syllable-space", "`su3c", ' ', "");
    run_context_case("context-zhuyin-su-toneless", "`su");
    run_context_case("context-zhuyin-su6", "`su6");
    run_context_case("context-zhuyin-su4", "`su4");
    run_context_case("context-zhuyin-ji3", "`ji3");
    run_context_case("context-zhuyin-ji-toneless", "`ji");
    run_context_case("context-zhuyin-wu0", "`wu0");
    run_context_case("context-symbol-jt", "/jt");
    run_context_case("context-symbol-sx", "/sx");
    run_context_case("context-symbol-bq", "/bq");
    run_case("symbol-jt-space", "/jt", ' ', "↑");
    run_case("symbol-sx-space", "/sx", ' ', "±");
    run_case("symbol-bq-space", "/bq", ' ', "☻");
    run_symbol_case("symbol-half-comma", 0, ",", ' ', ",");
    run_symbol_case("symbol-natural-comma", 1, ",", ' ', "，");
    run_symbol_case("symbol-full-comma", 2, ",", ' ', "，");
    run_symbol_case("symbol-half-dollar", 0, ",dol", ' ', "$");
    run_symbol_case("symbol-natural-dollar", 1, ",dol", ' ', "$");
    run_symbol_case("symbol-full-dollar", 2, ",dol", ' ', "＄");
    run_symbol_case("symbol-half-excl", 0, "c.", ' ', "!");
    run_symbol_case("symbol-natural-excl", 1, "c.", ' ', "！");
    run_symbol_case("symbol-full-excl", 2, "c.", ' ', "！");
    run_symbol_case("symbol-half-bracket", 0, "[", ' ', "「");
    run_symbol_case("symbol-natural-bracket", 1, "[", ' ', "「");
    run_symbol_case("symbol-half-menu", 0, "/jt", ' ', "↑");
    run_symbol_case("symbol-natural-menu", 1, "/jt", ' ', "↑");
    run_direct_case("direct-half-excl-passthrough", 0, '!', 1, "");
    run_direct_case("direct-natural-excl", 1, '!', 1, "！");
    run_direct_case("direct-full-excl", 2, '!', 1, "！");
    run_direct_case("direct-half-question-passthrough", 0, '?', 1, "");
    run_direct_case("direct-natural-question", 1, '?', 1, "？");
    run_direct_case("direct-full-question", 2, '?', 1, "？");
    run_symbol_case("direct-half-slash", 0, "/", ' ', "/");
    run_symbol_case("direct-natural-slash", 1, "/", ' ', "/");
    run_symbol_case("direct-full-slash", 2, "/", ' ', "／");

    // Candidate selection: plain digits in boshiamy, Shift+digit in zhuyin.
    run_select_case("select-the-2", "the", '2', 0, "the");
    run_select_case("select-the-shift2", "the", '@', 1, "the");
    run_select_case("select-zhuyin-shift2", "`su3", '@', 1, "擬", true);
    run_select_case("zhuyin-ji3-plain-2", "`ji3", '2', 0, "婑", true);
    run_select_case("zhuyin-su-shift2", "`su", '@', 1, "呢", true);
    run_select_case("zhuyin-su-toneless-first", "`su", '!', 1, "你", true);
    run_select_case("zhuyin-ji-toneless-first", "`ji", '!', 1, "我", true);
    run_select_case("zhuyin-initial-b-shift2", "`1", '@', 1, "吧", true);
    run_case("zhuyin-invalid-ji2-space", "`ji2", ' ', "");
    run_case("zhuyin-su-plain-2-space", "`su2", ' ', "");

    // A plain digit is still input while the prefix menu is open: `1 (ㄅ)
    // then 8 (ㄚ) must become ㄅㄚ, not select the 8th candidate.
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`1");
        g_api->process_key(session, '8', 0);
        RIME_STRUCT(RimeContext, ctx);
        std::string preedit;
        if (g_api->get_context(session, &ctx)) {
            if (ctx.composition.preedit) preedit = ctx.composition.preedit;
            g_api->free_context(&ctx);
        }
        out("CASE zhuyin-initial-b-digit-input preedit=[%s] expect [ㄅㄚ] %s\n",
            preedit.c_str(), preedit == "ㄅㄚ" ? "OK" : "MISMATCH");
        g_api->destroy_session(session);
    }

    // Zhuyin digit selection must highlight only; Enter commits.
    run_highlight_case("zhuyin-ji3-after-plain-2", "`ji32");
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji3");
        g_api->process_key(session, '2', 0);
        g_api->process_key(session, '3', 0);
        out("CASE zhuyin-ji3-after-plain-2-3 (highlight only)\n");
        print_context(session);
        g_api->process_key(session, XK_Return, 0);
        std::string committed = commit_text(session);
        out("CASE zhuyin-ji3-2-3-enter => [%s] expect [捰] %s\n",
            committed.c_str(), committed == "捰" ? "OK" : "MISMATCH");
        g_api->destroy_session(session);
    }
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji3");
        g_api->process_key(session, '@', 1);
        out("CASE zhuyin-ji3-after-shift2 (highlight only)\n");
        print_context(session);
        g_api->process_key(session, XK_Return, 0);
        std::string committed = commit_text(session);
        out("CASE zhuyin-ji3-shift2-enter => [%s] expect [婑] %s\n",
            committed.c_str(), committed == "婑" ? "OK" : "MISMATCH");
        g_api->destroy_session(session);
    }

    // Backtick after input must not start zhuyin and must not commit the
    // composition.  grave_guard swallows it; then space commits 對.
    run_context_case("context-a-only", "a");
    run_context_case("context-a-backtick", "a`");
    run_case("backtick-after-a-space", "a`", ' ', "對");
    run_commit_case("backtick-double", "``", "``");
    run_case("backtick-single-enter", "`", XK_Return, "`");

    // ASCII mode via CapsLock (standard Rime ascii_composer behavior).
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        g_api->process_key(session, 0xFFE5, 0);  // XK_Caps_Lock
        RIME_STRUCT(RimeStatus, status);
        if (g_api->get_status(session, &status)) {
            out("CASE ascii-capslock: is_ascii_mode=%d (expect 1)\n",
                status.is_ascii_mode);
            g_api->free_status(&status);
        } else {
            out("CASE ascii-capslock: get_status failed\n");
        }
        g_api->destroy_session(session);
    }

    // Does the engine auto-commit a zhuyin syllable when the next syllable starts?
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji3a");
        std::string committed = commit_text(session);
        out("CASE zhuyin-ji3-then-a: committed=[%s]\n", committed.c_str());
        print_context(session);
        g_api->destroy_session(session);
    }
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji3su3");
        std::string committed = commit_text(session);
        out("CASE zhuyin-ji3-then-su3: committed=[%s]\n", committed.c_str());
        print_context(session);
        g_api->destroy_session(session);
    }

    // Does the highlight persist across compositions in one session?
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji3");
        out("CASE seq1-ji3-before-digit\n");
        print_context(session);
        g_api->process_key(session, '3', 0);
        out("CASE seq1-ji3-after-digit-3\n");
        print_context(session);
        g_api->process_key(session, XK_Return, 0);
        out("CASE seq1-commit => [%s]\n", commit_text(session).c_str());
        send_string(session, "`su3");
        out("CASE seq1-next-su3\n");
        print_context(session);
        g_api->destroy_session(session);
    }
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji3");
        g_api->process_key(session, XK_Return, 0);
        out("CASE seq2-commit => [%s]\n", commit_text(session).c_str());
        send_string(session, "`su3");
        out("CASE seq2-next-su3\n");
        print_context(session);
        g_api->destroy_session(session);
    }

    // A key release must not be processed as a second key press.  The tone
    // 3 press inputs the tone; the release used to be mistaken for candidate
    // selection 3 and left the highlight on the third candidate.
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`ji");
        g_api->process_key(session, '3', 0);            // press tone
        g_api->process_key(session, '3', 0x40000000);   // release tone (kReleaseMask)
        out("CASE zhuyin-tone-press-release\n");
        print_context(session);
        g_api->process_key(session, XK_Return, 0);
        out("CASE zhuyin-tone-press-release-enter => [%s] expect [我]\n",
            commit_text(session).c_str());
        g_api->destroy_session(session);
    }

    // Forgotten list: after the Zhuyin commits above, ,,fk should show them.
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, ",,fk");
        out("CASE forgotten-list-fk\n");
        print_context(session);
        g_api->process_key(session, ' ', 0);
        out("CASE forgotten-list-fk-space => [%s]\n",
            commit_text(session).c_str());
        g_api->destroy_session(session);
    }

    // ,,fl: only the most recent Zhuyin commit.  Seed a unique character
    // first so the check is unambiguous.
    {
        RimeSessionId session = g_api->create_session();
        g_api->select_schema(session, "puffime");
        send_string(session, "`wu0");
        g_api->process_key(session, XK_Return, 0);
        out("CASE forgotten-last-seed => [%s]\n", commit_text(session).c_str());
        g_api->destroy_session(session);
    }
    run_context_case("forgotten-last-fl", ",,fl");
    run_case("forgotten-last-fl-space", ",,fl", ' ', "天");

    g_api->finalize();
    FreeLibrary(dll);
    fclose(g_out);
    printf("done: %s\n", out_path);
    return 0;
}
