-- BarterMan initial schema. Apply in the Supabase SQL editor or with `supabase db push`.
create extension if not exists pgcrypto;
do $$ begin create type public.listing_status as enum ('available','reserved','completed','paused','removed'); exception when duplicate_object then null; end $$;
do $$ begin create type public.transaction_type as enum ('sale','barter','rental','auction'); exception when duplicate_object then null; end $$;
do $$ begin create type public.request_status as enum ('pending','accepted','rejected','cancelled','completed'); exception when duplicate_object then null; end $$;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '', bio text not null default '', campus text not null default '', avatar_path text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create or replace function public.create_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_profile();
create table if not exists public.listings (
 id uuid primary key default gen_random_uuid(), seller_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check(length(trim(title)) between 3 and 100), description text not null check(length(trim(description)) between 1 and 3000),
 category text not null check(length(category) between 1 and 60), condition text not null check(condition in ('Like new','Good','Fair','Well loved')),
 transaction_type public.transaction_type not null, price numeric(12,2) check(price is null or price>=0), status public.listing_status not null default 'available',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(transaction_type='barter' or price is not null)
);
create index if not exists listings_browse_idx on public.listings(status,category,created_at desc);
create index if not exists listings_seller_idx on public.listings(seller_id,created_at desc);
create table if not exists public.listing_images(id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade, storage_path text not null unique, sort_order int not null default 0, created_at timestamptz not null default now());
create table if not exists public.offers(id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade, buyer_id uuid not null references public.profiles(id) on delete cascade, amount numeric(12,2) not null check(amount>0), message text not null default '' check(length(message)<=1000), status public.request_status not null default 'pending', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(listing_id,buyer_id));
create table if not exists public.trade_requests(id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade, requester_id uuid not null references public.profiles(id) on delete cascade, offered_listing_id uuid references public.listings(id) on delete set null, message text not null default '' check(length(message)<=1000), status public.request_status not null default 'pending', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(offered_listing_id is not null or length(trim(message))>0));
create table if not exists public.rental_requests(id uuid primary key default gen_random_uuid(), listing_id uuid not null references public.listings(id) on delete cascade, renter_id uuid not null references public.profiles(id) on delete cascade, starts_on date not null, ends_on date not null, message text not null default '', status public.request_status not null default 'pending', created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(ends_on>=starts_on), check(starts_on>=current_date));
create index if not exists rental_dates_idx on public.rental_requests(listing_id,starts_on,ends_on) where status in ('pending','accepted');
create table if not exists public.conversations(id uuid primary key default gen_random_uuid(), listing_id uuid references public.listings(id) on delete set null, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.conversation_members(conversation_id uuid not null references public.conversations(id) on delete cascade,user_id uuid not null references public.profiles(id) on delete cascade,joined_at timestamptz not null default now(),primary key(conversation_id,user_id));
create table if not exists public.messages(id uuid primary key default gen_random_uuid(),conversation_id uuid not null references public.conversations(id) on delete cascade,sender_id uuid not null references public.profiles(id) on delete cascade,content text not null check(length(trim(content)) between 1 and 4000),created_at timestamptz not null default now(),read_at timestamptz);
create index if not exists messages_conversation_idx on public.messages(conversation_id,created_at);
create table if not exists public.notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,kind text not null,body text not null,read_at timestamptz,created_at timestamptz not null default now());
create table if not exists public.activity_events(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,kind text not null,description text not null,status text not null default 'completed',entity_id uuid,created_at timestamptz not null default now());

alter table public.profiles enable row level security; alter table public.listings enable row level security; alter table public.listing_images enable row level security;
alter table public.offers enable row level security; alter table public.trade_requests enable row level security; alter table public.rental_requests enable row level security;
alter table public.conversations enable row level security; alter table public.conversation_members enable row level security; alter table public.messages enable row level security; alter table public.notifications enable row level security; alter table public.activity_events enable row level security;
drop policy if exists "Profiles are public to authenticated users" on public.profiles;
create policy "Profiles are public to authenticated users" on public.profiles for select to authenticated using(true);
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
drop policy if exists "Available listings are public" on public.listings;
create policy "Available listings are public" on public.listings for select using(status='available' or seller_id=auth.uid());
drop policy if exists "Create own listings" on public.listings;
create policy "Create own listings" on public.listings for insert to authenticated with check(seller_id=auth.uid());
drop policy if exists "Update own listings" on public.listings;
create policy "Update own listings" on public.listings for update to authenticated using(seller_id=auth.uid()) with check(seller_id=auth.uid());
drop policy if exists "Delete own listings" on public.listings;
create policy "Delete own listings" on public.listings for delete to authenticated using(seller_id=auth.uid());
drop policy if exists "Listing images public read" on public.listing_images;
create policy "Listing images public read" on public.listing_images for select using(exists(select 1 from public.listings l where l.id=listing_id and (l.status='available' or l.seller_id=auth.uid())));
drop policy if exists "Owners manage listing images" on public.listing_images;
create policy "Owners manage listing images" on public.listing_images for all to authenticated using(exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid())) with check(exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid()));
drop policy if exists "Participants view offers" on public.offers;
create policy "Participants view offers" on public.offers for select to authenticated using(buyer_id=auth.uid() or exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid()));
drop policy if exists "Buyers create own offers" on public.offers;
create policy "Buyers create own offers" on public.offers for insert to authenticated with check(buyer_id=auth.uid() and exists(select 1 from public.listings l where l.id=listing_id and l.seller_id<>auth.uid() and l.status='available'));
drop policy if exists "Participants view trades" on public.trade_requests;
create policy "Participants view trades" on public.trade_requests for select to authenticated using(requester_id=auth.uid() or exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid()));
drop policy if exists "Users create own trades" on public.trade_requests;
create policy "Users create own trades" on public.trade_requests for insert to authenticated with check(requester_id=auth.uid() and exists(select 1 from public.listings l where l.id=listing_id and l.seller_id<>auth.uid() and l.transaction_type='barter' and l.status='available'));
drop policy if exists "Participants view rentals" on public.rental_requests;
create policy "Participants view rentals" on public.rental_requests for select to authenticated using(renter_id=auth.uid() or exists(select 1 from public.listings l where l.id=listing_id and l.seller_id=auth.uid()));
drop policy if exists "Users request rentals" on public.rental_requests;
create policy "Users request rentals" on public.rental_requests for insert to authenticated with check(renter_id=auth.uid() and exists(select 1 from public.listings l where l.id=listing_id and l.seller_id<>auth.uid() and l.transaction_type='rental' and l.status='available'));
drop policy if exists "Participants see conversations" on public.conversations;
create policy "Participants see conversations" on public.conversations for select to authenticated using(exists(select 1 from public.conversation_members m where m.conversation_id=id and m.user_id=auth.uid()));
drop policy if exists "Member lists visible to members" on public.conversation_members;
create policy "Member lists visible to members" on public.conversation_members for select to authenticated using(exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=auth.uid()));
drop policy if exists "Members read messages" on public.messages;
create policy "Members read messages" on public.messages for select to authenticated using(exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=auth.uid()));
drop policy if exists "Members send messages as self" on public.messages;
create policy "Members send messages as self" on public.messages for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from public.conversation_members m where m.conversation_id=conversation_id and m.user_id=auth.uid()));
drop policy if exists "Users see own notifications" on public.notifications;
create policy "Users see own notifications" on public.notifications for select to authenticated using(user_id=auth.uid());
drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications" on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists "Users see own activity" on public.activity_events;
create policy "Users see own activity" on public.activity_events for select to authenticated using(user_id=auth.uid());

-- Owner-only decisions serialize competing acceptances and enforce date overlap checks.
create or replace function public.decide_offer(request_id uuid, decision text) returns void language plpgsql security definer set search_path=public as $$
declare o public.offers; l public.listings;
begin if decision not in ('accepted','rejected') then raise exception 'Invalid decision'; end if; select * into o from public.offers where id=request_id for update; select * into l from public.listings where id=o.listing_id for update; if auth.uid() is null or l.seller_id<>auth.uid() then raise exception 'Only the listing owner can decide'; end if; if o.status<>'pending' or l.status<>'available' then raise exception 'Request is no longer open'; end if; update public.offers set status=decision,updated_at=now() where id=o.id; if decision='accepted' then update public.listings set status='reserved',updated_at=now() where id=l.id; update public.offers set status='rejected',updated_at=now() where listing_id=l.id and id<>o.id and status='pending'; end if; insert into public.activity_events(user_id,kind,description,status,entity_id) values(o.buyer_id,'offer','Offer '||decision,decision,o.id),(l.seller_id,'offer','Offer '||decision,decision,o.id); end $$;
create or replace function public.decide_trade_request(request_id uuid, decision text) returns void language plpgsql security definer set search_path=public as $$
declare r public.trade_requests; l public.listings;
begin if decision not in ('accepted','rejected') then raise exception 'Invalid decision'; end if; select * into r from public.trade_requests where id=request_id for update; select * into l from public.listings where id=r.listing_id for update; if l.seller_id<>auth.uid() then raise exception 'Only the listing owner can decide'; end if; if r.status<>'pending' or l.status<>'available' then raise exception 'Request is no longer open'; end if; update public.trade_requests set status=decision,updated_at=now() where id=r.id; if decision='accepted' then update public.listings set status='reserved' where id=l.id; update public.trade_requests set status='rejected',updated_at=now() where listing_id=l.id and id<>r.id and status='pending'; end if; insert into public.activity_events(user_id,kind,description,status,entity_id) values(r.requester_id,'trade','Trade '||decision,decision,r.id),(l.seller_id,'trade','Trade '||decision,decision,r.id); end $$;
create or replace function public.decide_rental_request(request_id uuid, decision text) returns void language plpgsql security definer set search_path=public as $$
declare r public.rental_requests; l public.listings;
begin if decision not in ('accepted','rejected') then raise exception 'Invalid decision'; end if; select * into r from public.rental_requests where id=request_id for update; select * into l from public.listings where id=r.listing_id for update; if l.seller_id<>auth.uid() then raise exception 'Only the listing owner can decide'; end if; if r.status<>'pending' then raise exception 'Request is no longer open'; end if; if decision='accepted' and exists(select 1 from public.rental_requests x where x.listing_id=r.listing_id and x.id<>r.id and x.status='accepted' and daterange(x.starts_on,x.ends_on,'[]') && daterange(r.starts_on,r.ends_on,'[]')) then raise exception 'Dates overlap another accepted rental'; end if; update public.rental_requests set status=decision,updated_at=now() where id=r.id; insert into public.activity_events(user_id,kind,description,status,entity_id) values(r.renter_id,'rental','Rental '||decision,decision,r.id),(l.seller_id,'rental','Rental '||decision,decision,r.id); end $$;
revoke all on function public.decide_offer(uuid,text),public.decide_trade_request(uuid,text),public.decide_rental_request(uuid,text) from public;
grant execute on function public.decide_offer(uuid,text),public.decide_trade_request(uuid,text),public.decide_rental_request(uuid,text) to authenticated;


-- Create a private conversation and its initial message atomically.
create or replace function public.start_conversation(listing_id uuid, first_message text) returns uuid language plpgsql security definer set search_path=public as $$
declare l public.listings; c uuid;
begin
 if auth.uid() is null or length(trim(first_message)) not between 1 and 4000 then raise exception 'Sign in and enter a message'; end if;
 select * into l from public.listings where id=listing_id and status='available';
 if l.id is null or l.seller_id=auth.uid() then raise exception 'This listing cannot be contacted'; end if;
 select cm.conversation_id into c from public.conversation_members cm join public.conversation_members seller on seller.conversation_id=cm.conversation_id and seller.user_id=l.seller_id where cm.user_id=auth.uid() and exists(select 1 from public.conversations cv where cv.id=cm.conversation_id and cv.listing_id=l.id) limit 1;
 if c is null then insert into public.conversations(listing_id) values(l.id) returning id into c; insert into public.conversation_members(conversation_id,user_id) values(c,auth.uid()),(c,l.seller_id); end if;
 insert into public.messages(conversation_id,sender_id,content) values(c,auth.uid(),trim(first_message)); update public.conversations set updated_at=now() where id=c; return c;
end $$;
create or replace function public.send_message(conversation_id uuid, message_text text) returns uuid language plpgsql security definer set search_path=public as $$
declare m uuid;
begin if auth.uid() is null or length(trim(message_text)) not between 1 and 4000 or not exists(select 1 from public.conversation_members where conversation_members.conversation_id=send_message.conversation_id and user_id=auth.uid()) then raise exception 'Message not allowed'; end if;
 insert into public.messages(conversation_id,sender_id,content) values(send_message.conversation_id,auth.uid(),trim(message_text)) returning id into m; update public.conversations set updated_at=now() where id=send_message.conversation_id; return m; end $$;
revoke all on function public.start_conversation(uuid,text),public.send_message(uuid,text) from public;
grant execute on function public.start_conversation(uuid,text),public.send_message(uuid,text) to authenticated;

-- Storage setup: create a PUBLIC bucket named listing-images. Restrict uploads and mutations to the owner folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('listing-images','listing-images',true,8388608,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
drop policy if exists "Anyone can view listing photos" on storage.objects;
create policy "Anyone can view listing photos" on storage.objects for select using(bucket_id='listing-images');
drop policy if exists "Users upload to own folder" on storage.objects;
create policy "Users upload to own folder" on storage.objects for insert to authenticated with check(bucket_id='listing-images' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users manage own photos" on storage.objects;
create policy "Users manage own photos" on storage.objects for delete to authenticated using(bucket_id='listing-images' and (storage.foldername(name))[1]=auth.uid()::text);
