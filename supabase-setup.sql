-- IB 학습자상 알아보기 - Supabase 데이터베이스 설정
-- Supabase 대시보드 > SQL Editor > New query 에서 아래 내용을 붙여넣고 실행하세요

-- 1. 학급 테이블
create table if not exists classrooms (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  student_count integer not null check (student_count >= 1),
  group_count integer not null default 5 check (group_count >= 1),
  created_at timestamptz default now()
);

-- 2. 학생 응답 테이블
create table if not exists student_responses (
  id uuid default gen_random_uuid() primary key,
  classroom_id uuid not null references classrooms(id) on delete cascade,
  seat_number integer not null,
  personal_answers jsonb default '{}',
  group_profile_id text default 'caring',
  group_def text default '',
  group_submitted boolean default false,
  self_scores jsonb default '{}',
  self_submitted boolean default false,
  updated_at timestamptz default now(),
  unique(classroom_id, seat_number)
);

-- 3. 반 전체 의미 테이블 (교사 관리)
create table if not exists class_meanings (
  id uuid default gen_random_uuid() primary key,
  classroom_id uuid not null references classrooms(id) on delete cascade,
  profile_id text not null,
  meaning text default '',
  updated_at timestamptz default now(),
  unique(classroom_id, profile_id)
);

-- 4. 인덱스 (실시간 필터 성능)
create index if not exists idx_sr_classroom on student_responses(classroom_id);
create index if not exists idx_cm_classroom on class_meanings(classroom_id);

-- 5. updated_at 자동 갱신 트리거
create or replace function set_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists trg_sr_updated_at on student_responses;
create trigger trg_sr_updated_at
  before update on student_responses
  for each row execute function set_updated_at();

drop trigger if exists trg_cm_updated_at on class_meanings;
create trigger trg_cm_updated_at
  before update on class_meanings
  for each row execute function set_updated_at();

-- 6. Row Level Security (인증 없이 공개 접근)
alter table classrooms enable row level security;
alter table student_responses enable row level security;
alter table class_meanings enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where tablename='classrooms' and policyname='public_classrooms') then
    create policy "public_classrooms" on classrooms for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='student_responses' and policyname='public_responses') then
    create policy "public_responses" on student_responses for all using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where tablename='class_meanings' and policyname='public_meanings') then
    create policy "public_meanings" on class_meanings for all using (true) with check (true);
  end if;
end $$;

-- 7. 실시간 활성화
alter publication supabase_realtime add table student_responses;
alter publication supabase_realtime add table class_meanings;
alter publication supabase_realtime add table classrooms;

-- 8. 신규 컬럼 (기존 DB에 이미 테이블이 있다면 아래 줄들만 실행)
alter table classrooms add column if not exists group_assignments jsonb default '{}';
alter table student_responses add column if not exists group_editing boolean default false;
