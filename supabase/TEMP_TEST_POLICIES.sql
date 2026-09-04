-- TEMP_TEST_POLICIES.sql
--
-- TESTING ONLY. These policies intentionally let any browser holding your
-- Supabase publishable key read and insert survey-submissions objects.
-- Remove these policies as soon as the real login/auth flow is implemented.
-- NEVER put a service_role / secret key in Flutter web code.

create policy "TEMP survey admin read"
on storage.objects
for select
to anon
using (bucket_id = 'survey-submissions');

create policy "TEMP survey admin insert new versions"
on storage.objects
for insert
to anon
with check (bucket_id = 'survey-submissions');

-- Later, after auth exists, replace the policies above with authenticated-role
-- policies and whatever employee/admin authorization rule you choose.
--
-- drop policy "TEMP survey admin read" on storage.objects;
-- drop policy "TEMP survey admin insert new versions" on storage.objects;
