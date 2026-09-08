create table if not exists classroom_courses (
  id uuid primary key default uuid_generate_v4(),
  teacher_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  section text,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists classroom_assignments (
  id uuid primary key default uuid_generate_v4(),
  course_id uuid not null references classroom_courses(id) on delete cascade,
  title text not null,
  description text,
  due_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists classroom_submissions (
  id uuid primary key default uuid_generate_v4(),
  assignment_id uuid not null references classroom_assignments(id) on delete cascade,
  student_id uuid not null references auth.users(id) on delete cascade,
  text text,
  submitted_at timestamptz,
  returned_at timestamptz,
  unique (assignment_id, student_id)
);

alter table classroom_courses enable row level security;
alter table classroom_assignments enable row level security;
alter table classroom_submissions enable row level security;

create policy "Teachers manage their courses"
  on classroom_courses for all
  using (auth.uid() = teacher_id)
  with check (auth.uid() = teacher_id);

create policy "Authenticated users can read courses"
  on classroom_courses for select
  using (auth.uid() is not null);

create policy "Authenticated users can read assignments"
  on classroom_assignments for select
  using (auth.uid() is not null);

create policy "Students manage their submissions"
  on classroom_submissions for all
  using (auth.uid() = student_id)
  with check (auth.uid() = student_id);

create index if not exists classroom_assignments_course_id_idx
  on classroom_assignments(course_id);

create index if not exists classroom_submissions_assignment_id_idx
  on classroom_submissions(assignment_id);
