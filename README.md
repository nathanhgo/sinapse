# 🧠 Sinapse

O **Sinapse** é um aplicativo gamificado e interativo desenvolvido em Flutter, projetado especificamente para auxiliar no desenvolvimento da memória, atenção e foco cognitivo. Unindo um design moderno, feedbacks visuais fluidos e uma infraestrutura robusta na nuvem, ele oferece um ambiente divertido e envolvente para exercícios cerebrais.

---

## ✨ Funcionalidades Principais

### 🎮 Mini-Jogos Integrados
* **Jogo da Memória (Memory Match)**:
  * **Contagem Regressiva**: Ticker animado de 3 segundos (`3`, `2`, `1`, `JÁ!`) para focar a mente antes de a partida iniciar.
  * **Design Premium**: Fundo azul profundo com uma estrela gigante desenhada sutilmente no background (`CustomPainter`) com apenas 5% de opacidade.
  * **Animação 3D de Virada de Cartas (Flip Card)**: Cartas com física realista em 3D usando matrizes de rotação e perspectiva (`Matrix4.setEntry(3, 2, 0.002)`), mantendo emojis em alta definição (`fontSize: 42`) centralizados sem efeito espelho.
  * **Recorde Pessoal (Trophy Badge)**: Salvamento reativo e inteligente do seu melhor placar (menor número de movimentos) no Supabase. O recorde é exibido na tela inicial através de um lindo troféu dourado (🏆).

### ⚡ Gamificação e Ofensivas (Streaks)
* **Sistema estilo Duolingo**:
  * Ao concluir qualquer mini-jogo, sua ofensiva (streak) é recalculada de forma inteligente com base no dia do calendário atual do aparelho.
  * Jogar em dias consecutivos acumula pontos de ofensiva.
  * Se você já jogou hoje, sua ofensiva é preservada sem acumular de forma duplicada.
  * Ficar sem jogar por um dia quebra a sequência e reseta a ofensiva para `1` na próxima partida.
* **Modo Casual**: Quer treinar sem a pressão da competitividade diária? Ative o *Modo Casual* nas configurações do perfil para ocultar completamente os balões e marcadores de ofensiva (fogos).

### 🎼 Música de Fundo e Controle Reativo
* **Música Ambiente**: Faixa de áudio ambiente looping (`background_music.mp3`) que favorece a concentração.
* **Inicialização Segura**: A música é iniciada somente após a renderização do primeiro frame da tela de carregamento (`addPostFrameCallback`), contornando bloqueios nativos de áudio de sistemas operacionais (Android/iOS) no boot.
* **Controle no Drawer**: Slider de volume deslizante a 60 FPS e botão de mudo com ícones dinâmicos no Drawer lateral. Se o som foi silenciado ou bloqueado no boot, subir o slider ou desmutar reinicia a música automaticamente!

### 👤 Gestão de Perfis & Customização
* **Seletor de Avatares**: Clique na foto do seu perfil para abrir uma paleta de diálogo premium e escolher diferentes emotes/ícones do Flutter para representá-lo. Atualiza de forma reativa no Drawer e no Perfil em tempo real!
* **Edição de Perfil**: Altere seu Nome Completo e Nome de Usuário (@) com validações robustas (evitando duplicidade de usernames).
* **Exclusão de Conta Segura**: Botão com confirmação dupla para excluir sua conta de forma definitiva através de uma RPC customizada em Postgres (utiliza cascata para remover com segurança as informações do Auth e do Profile).

---

## 🛠️ Arquitetura e Estrutura do Projeto

* `lib/main.dart`: Arquivo principal contendo a inicialização do Supabase, gerenciador de rotas e a tela de Splash Screen inteligente com persistência de login.
* `lib/homePage.dart`: Hub central e menu lateral (Drawer) com a listagem dos jogos, conquistas, recordes (troféus) e controladores de som reativos.
* `lib/profilePage.dart`: Painel de edição de dados pessoais, ativação do Modo Casual, seletor de avatares com emotes e exclusão segura da conta.
* `lib/memoryGamePage.dart`: Tabuleiro 4x4 do Jogo da Memória, com estrela pintada em vetor, contagem de movimentos, animador 3D de cartas e persistência de recordes.
* `lib/backgroundMusic.dart`: Singleton gerenciador de áudio global com audioplayers.
* `supabase_schema.sql`: Script SQL contendo a estrutura da tabela de perfis pública, triggers automatizados de cadastro do Auth, regras de segurança RLS e funções RPC.

---

## ⚙️ Instalação e Configuração

### 1. Requisitos Prévios
* SDK do Flutter instalado.
* Conta ativa no [Supabase](https://supabase.com/).

### 2. Configurando o Banco de Dados (Supabase)
Abra a aba **SQL Editor** do painel do seu projeto Supabase e execute integralmente as instruções contidas no arquivo:
📄 **[supabase_schema.sql](file:///home/admin/Pessoal/CodeInProgress/sinapse/supabase_schema.sql)**

### 3. Configurando as Variáveis de Ambiente
Crie um arquivo chamado `.env` na raiz do projeto contendo as seguintes chaves de acesso:

```env
SUPABASE_URL=https://SEU_PROJECT_ID.supabase.co
SUPABASE_ANON_KEY=SUA_ANON_KEY_AQUI
```

### 4. Configurando a Música de Fundo
Coloque o arquivo de música de sua preferência em formato `.mp3` no seguinte caminho:
📂 `assets/background_music.mp3`

---

## 🚀 Executando o Projeto

Após concluir as configurações, abra o terminal na raiz do projeto e execute os seguintes comandos:

```bash
# Obter dependências do projeto
flutter pub get

# Rodar o aplicativo localmente
flutter run
```

## Criar Aplicativo
```bash
docker run --rm --user 1000:1000 -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable bash -c "git config --global --add safe.directory /sdks/flutter && flutter build apk --release"
```

