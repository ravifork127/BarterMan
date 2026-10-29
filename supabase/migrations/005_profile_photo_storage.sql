-- Profile picture storage bucket and owner-only write access.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-photos','profile-photos',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
drop policy if exists "Public profile photo read" on storage.objects;
create policy "Public profile photo read" on storage.objects for select using(bucket_id='profile-photos');
drop policy if exists "Users upload own profile photo" on storage.objects;
create policy "Users upload own profile photo" on storage.objects for insert to authenticated with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users update own profile photo" on storage.objects;
create policy "Users update own profile photo" on storage.objects for update to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text) with check(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
drop policy if exists "Users delete own profile photo" on storage.objects;
create policy "Users delete own profile photo" on storage.objects for delete to authenticated using(bucket_id='profile-photos' and (storage.foldername(name))[1]=auth.uid()::text);
