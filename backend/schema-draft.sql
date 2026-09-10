-- REVIEW DRAFT, not an applied migration. Target: Supabase PostgreSQL 15+.
-- Apply only in a new isolated project after running the supplied RLS tests.
begin;
create schema if not exists rideguard_private;
revoke all on schema rideguard_private from public, anon, authenticated;

create table public.rg_profiles (
    user_id uuid primary key references auth.users(id) on delete cascade,
    display_name text not null check (char_length(display_name) between 1 and 100),
    created_at timestamptz not null default now()
);
create table public.rg_rides (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    destination_label text not null check (char_length(destination_label) between 1 and 200),
    started_at timestamptz not null default now(),
    ended_at timestamptz,
    expected_arrival timestamptz not null,
    status text not null check (status in ('riding','overdue','arrived','completed')),
    distance_metres double precision check (distance_metres >= 0 and distance_metres < 10000000),
    unique (id, user_id),
    check (ended_at is null or ended_at >= started_at)
);
create table public.rg_ride_segments (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    ride_id uuid not null,
    recorded_at timestamptz not null,
    latitude double precision not null check (latitude between -90 and 90),
    longitude double precision not null check (longitude between -180 and 180),
    accuracy_metres double precision not null check (accuracy_metres between 0 and 100),
    foreign key (ride_id, user_id) references public.rg_rides(id, user_id) on delete cascade
);
create table public.rg_hazard_reports (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    category text not null check (category in ('pothole','roadworks','debris','blockedCycleLane','brokenGlass','poorSurface','flooding','poorLighting','dangerousJunction','closure','vehicleObstruction','other')),
    latitude double precision not null check (latitude between -90 and 90),
    longitude double precision not null check (longitude between -180 and 180),
    observed_at timestamptz not null,
    description text not null default '' check (char_length(description) <= 2000),
    severity smallint not null check (severity between 1 and 3),
    created_at timestamptz not null default now()
);
-- Published observations are separate from private author identity/history.
-- Only a moderated server job can create these; clients cannot self-publish.
create table public.rg_community_observations (
    id uuid primary key default gen_random_uuid(),
    category text not null,
    approximate_latitude double precision not null check (approximate_latitude between -90 and 90),
    approximate_longitude double precision not null check (approximate_longitude between -180 and 180),
    observed_at timestamptz not null,
    expires_at timestamptz not null,
    description text not null check (char_length(description) <= 2000),
    check (expires_at > observed_at)
);
create table rideguard_private.publication_sources (
    observation_id uuid primary key references public.rg_community_observations(id) on delete cascade,
    report_id uuid not null references public.rg_hazard_reports(id) on delete cascade
);
create table public.rg_hazard_confirmations (
    user_id uuid not null references auth.users(id) on delete cascade,
    observation_id uuid not null references public.rg_community_observations(id) on delete cascade,
    verdict text not null check (verdict in ('stillThere','cleared','incorrect')),
    updated_at timestamptz not null default now(),
    primary key (user_id, observation_id)
);
create table public.rg_trusted_contacts (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    display_name text not null check (char_length(display_name) between 1 and 100),
    encrypted_contact bytea not null,
    unique (id, user_id)
);
create table public.rg_live_rides (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    ride_id uuid not null,
    expires_at timestamptz not null,
    revoked_at timestamptz,
    sharing_location boolean not null default false,
    last_update timestamptz,
    unique (id, user_id),
    foreign key (ride_id, user_id) references public.rg_rides(id, user_id) on delete cascade
);
create table rideguard_private.sharing_tokens (
    token_digest bytea primary key,
    live_ride_id uuid not null references public.rg_live_rides(id) on delete cascade,
    expires_at timestamptz not null,
    revoked_at timestamptz,
    check (octet_length(token_digest) = 32)
);
create table public.rg_route_scores (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    route_fingerprint text not null,
    model_version text not null,
    score smallint check (score between 0 and 100),
    confidence text not null check (confidence in ('unavailable','low','moderate','high')),
    missing_data jsonb not null default '[]',
    calculated_at timestamptz not null default now(),
    unique (id, user_id)
);
create table public.rg_route_factors (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    score_id uuid not null,
    kind text not null,
    source text not null,
    observed_at timestamptz not null,
    expires_at timestamptz not null,
    coverage numeric not null check (coverage > 0 and coverage <= 1),
    indicator numeric not null check (indicator between 0 and 100),
    evidence jsonb not null,
    foreign key (score_id, user_id) references public.rg_route_scores(id, user_id) on delete cascade,
    unique (score_id, kind)
);
create table public.rg_check_ins (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    ride_id uuid not null,
    contact_id uuid not null,
    idempotency_key uuid not null unique,
    delivery_status text not null default 'pending' check (delivery_status in ('pending','sent','delivered','failed')),
    requested_at timestamptz not null default now(),
    delivered_at timestamptz,
    foreign key (ride_id, user_id) references public.rg_rides(id, user_id) on delete cascade,
    foreign key (contact_id, user_id) references public.rg_trusted_contacts(id, user_id) on delete cascade
);
create table public.rg_notification_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    grace_minutes integer not null default 10 check (grace_minutes between 5 and 60),
    contact_escalation_enabled boolean not null default false,
    escalation_delay_minutes integer not null default 15 check (escalation_delay_minutes between 5 and 120),
    explicit_consent_at timestamptz,
    check (not contact_escalation_enabled or explicit_consent_at is not null)
);
create table public.rg_subscriptions (
    user_id uuid primary key references auth.users(id) on delete cascade,
    product_id text not null,
    expires_at timestamptz not null,
    revoked_at timestamptz,
    verified_at timestamptz not null
);

-- Owner CRUD for private user-authored records. Composite FKs prevent cross-owner joins.
do $$ declare table_name text; begin
    foreach table_name in array array['rg_profiles','rg_rides','rg_ride_segments','rg_hazard_reports','rg_hazard_confirmations','rg_trusted_contacts','rg_notification_preferences'] loop
        execute format('alter table public.%I enable row level security', table_name);
        execute format('revoke all on public.%I from public, anon, authenticated', table_name);
        execute format('grant select, insert, update, delete on public.%I to authenticated', table_name);
        execute format('create policy owner_select on public.%I for select to authenticated using ((select auth.uid()) = user_id)', table_name);
        execute format('create policy owner_insert on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', table_name);
        execute format('create policy owner_update on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', table_name);
        execute format('create policy owner_delete on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', table_name);
        execute format('create index on public.%I (user_id)', table_name);
    end loop;
    -- Lifecycle, delivery, scoring and entitlements are server controlled.
    foreach table_name in array array['rg_live_rides','rg_route_scores','rg_route_factors','rg_check_ins','rg_subscriptions'] loop
        execute format('alter table public.%I enable row level security', table_name);
        execute format('revoke all on public.%I from public, anon, authenticated', table_name);
        execute format('grant select on public.%I to authenticated', table_name);
        execute format('create policy owner_read on public.%I for select to authenticated using ((select auth.uid()) = user_id)', table_name);
        execute format('create index on public.%I (user_id)', table_name);
    end loop;
end $$;
alter table public.rg_community_observations enable row level security;
revoke all on public.rg_community_observations from public, anon, authenticated;
grant select on public.rg_community_observations to authenticated;
create policy current_reports on public.rg_community_observations for select to authenticated using (expires_at > now());
alter table rideguard_private.sharing_tokens enable row level security;
alter table rideguard_private.publication_sources enable row level security;
revoke all on all tables in schema rideguard_private from public, anon, authenticated;
-- No direct public RPC or security-definer functions. Authenticated server endpoints
-- must validate token/session, ownership, consent, limits and idempotency before writes.
commit;
