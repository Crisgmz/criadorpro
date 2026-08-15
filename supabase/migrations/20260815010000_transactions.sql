-- Criador Pro — contabilidad (`RF-CON`).
--
-- El importe es `numeric(12,2)` y **siempre positivo**: el signo lo pone el
-- tipo del movimiento, no el importe. Un gasto negativo sumaría al balance.
--
-- Idempotente: se puede ejecutar dos veces sin romper nada.

create table if not exists public.transactions (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,

  type text not null,
  category text not null,
  amount numeric(12,2) not null,
  date date not null,
  description text,

  -- Ejemplar relacionado. `on delete set null` y no `cascade`: vender un
  -- ejemplar y luego borrarlo no puede llevarse por delante el ingreso.
  bird_id uuid references public.birds(id) on delete set null,

  recurrence text not null default 'none',
  recurrence_source_id uuid references public.transactions(id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_deleted boolean not null default false
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'transactions_type_check') then
    alter table public.transactions
      add constraint transactions_type_check check (type in ('income', 'expense'));
  end if;

  if not exists (select 1 from pg_constraint where conname = 'transactions_amount_check') then
    alter table public.transactions
      add constraint transactions_amount_check check (amount > 0);
  end if;

  if not exists (select 1 from pg_constraint where conname = 'transactions_recurrence_check') then
    alter table public.transactions
      add constraint transactions_recurrence_check
      check (recurrence in ('none', 'weekly', 'biweekly', 'monthly'));
  end if;

  -- Catálogo cerrado (`RF-CON-02`). Añadir una categoría exige migración, que
  -- es justo lo que se quiere: el usuario no crea las suyas.
  if not exists (select 1 from pg_constraint where conname = 'transactions_category_check') then
    alter table public.transactions
      add constraint transactions_category_check check (
        category in (
          'bird_sale', 'breeding_service', 'egg_sale', 'other_income',
          'feed', 'medicine', 'payroll', 'transport', 'maintenance',
          'bird_purchase', 'utilities', 'other_expense'
        )
      );
  end if;

  -- La categoría tiene que pertenecer al tipo: un «alimento» marcado como
  -- ingreso rompería el desglose mensual.
  if not exists (select 1 from pg_constraint where conname = 'transactions_category_type_check') then
    alter table public.transactions
      add constraint transactions_category_type_check check (
        (type = 'income' and category in ('bird_sale', 'breeding_service', 'egg_sale', 'other_income'))
        or
        (type = 'expense' and category in (
          'feed', 'medicine', 'payroll', 'transport', 'maintenance',
          'bird_purchase', 'utilities', 'other_expense'
        ))
      );
  end if;
end $$;

-- `transactions(owner_id, date)` — el índice que pide el SRS: sostiene el
-- cierre mensual, que es la consulta que más se repite.
create index if not exists transactions_owner_date_idx
  on public.transactions (owner_id, date desc);

create index if not exists transactions_bird_idx
  on public.transactions (bird_id) where bird_id is not null;

drop trigger if exists touch_transactions_updated_at on public.transactions;
create trigger touch_transactions_updated_at
  before update on public.transactions
  for each row execute function public.touch_updated_at();

-- `RS-13` · `RNF-16`.
alter table public.transactions enable row level security;

drop policy if exists "transactions_select_own" on public.transactions;
create policy "transactions_select_own" on public.transactions
  for select using (owner_id = auth.uid());

drop policy if exists "transactions_insert_own" on public.transactions;
create policy "transactions_insert_own" on public.transactions
  for insert with check (owner_id = auth.uid());

drop policy if exists "transactions_update_own" on public.transactions;
create policy "transactions_update_own" on public.transactions
  for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "transactions_delete_own" on public.transactions;
create policy "transactions_delete_own" on public.transactions
  for delete using (owner_id = auth.uid());
