# Cloud transcription providers — research & roadmap

*Written 2026-08-08. Prices checked against public pricing pages/aggregators on that date — re-verify before quoting anywhere user-facing.*

## What shipped (build 16)

The cloud engine ("Cloud Whisper", provider id `openai-whisper`) speaks the **OpenAI wire
format** but the server is user-configurable — Settings → Transcription exposes:

| Defaults key        | Meaning                        | Default                     |
|---------------------|--------------------------------|-----------------------------|
| `cloud.baseURL`     | OpenAI-compatible base URL     | `https://api.openai.com/v1` |
| `cloud.sttModel`    | model for `/audio/transcriptions` | `whisper-1`              |
| `cloud.polishModel` | chat model for grammar polish  | `gpt-4o-mini`               |

One key (`openAIKey`) authenticates against whichever server is configured; the key
verifier probes `{base}/models` on the configured server. Presets ship for the three
providers below.

## OpenAI-compatible drop-ins (work today via the Server field)

| Provider | Base URL | STT model | Price | Notes |
|---|---|---|---|---|
| OpenAI | `https://api.openai.com/v1` | `whisper-1` | ~$0.006/min (~$0.36/hr) | The default; also `gpt-4o-mini-transcribe`. |
| **Groq** | `https://api.groq.com/openai/v1` | `whisper-large-v3-turbo` | **~$0.04/hr (~9× cheaper)** | 228× real-time; free tier ≈ 28,800 audio-seconds/day — effectively free for personal dictation. Polish: `llama-3.1-8b-instant`. |
| **Mistral** | `https://api.mistral.ai/v1` | `voxtral-mini-latest` | ~$0.003/min (≈half of OpenAI) | Voxtral Mini Transcribe; claims better WER than whisper-large-v3. Polish: `mistral-small-latest`. |
| OpenRouter | `https://openrouter.ai/api/v1` | `openai/whisper-large-v3-turbo` | varies | One key, many models — mostly useful for the polish model. |
| Local (Ollama / LM Studio / vLLM) | e.g. `http://localhost:11434/v1` | n/a for STT | free | OpenAI-compatible **chat** only → works for the polish model; STT support varies by server. |

## Not drop-in compatible (would need native adapters — future work)

- **Deepgram Nova-3** (~$0.26/hr batch): own REST/WS API. Best-in-class streaming — the
  interesting one if we ever want *cloud* live partials instead of Apple-only.
- **AssemblyAI Universal** (~$0.12/hr): own API, strong diarization/formatting.
- **ElevenLabs Scribe**: own API; premium accuracy tier.
- Each would be a new `AIModelProvider` struct in `AIModelProvider.swift` with its own
  request shape — the registry already supports that; nothing blocks it structurally.

## Recommended next steps

1. **Groq preset as the "recommended cheap" path** in onboarding copy (free tier covers a
   typical day of dictation) — currently only surfaced in Settings presets.
2. Per-provider key storage (`cloud.apiKey.<host>`) if users switch servers often — today
   one key field follows the active server.
3. Keychain storage for keys instead of UserDefaults.
4. Deepgram adapter if cloud streaming partials become a goal.

## Sources

- [Groq pricing 2026 (CloudZero)](https://www.cloudzero.com/blog/groq-pricing/)
- [Groq speech-to-text API overview (apio)](https://apio.sh/apis/groq-speech-to-text)
- [Whisper API pricing comparison (TokenMix)](https://tokenmix.ai/blog/whisper-api-pricing)
- [Voxtral announcement (Mistral)](https://mistral.ai/news/voxtral/)
- [Voxtral Mini Transcribe pricing (OpenRouter)](https://openrouter.ai/mistralai/voxtral-mini-transcribe)
- [Mistral API pricing](https://mistral.ai/pricing/api/)
- [Transcription API comparison incl. Deepgram/AssemblyAI (VexaScribe)](https://novascribe.ai/compare/best-transcription-api-for-developers)
