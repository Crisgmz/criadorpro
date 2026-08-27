-- Criador Pro — empleomanía (`RF-NOM`).
--
-- Dos tablas: la plantilla del criadero y sus pagos. El neto se guarda porque
-- el recibo tiene que poder reimprimirse tal cual se emitió, pero **se calcula**
-- —base + bono − deducciones— y la restricción lo impone: nadie puede escribir
-- un neto que no cuadre con sus componentes.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

create table if not exists public.employees (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,

  name text not null,
  role text,
  phone text,

  -- Cédula. Sin `check`: `RV-17` la valida como advertencia, no como bloqueo, y
  -- hay trabajadores sin documento dominicano.
  document text,

  salary numeric(12,2) not null,
  frequency text not null,

  -- Quien se va deja de sumar al costo mensual, pero sus pagos siguen contando
  -- en los meses en que se hicieron.
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

create table if not exists public.payroll_payments (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,

  -- `restrict` y no `cascade`: borrar a un empleado no puede llevarse por
  -- delante los pagos que ya cuadraron un mes cerrado. La baja es lógica.
  employee_id uuid not null references public.employees(id) on delete restrict,

  period_start date not null,
  period_end date not null,

  base numeric(12,2) not null,
  bonus numeric(12,2) not null default 0,
  deductions numeric(12,2) not null default 0,
  net numeric(12,2) not null,

  method text not null,

  -- Gasto de nómina que este pago generó (`RS-06`). `set null` para que borrar
  -- el gasto no impida anular el pago.
  transaction_id uuid references public.transactions(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'employees_frequency_check') then
    alter table public.employees
      add constraint employees_frequency_check
      check (frequency in ('weekly', 'biweekly', 'monthly'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'employees_salary_check') then
    alter table public.employees
      add constraint employees_salary_check check (salary > 0);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'payroll_method_check') then
    alter table public.payroll_payments
      add constraint payroll_method_check check (method in ('cash', 'transfer', 'other'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'payroll_period_check') then
    alter table public.payroll_payments
      add constraint payroll_period_check check (period_end >= period_start);
  end if;

  -- `RV-15` — «El neto no puede ser negativo». La app lo comprueba antes de
  -- guardar; aquí queda impuesto para cualquier cliente, incluido uno mal
  -- escrito o una versión futura.
  if not exists (select 1 from pg_constraint where conname = 'payroll_net_check') then
    alter table public.payroll_payments
      add constraint payroll_net_check check (net >= 0 and net = base + bonus - deductions);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'payroll_amounts_check') then
    alter table public.payroll_payments
      add constraint payroll_amounts_check
      check (base > 0 and bonus >= 0 and deductions >= 0);
  end if;
end $$;

-- `payroll_payments(employee_id, period_start)` — el índice que pide el SRS:
-- sostiene el historial por empleado y la búsqueda del último período pagado.
create index if not exists payroll_employee_period_idx
  on public.payroll_payments (employee_id, period_start desc);

create index if not exists employees_owner_name_idx
  on public.employees (owner_id, name);

drop trigger if exists touch_employees_updated_at on public.employees;
create trigger touch_employees_updated_at
  before update on public.employees
  for each row execute function public.touch_updated_at();

drop trigger if exists touch_payroll_updated_at on public.payroll_payments;
create trigger touch_payroll_updated_at
  before update on public.payroll_payments
  for each row execute function public.touch_updated_at();

-- `RS-13` · `RNF-16` — el aislamiento lo impone la base, no la aplicación.
alter table public.employees enable row level security;
alter table public.payroll_payments enable row level security;

drop policy if exists "employees_select_own" on public.employees;
create policy "employees_select_own" on public.employees
  for select using (owner_id = auth.uid());

drop policy if exists "employees_insert_own" on public.employees;
create policy "employees_insert_own" on public.employees
  for insert with check (owner_id = auth.uid());

drop policy if exists "employees_update_own" on public.employees;
create policy "employees_update_own" on public.employees
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "employees_delete_own" on public.employees;
create policy "employees_delete_own" on public.employees
  for delete using (owner_id = auth.uid());

drop policy if exists "payroll_select_own" on public.payroll_payments;
create policy "payroll_select_own" on public.payroll_payments
  for select using (owner_id = auth.uid());

drop policy if exists "payroll_insert_own" on public.payroll_payments;
create policy "payroll_insert_own" on public.payroll_payments
  for insert with check (owner_id = auth.uid());

drop policy if exists "payroll_update_own" on public.payroll_payments;
create policy "payroll_update_own" on public.payroll_payments
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "payroll_delete_own" on public.payroll_payments;
create policy "payroll_delete_own" on public.payroll_payments
  for delete using (owner_id = auth.uid());
