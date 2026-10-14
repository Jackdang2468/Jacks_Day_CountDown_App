-- Jack's Day Counter: yearly repeats, pinning, and per-countdown reminders.
-- Run once in Supabase dashboard > SQL Editor > New query > paste > Run.
alter table public.countdowns
  add column if not exists repeats_yearly    boolean not null default false,
  add column if not exists is_pinned         boolean not null default false,
  add column if not exists reminders_enabled boolean not null default true;
