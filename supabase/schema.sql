-- Tabela de observações astronômicas
create table public.observations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  titulo text not null,
  foto_url text,
  lat double precision,
  long double precision,
  data timestamptz not null default now(),
  descricao text
);

-- Habilitar RLS
alter table public.observations enable row level security;

-- Usuário só acessa os próprios registros
create policy "Usuário acessa próprios registros"
  on public.observations
  for all
  using (auth.uid() = user_id);

-- Bucket de Storage para fotos
insert into storage.buckets (id, name, public)
values ('observation-photos', 'observation-photos', false);

-- Política de storage: usuário acessa apenas suas próprias fotos
create policy "Upload própria foto"
  on storage.objects for insert
  with check (bucket_id = 'observation-photos' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "Leitura própria foto"
  on storage.objects for select
  using (bucket_id = 'observation-photos' and auth.uid()::text = (storage.foldername(name))[1]);
