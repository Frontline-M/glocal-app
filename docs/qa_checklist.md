# QA Checklist

- Clock displays local timezone correctly.
- 12h/24h toggle persists after app restart.
- Hourly time announcement triggers at top of hour.
- Weather announcement uses latest API data or cached fallback.
- Low-bandwidth mode retries and degrades gracefully.
- Voice picker changes active TTS voice.
- Volume slider affects spoken announcements.
- Quiet hours suppress announcements.
- Voice reminder capture transcribes and pre-fills edit dialog.
- Reminder schedules local notification at selected time.
- Permissions denied path shows recoverable user guidance.
- App survives offline startup with cached state.
