-- ==========================================
-- SCRIPT DE ESTRUTURA INICIAL DO BANCO DE DADOS (SUPABASE)
-- Execute este script no "SQL Editor" do painel do seu projeto Supabase.
-- ==========================================

-- 1. Criar a Tabela Pública de Perfis
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  name text not null,
  username text unique not null,
  streak integer default 0 not null check (streak >= 0),
  is_casual boolean default false not null,
  avatar text default 'psychology' not null,
  best_score_memory integer,
  last_play_date date,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- 2. Habilitar o Row Level Security (RLS)
alter table public.profiles enable row level security;

-- 3. Criar Políticas de RLS
-- Permitir que qualquer pessoa veja os perfis (útil para ranking, compartilhamento e busca de amigos)
create policy "Qualquer pessoa pode visualizar perfis"
  on public.profiles for select
  using (true);

-- Permitir que os usuários apenas alterem o seu próprio perfil
create policy "Usuários podem atualizar seu próprio perfil"
  on public.profiles for update
  using (auth.uid() = id);

-- 4. Função Trigger para Criação Automática do Perfil após Sign Up
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, name, username, streak, is_casual, avatar)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', 'Usuário Sinapse'),
    coalesce(new.raw_user_meta_data ->> 'username', 'user_' || substring(new.id::text from 1 for 8)),
    0,
    false,
    'psychology'
  );
  return new;
end;
$$ language plpgsql security definer;

-- Associar a função trigger ao evento de criação de novos usuários em auth.users
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. Função Segura (Security Definer) para Exclusão de Conta pelo Aplicativo
-- Como o SDK cliente do Supabase não permite deletar o auth.users diretamente,
-- esta função executada no lado do servidor com privilégios elevados resolve isso com segurança.
create or replace function public.delete_user_account()
returns void as $$
declare
  current_user_id uuid;
begin
  -- Recupera o ID do usuário atualmente autenticado que chamou a função
  current_user_id := auth.uid();
  
  if current_user_id is null then
    raise exception 'Não autorizado. Nenhum usuário autenticado encontrado na sessão.';
  end if;
  
  -- Exclui o registro na tabela auth.users
  -- (Isso irá apagar automaticamente o profile devido ao 'on delete cascade')
  delete from auth.users where id = current_user_id;
end;
$$ language plpgsql security definer;
