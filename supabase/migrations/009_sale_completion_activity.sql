create or replace function public.decide_offer(request_id uuid, decision text) returns void language plpgsql security definer set search_path=public as $$
declare o public.offers; l public.listings; final_status public.request_status;
begin
 if decision not in ('accepted','rejected') then raise exception 'Invalid decision'; end if;
 select * into o from public.offers where id=request_id for update;
 select * into l from public.listings where id=o.listing_id for update;
 if auth.uid() is null or l.seller_id<>auth.uid() then raise exception 'Only the listing owner can decide'; end if;
 if o.status<>'pending' or l.status<>'available' then raise exception 'Request is no longer open'; end if;
 final_status := decision::public.request_status;
 update public.offers set status=final_status,updated_at=now() where id=o.id;
 if decision='accepted' then
   update public.listings set status='completed',updated_at=now() where id=l.id;
   update public.offers set status='rejected'::public.request_status,updated_at=now() where listing_id=l.id and id<>o.id and status='pending';
   insert into public.activity_events(user_id,kind,description,status,entity_id) values(o.buyer_id,'purchase','Bought: '||l.title,'completed',o.id),(l.seller_id,'sale','Sold: '||l.title,'completed',o.id);
 else
   insert into public.activity_events(user_id,kind,description,status,entity_id) values(o.buyer_id,'purchase','Buy request rejected: '||l.title,'rejected',o.id),(l.seller_id,'sale','Buy request rejected: '||l.title,'rejected',o.id);
 end if;
end $$;
