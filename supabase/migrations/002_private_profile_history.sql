-- Private user contact details and basic listing history.
create table if not exists public.private_profile_details (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 phone_number text check(phone_number is null or length(phone_number) between 6 and 32),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.private_profile_details enable row level security;
drop policy if exists "Users read own private profile details" on public.private_profile_details;
create policy "Users read own private profile details" on public.private_profile_details for select to authenticated using(user_id=auth.uid());
drop policy if exists "Users create own private profile details" on public.private_profile_details;
create policy "Users create own private profile details" on public.private_profile_details for insert to authenticated with check(user_id=auth.uid());
drop policy if exists "Users update own private profile details" on public.private_profile_details;
create policy "Users update own private profile details" on public.private_profile_details for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());

create or replace function public.record_listing_activity() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' then
  insert into public.activity_events(user_id,kind,description,status,entity_id) values(new.seller_id,'listing','Created listing: '||new.title,'available',new.id);
 elsif old.status is distinct from new.status then
  insert into public.activity_events(user_id,kind,description,status,entity_id) values(new.seller_id,'listing','Listing "'||new.title||'" is now '||new.status::text,new.status::text,new.id);
 end if;
 return new;
end $$;
drop trigger if exists listings_activity_insert on public.listings;
create trigger listings_activity_insert after insert on public.listings for each row execute function public.record_listing_activity();
drop trigger if exists listings_activity_status on public.listings;
create trigger listings_activity_status after update of status on public.listings for each row execute function public.record_listing_activity();
