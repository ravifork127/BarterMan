drop function if exists public.request_to_buy(uuid);
create function public.request_to_buy(target_listing_id uuid)
returns uuid
language sql
security definer
set search_path = public
as $function$
  with candidate as materialized (
    select l.id, l.title, l.price
    from public.listings l
    where l.id = target_listing_id
      and l.status = 'available'
      and l.transaction_type = 'sale'
      and l.price is not null
      and l.seller_id <> auth.uid()
      and auth.uid() is not null
    for update
  ), saved as (
    insert into public.offers as existing_offer(listing_id, buyer_id, amount, message)
    select c.id, auth.uid(), c.price, 'Purchase request at listed price'
    from candidate c
    on conflict on constraint offers_listing_id_buyer_id_key
    do update set amount = excluded.amount,
                  message = excluded.message,
                  updated_at = now()
    where existing_offer.status = 'pending'
    returning id, listing_id, buyer_id
  ), history as (
    insert into public.activity_events(user_id, kind, description, status, entity_id)
    select s.buyer_id, 'purchase', 'Requested to buy ' || c.title, 'pending', s.id
    from saved s join candidate c on c.id = s.listing_id
    returning entity_id
  )
  select saved.id from saved join history on history.entity_id = saved.id;
$function$;
revoke all on function public.request_to_buy(uuid) from public;
grant execute on function public.request_to_buy(uuid) to authenticated;
