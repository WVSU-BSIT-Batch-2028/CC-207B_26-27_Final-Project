# ai-assistant

Customer chat uses the **Gemini API**. The key is **not** in Flutter `env/prod.json` — only in Supabase.

## Production

1. [Google AI Studio](https://aistudio.google.com/apikey) → create an **API key** (not OAuth).
2. Supabase Dashboard → **Project Settings** → **Edge Functions** → **Secrets**:
   - Name: `GEMINI_API_KEY`
   - Value: your key
3. Deploy the function (CLI or linked project):
   ```bash
   supabase functions deploy ai-assistant
   ```
4. Apply DB migration `20261115092729_ai_daily_limit.sql` if `consume_ai_message` is missing.
5. Optional secret `GEMINI_MODELS` (comma-separated), e.g. `gemini-3.6-flash,gemini-3.5-flash,gemini-2.5-flash`. Older `gemini-2.0-flash` was shut down in 2026.

**"Recommend a pharmacy for …"** is answered from live inventory when possible — no Gemini call required.

## Local

```bash
supabase secrets set GEMINI_API_KEY=your-key-here
supabase functions serve ai-assistant
```

## Test

- Sign in as a **customer** (admin accounts get 403).
- Ask something in the app Assistant screen, or POST to the function with the user's JWT.