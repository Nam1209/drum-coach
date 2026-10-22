Subreddit gợi ý: r/drums (hoặc r/edrums nếu muốn nhấn vào phần MIDI). Đọc luật sub về self-promotion trước khi đăng; app không bán, mã nguồn mở trên GitHub, nên thường được chấp nhận như một bài "show and tell / xin góp ý".

---

**Title:** I don't have a drum teacher, so I built an iPad app that tells me which notes I rushed. Looking for feedback from people who've had real lessons

**Body:**

I'm an adult learner working through Stick Control, aiming at Rockschool grades. My comfortable range is 50–90 BPM and I practise mostly on a 12" pad, sometimes on a Roland TD-4K. No teacher, so for a long time I had no idea whether I was actually on the click or just felt like I was.

So I built a practice app for my iPad. It's a personal project, not on the App Store, nothing to sell, and the code is public. Here's what it does:

- **Listens while you play.** Pad through the iPad mic (8-tap setup for room noise, softest stroke, latency), or e-kit over USB/Bluetooth MIDI.
- **Colours every note.** Green = within ±30 ms, amber = early/late (the mark sits before the note if you rushed, after if you dragged), red = missed. A % at the end.
- **Says *where* it goes wrong.** Which hand, which part of "1 e & a", and whether you drift through the run or are just consistently off (which is usually latency, not you).
- **Counting coach.** My counting fell apart on the "&", so it speaks a smooth "1 e & a" at any tempo, then listens to *me* count and marks each syllable.
- **Levels tied to Rockschool grades.** You pass a grade's tests at 90%+ at the book tempo, *and* you need practice points behind it, so you can't level up from one lucky run.
- **An "AI teacher" loop.** The app writes a daily practice report to Notion; I open a Claude chat that can read it, and it writes next week's plan back, which the app syncs. Not a replacement for a real teacher, but it catches patterns I miss (like my left hand being late on every "e").

It ships none of the Stick Control or Rockschool book content (copyright). It generates sticking permutations itself and lets me type in exercises from my own books.

Browser demo of the practice screen (you can tap along with the click): https://nam1209.github.io/drum-coach/

Clickable prototype of the whole app, every screen: https://nam1209.github.io/drum-coach/prototype-en.html

Source code (Swift/SwiftUI, if you have a Mac and an iPad you can build it yourself): https://github.com/Nam1209/drum-coach

Questions for those of you who've had lessons:

1. Is ±30 ms a reasonable "on time" window for a beginner, or too strict / too loose?
2. Would a real teacher care more about timing numbers like this, or would they tell me to fix something else first (grip, stroke height, sound)?
3. Anything you wish you'd been made to practise earlier that an app like this should push?

And for the self-taught folks, practising without a teacher like me:

4. How do you know you're actually improving? Recording yourself, a metronome app, a tempo log, something else?
5. What made you quit or stall in the past: boredom, plateaus, no clear next step, sore wrists? What would have kept you going?
6. Do you practise on a pad, an e-kit or an acoustic kit, and would mic-based scoring even work in your room?
7. Would you trust an AI-written weekly plan, or would you rather follow a fixed path like Rockschool grades or a book?
8. What does your daily practice look like right now (minutes, warm-up, what you work on)?

Full disclosure: I wrote it with a lot of help from Claude Code (AI coding assistant). Happy to answer questions about how it works.
