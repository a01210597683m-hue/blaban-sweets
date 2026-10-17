-- Secure customer-owned support conversations and enable two-way chat with admins.
drop policy if exists "Visitors can create support conversations" on public.support_conversations;
drop policy if exists "Customers can view own support conversations" on public.support_conversations;
create policy "Customers can view own support conversations"
on public.support_conversations for select to authenticated
using (customer_user_id = (select auth.uid()));

drop policy if exists "Customers can create own support conversations" on public.support_conversations;
create policy "Customers can create own support conversations"
on public.support_conversations for insert to authenticated
with check (customer_user_id = (select auth.uid()));

drop policy if exists "Customers can update own active support conversations" on public.support_conversations;
create policy "Customers can update own active support conversations"
on public.support_conversations for update to authenticated
using (customer_user_id = (select auth.uid()))
with check (customer_user_id = (select auth.uid()) and status in ('open','waiting_human'));

drop policy if exists "Visitors can add support messages" on public.support_messages;
drop policy if exists "Customers and assistant can add messages to own conversations" on public.support_messages;
create policy "Customers and assistant can add messages to own conversations"
on public.support_messages for insert to authenticated
with check (
  sender_type in ('customer','assistant','system')
  and exists (
    select 1 from public.support_conversations c
    where c.id = conversation_id and c.customer_user_id = (select auth.uid())
  )
);

drop policy if exists "Admins can reply in support conversations" on public.support_messages;
create policy "Admins can reply in support conversations"
on public.support_messages for insert to authenticated
with check (
  sender_type = 'admin'
  and exists (select 1 from public.admin_users au where au.user_id = (select auth.uid()))
  and exists (select 1 from public.support_conversations c where c.id = conversation_id)
);

drop policy if exists "Customers can view messages in own support conversations" on public.support_messages;
create policy "Customers can view messages in own support conversations"
on public.support_messages for select to authenticated
using (
  exists (
    select 1 from public.support_conversations c
    where c.id = conversation_id and c.customer_user_id = (select auth.uid())
  )
);

drop policy if exists "Visitors can request human support" on public.support_handoffs;
drop policy if exists "Customers can request human support for own conversations" on public.support_handoffs;
create policy "Customers can request human support for own conversations"
on public.support_handoffs for insert to authenticated
with check (
  exists (
    select 1 from public.support_conversations c
    where c.id = conversation_id and c.customer_user_id = (select auth.uid())
  )
);

revoke all on public.support_conversations from anon;
revoke all on public.support_messages from anon;
revoke all on public.support_handoffs from anon;
grant select, insert, update on public.support_conversations to authenticated;
grant select, insert on public.support_messages to authenticated;
grant insert on public.support_handoffs to authenticated;
