-- Ranking do jogo Tempo. Cole no Supabase → SQL Editor → Run.
create table ranking_tempo (
  id bigint generated always as identity primary key,
  data date not null,
  modo text not null check (modo in ('easy', 'hard')),
  nome text not null check (char_length(trim(nome)) between 1 and 20),
  pontos numeric(5,2) not null check (pontos between 0 and 50),
  criado_em timestamptz not null default now()
);

create index ranking_tempo_dia_modo on ranking_tempo (data, modo, pontos desc);

-- Qualquer visitante pode ver o ranking e adicionar um resultado,
-- mas ninguém pode alterar ou apagar resultados pelo site.
alter table ranking_tempo enable row level security;
create policy "ver ranking tempo" on ranking_tempo for select to anon using (true);
create policy "adicionar resultado tempo" on ranking_tempo for insert to anon with check (true);
