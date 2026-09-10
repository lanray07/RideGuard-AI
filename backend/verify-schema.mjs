import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

// Isolated PostgreSQL engine. No network, production database, or credentials.
const db = new PGlite();
await db.exec(`
  create role anon;
  create role authenticated;
  create schema auth;
  create table auth.users (id uuid primary key);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  grant usage on schema public, auth to authenticated, anon;
  grant execute on function auth.uid() to authenticated, anon;
  insert into auth.users values ('11111111-1111-1111-1111-111111111111'), ('22222222-2222-2222-2222-222222222222');
`);
await db.exec(await readFile(new URL('./schema-draft.sql', import.meta.url), 'utf8'));
let checks = 0;
function check(value, description) { assert.ok(value, description); checks++; console.log(`PASS ${description}`); }
async function asUser(id) {
  await db.exec(`reset role; set role authenticated; select set_config('request.jwt.claim.sub', '${id}', false);`);
}
async function denied(sql, description) {
  let rejected = false;
  try { await db.exec(sql); } catch { rejected = true; }
  check(rejected, description);
}
const alice = '11111111-1111-1111-1111-111111111111';
const bob = '22222222-2222-2222-2222-222222222222';
const ride = '33333333-3333-3333-3333-333333333333';
await asUser(alice);
await db.exec(`insert into public.rg_profiles values ('${alice}', 'Alice', now());
  insert into public.rg_rides(id, user_id, destination_label, expected_arrival, status)
  values ('${ride}', '${alice}', 'Home', now() + interval '30 minutes', 'riding');`);
check((await db.query('select * from public.rg_rides')).rows.length === 1, 'owner can create and read ride');
await denied(`update public.rg_rides set user_id = '${bob}' where id = '${ride}'`, 'owner cannot transfer ride to another user');
await denied(`insert into public.rg_profiles values ('${bob}', 'Impersonated', now())`, 'cannot insert another user profile');
await denied(`insert into public.rg_subscriptions values ('${alice}', 'pro', now() + interval '1 year', null, now())`, 'client cannot mint entitlement');
await denied(`insert into public.rg_live_rides(user_id,ride_id,expires_at) values ('${alice}','${ride}',now()+interval '1 hour')`, 'client cannot create sharing session directly');
await denied(`select * from rideguard_private.sharing_tokens`, 'client cannot read token hashes');
await denied(`insert into public.rg_community_observations(category,approximate_latitude,approximate_longitude,observed_at,expires_at,description) values ('pothole',51,0,now(),now()+interval '1 day','unmoderated')`, 'client cannot publish unmoderated observation');
await denied(`insert into public.rg_notification_preferences(user_id,contact_escalation_enabled) values ('${alice}',true)`, 'escalation requires explicit consent timestamp');
await asUser(bob);
check((await db.query('select * from public.rg_rides')).rows.length === 0, 'other user cannot see ride');
await db.exec(`update public.rg_rides set destination_label = 'Stolen' where id = '${ride}'; delete from public.rg_rides where id = '${ride}';`);
await denied(`insert into public.rg_ride_segments(user_id,ride_id,recorded_at,latitude,longitude,accuracy_metres) values ('${bob}','${ride}',now(),51,0,10)`, 'composite foreign key rejects attaching location to another user ride');
await asUser(alice);
check((await db.query(`select destination_label from public.rg_rides where id = '${ride}'`)).rows[0].destination_label === 'Home', 'cross-user update/delete changed nothing');
await db.exec(`reset role; set role anon;`);
await denied('select * from public.rg_rides', 'anonymous role cannot read rides');
await denied('select * from public.rg_trusted_contacts', 'anonymous role cannot read contacts');
await db.exec('reset role');
const tables = (await db.query(`select relname, relrowsecurity from pg_class join pg_namespace n on n.oid=relnamespace where n.nspname in ('public','rideguard_private') and relkind='r'`)).rows;
check(tables.length === 15 && tables.every(t => t.relrowsecurity), 'all 15 application tables enable RLS');
await asUser(alice);
await db.exec(`delete from public.rg_rides where id = '${ride}'`);
check((await db.query('select * from public.rg_rides')).rows.length === 0, 'owner can delete own ride');
console.log(`\n${checks} schema checks passed. This does not verify hosted Supabase configuration or server endpoints.`);
await db.close();
