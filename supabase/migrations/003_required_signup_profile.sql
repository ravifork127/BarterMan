alter table public.profiles add column if not exists semester smallint check(semester between 1 and 12);

create or replace function public.create_profile() returns trigger language plpgsql security definer set search_path=public as $$
declare profile_id uuid;
begin
 insert into public.profiles(id,display_name,semester)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),nullif(new.raw_user_meta_data->>'semester','')::smallint)
 on conflict(id) do update set display_name=excluded.display_name,semester=excluded.semester
 returning id into profile_id;
 insert into public.private_profile_details(user_id,phone_number)
 values(new.id,nullif(new.raw_user_meta_data->>'phone_number',''))
 on conflict(user_id) do update set phone_number=excluded.phone_number,updated_at=now();
 return new;
end $$;
