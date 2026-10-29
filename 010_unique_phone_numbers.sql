-- User requested a clean phone-number start: clear stored test numbers, preserve accounts.
update public.private_profile_details
set phone_number = null, updated_at = now()
where phone_number is not null;

-- From now on each account can claim a phone number only once.
create unique index if not exists private_profile_details_phone_unique
on public.private_profile_details (phone_number)
where phone_number is not null;
