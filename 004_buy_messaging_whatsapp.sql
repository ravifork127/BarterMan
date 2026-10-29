-- Use a definer helper to avoid recursive RLS when checking membership.
create or replace function public.is_conversation_member(target_conversation uuid) returns boolean
language sql stable security definer set search_path=public set row_security=off as $$
 select exists(select 1 from public.conversation_members where conversation_id=target_conversation and user_id=auth.uid());
$$;
revoke all on function public.is_conversation_member(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;

drop policy if exists "Participants see conversations" on public.conversations;
drop policy if exists "Member lists visible to members" on public.conversation_members;
drop policy if exists "Members read messages" on public.messages;
drop policy if exists "Members send messages as self" on public.messages;
create policy "Participants see conversations" on public.conversations for select to authenticated using(public.is_conversation_member(id));
create policy "Member lists visible to members" on public.conversation_members for select to authenticated using(public.is_conversation_member(conversation_id));
create policy "Members read messages" on public.messages for select to authenticated using(public.is_conversation_member(conversation_id));
create policy "Members send messages as self" on public.messages for insert to authenticated with check(sender_id=auth.uid() and public.is_conversation_member(conversation_id));

create or replace function public.request_to_buy(listing_id uuid) returns uuid language plpgsql security definer set search_path=public as $$
declare l public.listings; request_uuid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in before requesting to buy'; end if;
 select * into l from public.listings where id=listing_id for update;
 if l.id is null or l.status<>'available' or l.transaction_type<>'sale' or l.price is null then raise exception 'This fixed-price listing is unavailable'; end if;
 if l.seller_id=auth.uid() then raise exception 'You cannot buy your own listing'; end if;
 insert into public.offers(listing_id,buyer_id,amount,message)
 values(l.id,auth.uid(),l.price,'Purchase request at listed price')
 on conflict(listing_id,buyer_id) do update set amount=excluded.amount,message=excluded.message,updated_at=now()
 where public.offers.status='pending' returning id into request_uuid;
 if request_uuid is null then raise exception 'You already have a resolved request for this listing'; end if;
 insert into public.activity_events(user_id,kind,description,status,entity_id) values(auth.uid(),'purchase','Requested to buy '||l.title,'pending',request_uuid);
 return request_uuid;
end $$;
revoke all on function public.request_to_buy(uuid) from public;
grant execute on function public.request_to_buy(uuid) to authenticated;

