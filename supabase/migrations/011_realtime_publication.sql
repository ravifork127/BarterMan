do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['listings','listing_images','offers','trade_requests','rental_requests','messages','conversation_members','activity_events','notifications'] loop
      if to_regclass(format('public.%I', t)) is not null
         and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;
