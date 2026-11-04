-- Reliable 30-min trigger for the price ingestion worker.
--
-- GitHub's `schedule` event is best effort: on this repo it fired 2 of ~22
-- expected runs in 11 h. pg_cron is precise, so the database now triggers the
-- `ingest-prices` workflow through GitHub's workflow_dispatch API. The worker
-- itself stays in Python on GitHub Actions; only the trigger moves here.
--
-- Requires a Vault secret named 'github_actions_token': a fine-grained GitHub
-- token scoped to this repository with "Actions: read and write" permission.
-- See docs/decisiones/0002-disparo-de-la-ingesta.md.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- Schema for internal jobs. Not exposed through the Data API.
create schema if not exists internal;
revoke all on schema internal from public, anon, authenticated;

-- Fires the workflow. Returns the pg_net request id; the HTTP response
-- (GitHub answers 204 on success) lands in net._http_response.
create or replace function internal.dispatch_price_ingestion()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
begin
  select decrypted_secret into token
  from vault.decrypted_secrets
  where name = 'github_actions_token';

  if token is null then
    raise exception 'Vault secret "github_actions_token" is missing';
  end if;

  return net.http_post(
    url     := 'https://api.github.com/repos/StefanMarioMagura/onda/actions/workflows/ingest-prices.yml/dispatches',
    headers := jsonb_build_object(
      'Authorization',        'Bearer ' || token,
      'Accept',               'application/vnd.github+json',
      'X-GitHub-Api-Version', '2022-11-28',
      'User-Agent',           'onda-pg-cron'
    ),
    body    := jsonb_build_object('ref', 'main')
  );
end;
$$;

revoke all on function internal.dispatch_price_ingestion() from public, anon, authenticated;

-- :02 and :32. The GitHub `schedule` (:07/:37) stays as a fallback; an extra
-- run is harmless because ingestion is idempotent.
select cron.schedule(
  'dispatch-price-ingestion',
  '2,32 * * * *',
  'select internal.dispatch_price_ingestion()'
);
