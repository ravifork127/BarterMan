-- Enforce one stored phone number per account.
-- Existing test numbers were cleared manually, so this does not delete user data.
create unique index if not exists private_profile_details_phone_unique
on public.private_profile_details (phone_number)
where phone_number is not null;
