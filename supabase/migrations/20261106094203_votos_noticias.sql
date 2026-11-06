-- Anonymous vote totals per item (onda, story or debate).
--
-- Only counters: no user id, no device id, no timestamp per vote. A user's
-- individual ratings stay on their device (they feed the political map,
-- special-category data under GDPR art. 9). The app calls cast_vote(); nobody
-- can write the table directly.
-- Known limit: without accounts, counters can be inflated by a script. Rate
-- limiting comes with user accounts.

create table public.votos_noticias (
  item_id     text primary key check (length(item_id) between 1 and 100),
  bien        integer not null default 0 check (bien >= 0),
  mal         integer not null default 0 check (mal >= 0),
  igual       integer not null default 0 check (igual >= 0),
  updated_at  timestamptz not null default now()
);

alter table public.votos_noticias enable row level security;

create policy "Vote totals are readable by everyone"
  on public.votos_noticias for select
  to anon, authenticated
  using (true);

revoke insert, update, delete, truncate on public.votos_noticias from anon, authenticated;

-- Adds one vote; if the user changed their mind, takes one from the previous option.
-- security definer: the only way to write the table, with validated input.
create or replace function public.cast_vote(p_item text, p_vote text, p_previous text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_vote not in ('bien', 'mal', 'igual') or (p_previous is not null and p_previous not in ('bien', 'mal', 'igual')) then
    raise exception 'invalid vote';
  end if;
  if p_previous = p_vote then
    return;
  end if;

  insert into public.votos_noticias as v (item_id, bien, mal, igual)
  values (p_item, (p_vote = 'bien')::int, (p_vote = 'mal')::int, (p_vote = 'igual')::int)
  on conflict (item_id) do update set
    bien  = greatest(0, v.bien  + (p_vote = 'bien')::int  - coalesce((p_previous = 'bien')::int, 0)),
    mal   = greatest(0, v.mal   + (p_vote = 'mal')::int   - coalesce((p_previous = 'mal')::int, 0)),
    igual = greatest(0, v.igual + (p_vote = 'igual')::int - coalesce((p_previous = 'igual')::int, 0)),
    updated_at = now();
end;
$$;

revoke all on function public.cast_vote(text, text, text) from public;
grant execute on function public.cast_vote(text, text, text) to anon, authenticated;
