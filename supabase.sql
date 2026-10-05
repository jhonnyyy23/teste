-- Tabela do ranking. Cole tudo no Supabase → SQL Editor → Run.
create table ranking (
  id bigint generated always as identity primary key,
  data date not null,
  nivel text not null check (nivel in ('very-easy', 'easy', 'medium', 'hard', 'very-hard', 'ultra-hard')),
  nome text not null check (char_length(trim(nome)) between 1 and 20),
  tempo integer not null check (tempo between 1 and 86400),
  criado_em timestamptz not null default now()
);

create index ranking_dia_nivel on ranking (data, nivel, tempo);

-- Qualquer visitante pode ver o ranking e adicionar um resultado,
-- mas ninguém pode alterar ou apagar resultados pelo site.
alter table ranking enable row level security;
create policy "ver ranking" on ranking for select to anon using (true);
create policy "adicionar resultado" on ranking for insert to anon with check (true);
