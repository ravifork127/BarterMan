drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles for insert to authenticated with check(id=auth.uid());
-- Private bucket keeps profile photos visible only to their owner and trusted app flows.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
drop policy if exists "Users read own profile photos" on storage.objects;
create policy "Users read own profile photos" on storage.objects for select to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users upload own profile photos" on storage.objects;
create policy "Users upload own profile photos" on storage.objects for insert to authenticated with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users update own profile photos" on storage.objects;
create policy "Users update own profile photos" on storage.objects for update to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users delete own profile photos" on storage.objects;
create policy "Users delete own profile photos" on storage.objects for delete to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
