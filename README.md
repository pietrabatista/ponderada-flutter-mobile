# SkySight

Aplicativo mobile desenvolvido em Flutter para registro de observações astronômicas. O usuário pode fotografar o céu, registrar o que viu (Lua, planetas, meteoros, ISS etc.), ver a Foto Astronômica do Dia da NASA e acompanhar a posição da Estação Espacial Internacional em tempo real.

---

## Proposta da aplicação

### Problema
Amantes de astronomia não têm uma forma simples e integrada de registrar suas observações pessoais. Aplicativos existentes são complexos ou focados em profissionais, faltam soluções que unam **captura de foto + GPS + dados astronômicos em tempo real** numa interface acessível.

### Público-alvo
Estudantes, curiosos e entusiastas de astronomia que querem manter um diário visual das próprias observações do céu.

### O que o app faz
- **Registra observações**: foto tirada na hora, localização GPS automática convertida em Bairro — Cidade via geocodificação reversa, título com autocomplete (Lua, Marte, Saturno, ISS…) e descrição livre
- **Foto Astronômica do Dia (APOD)**: integração com a API da NASA, com cache local; quando é imagem pode ser expandida em modal com zoom; quando é vídeo (YouTube ou MP4 direto) toca em loop dentro do próprio app; descrição exibida com opção "Ver mais"
- **ISS em tempo real**: posição atual atualizada automaticamente a cada 5 segundos, com localização convertida para País — Cidade (ou nome do oceano/mar quando sobre água); notificação disparada quando a ISS entra em raio de 100 km de São Paulo
- **Histórico**: listagem de todos os registros com busca por nome, filtro por período, swipe para excluir; toque na foto abre modal expandível com zoom (até 5×)
- **Notificações**: passagem da ISS agendada automaticamente, APOD diário às 9h e alerta de proximidade da ISS sobre São Paulo (cooldown de 10 min para evitar spam)
- **Perfil**: toggles para ativar/desativar cada tipo de notificação, logout, e seção de desenvolvimento com botões de teste

---

## Tecnologias utilizadas

| Tecnologia | Uso |
|---|---|
| Flutter (Dart) | Framework mobile — Android e iOS |
| Supabase | Auth (email/senha), banco de dados (PostgreSQL), Storage (fotos) |
| NASA APOD API | Foto Astronômica do Dia |
| Open Notify API (`iss-now.json`) | Posição atual da ISS (~400 ms) |
| wheretheiss.at API | Fallback de posição da ISS |
| Nominatim / OpenStreetMap | Geocodificação reversa (lat/lon → País — Cidade / Bairro — Cidade) |
| BigDataCloud | Fallback de geocodificação para oceanos e mares |
| `flutter_local_notifications` | Notificações locais (agendadas e imediatas) |
| `geolocator` | GPS do dispositivo (com cache de 2 min) |
| `image_picker` | Câmera / galeria |
| `share_plus` | Compartilhamento nativo do sistema |
| `shared_preferences` | Cache de preferências e metadados do APOD |
| `path_provider` | Armazenamento local da imagem do APOD |
| `timezone` | Agendamento de notificações com fuso horário correto |
| `flutter_svg` | Renderização da logo SkySight em SVG |
| `youtube_player_flutter` | Player de vídeos YouTube do APOD em loop |
| `video_player` | Player de vídeos MP4 diretos do APOD em loop |

---

## Setup e execução

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.11
- Conta no [Supabase](https://supabase.com)

### 1. Clonar o repositório
```bash
git clone https://github.com/pietrabatista/ponderada-flutter-mobile.git
cd ponderada-flutter-mobile
```

### 2. Configurar o Supabase

#### Criar o projeto
1. Acesse [supabase.com](https://supabase.com) e crie um novo projeto
2. Vá em **SQL Editor** e execute o conteúdo de [`supabase/schema.sql`](supabase/schema.sql) para criar a tabela e as políticas de segurança

#### Configurar credenciais no app
Abra `lib/main.dart` e substitua as constantes com as credenciais do seu projeto Supabase:

```dart
const _supabaseUrl = 'https://SEU_PROJETO.supabase.co';
const _supabaseAnonKey = 'sua_anon_key_aqui';
```

As credenciais ficam em **Project Settings → API** no painel do Supabase.

### 3. Instalar dependências
```bash
flutter pub get
```

### 4. Rodar o app

**Android (dispositivo físico ou emulador):**
```bash
flutter run
```

**iOS (requer Mac com Xcode):**
```bash
cd ios && pod install && cd ..
flutter run
```

> **Permissões necessárias no dispositivo:** localização (para ISS), câmera (para registros) e notificações (para alertas de passagem). O app solicita cada permissão na primeira vez que a funcionalidade é usada.

---

## Estrutura do projeto

```
lib/
├── main.dart                           # Inicialização do app e Supabase
├── models/
│   ├── apod_model.dart                 # Modelo da resposta da NASA
│   └── observation_model.dart          # Modelo de observação do banco
├── screens/
│   ├── auth_screen.dart                # Login e cadastro com logo SVG
│   ├── main_screen.dart                # BottomNavigationBar principal
│   ├── home_screen.dart                # APOD + ISS (5s refresh) + registros recentes
│   ├── history_screen.dart             # Histórico com busca e filtro
│   ├── observation_detail_screen.dart  # Detalhe com modal de imagem e geocodificação
│   ├── new_observation_screen.dart     # Câmera + GPS
│   ├── observation_form_screen.dart    # Formulário de registro
│   └── profile_screen.dart            # Perfil, notificações e botões de debug
├── services/
│   ├── supabase_service.dart           # Inicialização do Supabase
│   ├── nasa_service.dart               # Integração com API da NASA
│   ├── iss_service.dart                # Rastreamento da ISS com fallback e override de debug
│   ├── geocoding_service.dart          # Geocodificação reversa (Nominatim + BigDataCloud)
│   ├── observation_service.dart        # CRUD de observações
│   ├── notification_service.dart       # Notificações locais + verificação de proximidade ISS/SP
│   └── apod_cache_service.dart         # Cache local do APOD
├── widgets/
│   └── supabase_image.dart             # Widget que carrega imagens via signed URL
assets/
├── logo.svg                            # Logo SkySight (SVG)
└── icon.png                            # Ícone do app 1024×1024 (gerado pelo flutter_launcher_icons)
```

---

## Diário de desenvolvimento

### Dificuldade 1 — Credenciais do Supabase e o `.env` que sumia

**O problema:** Comecei usando `flutter_dotenv` para manter as credenciais do Supabase fora do código-fonte. Funcionou perfeitamente no computador de desenvolvimento, mas quando rodei no tablet, o app travava na tela inicial com `EmptyEnvFileError`. O arquivo `.env` estava listado no `.gitignore` e, ao rodar o app em outro dispositivo, ele simplesmente não existia. O Flutter tenta carregar o asset em runtime e falha silenciosamente, congelando o app.

**Como resolvi:** Removi completamente o `flutter_dotenv` e hardcodei as credenciais diretamente em `lib/main.dart`. Como o repositório é privado, essa é uma solução aceitável para o contexto acadêmico. A solução "correta" em produção seria usar variáveis de ambiente em CI/CD e injetá-las em build time com `--dart-define`.

---

### Dificuldade 2 — Build Android quebrando com `flutter_local_notifications`

**O problema:** Ao compilar para Android pela primeira vez com `flutter_local_notifications`, recebi um erro de build relacionado a `java.lang.invoke.MethodHandles`. A biblioteca usa APIs do Java 8 que não existem nativamente em versões antigas do Android. É necessário um processo chamado **core library desugaring** para fazer o backport dessas APIs.

**Como resolvi:** Três mudanças no `android/app/build.gradle.kts`:
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Além disso, o Android 13+ exige declaração explícita de permissões no `AndroidManifest.xml` que o Flutter não adiciona por padrão: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` e os `BroadcastReceiver`s do `flutter_local_notifications` para notificações agendadas sobreviverem a reinicializações do dispositivo.

---

### Dificuldade 3 — API da ISS retornando 404

**O problema:** A `api.open-notify.org/iss-pass.json` (previsão de passagens) retornou 404 durante o desenvolvimento — o endpoint foi descontinuado sem aviso. O código falhava silenciosamente e nunca mostrava dados da ISS na tela inicial.

**Como resolvi:** Troquei para `open-notify.org/iss-now.json`, que retorna a posição atual da ISS em tempo real (~400 ms). Também adicionei `api.wheretheiss.at/v1/satellites/25544` como fallback com timeout de 20 s. A lógica tenta a API principal e, em qualquer falha, cai automaticamente para o fallback. Somente se ambas falharem com `SocketException` é que o erro de "sem conexão" é exibido.

Para evitar sobrecarregar o hardware com chamadas de GPS a cada 5 s (o timer de refresh), adicionei um cache de posição com TTL de 2 minutos em `IssService._getPosition()`.

---

### Dificuldade 4 — Imagens do Supabase Storage não carregavam

**O problema:** As fotos dos registros não apareciam em nenhuma tela. O bucket estava configurado como **privado** no Supabase (por segurança, para que cada usuário acesse apenas suas próprias fotos), então as URLs geradas por `getPublicUrl` retornavam 403. Tentei adicionar `Authorization: Bearer <token>` manualmente no `Image.network`, mas o token estático ficava desatualizado após 1 hora de sessão, e algumas configurações de CDN rejeitavam o header.

**Como resolvi:** Criei o widget `SupabaseImage` que usa o SDK do Supabase para chamar `storage.from(bucket).createSignedUrl(path, 3600)`, gera uma URL temporária autenticada diretamente pelo SDK, sempre com o token de sessão atual e válida por 1 hora. Isso funciona independentemente de o bucket ser público ou privado, sem nenhuma configuração adicional.

---

### Dificuldade 5 — APOD retornando 503 por limite de requisições

**O problema:** A NASA limita a `DEMO_KEY` a 30 requisições por hora por IP. Durante o desenvolvimento intenso, com vários `flutter run` seguidos, o limite era atingido rapidamente e o card da Foto do Dia exibia erro. Além disso, o app chamava a API **toda vez** que abria a tela inicial, mesmo que a foto não tivesse mudado desde a última abertura.

**Como resolvi:** Implementei `ApodCacheService` com dois níveis de persistência:
- **Metadados** (título, URL, tipo de mídia, data) salvos no `SharedPreferences` com a data do dia (`YYYY-MM-DD`)
- **Arquivo de imagem** baixado em background e salvo em `getApplicationDocumentsDirectory()/apod_today.jpg`

Na abertura do app, verifica primeiro se o cache é do dia atual. Se sim, carrega instantaneamente sem tocar na API. Se a data mudou, faz a chamada e sobrescreve o cache. Isso reduziu as chamadas à API de "uma por abertura" para "uma por dia".

---

### Dificuldade 6 — Geocodificação reversa não funciona sobre oceanos

**O problema:** A ISS passa a maior parte do tempo sobre oceanos. A API Nominatim (OpenStreetMap) retorna `{"error": "Unable to geocode"}` para coordenadas no meio do Oceano Pacífico, por exemplo — o que fazia o card da ISS exibir as coordenadas brutas em vez de um nome legível.

**Como resolvi:** Implementei `GeocodingService` com duas etapas em cascata:
1. Tenta **Nominatim** com `zoom=10` (nível de cidade). Se retornar `error`, passa para o próximo.
2. Tenta **BigDataCloud** (`api.bigdatacloud.net/data/reverse-geocode-client`), que retorna o nome do oceano ou mar no campo `locality` (ex: "Oceano Atlântico", "Mar do Caribe"). Aceita coordenadas de qualquer ponto do globo.

Adicionei também um throttle de tempo no card da ISS: no máximo uma requisição de geocodificação a cada 30 s, para não saturar as APIs gratuitas com o refresh de 5 s.

---

### Dificuldade 7 — APOD retornando vídeo MP4 direto em vez de YouTube

**O problema:** O card do APOD só tinha `youtube_player_flutter` para vídeos. Quando a NASA retornou um arquivo MP4 direto (`sdo_cme.mp4`), `_youtubeId()` retornou `null`, o controller ficou `null`, e o card exibiu um placeholder estático sem nenhuma indicação de erro — zero responsividade.

**Como resolvi:** Adicionei `video_player: ^2.9.2` e bifurquei a lógica de `_load()`:
- URL YouTube → `YoutubePlayerController` com `loop: true`
- Qualquer outra URL → `VideoPlayerController.networkUrl()` + `initialize()` + `setLooping(true)` + `play()`

O método `_buildMedia()` verifica qual controller está disponível e renderiza o widget correto. O `FittedBox(fit: BoxFit.cover)` garante que o vídeo MP4 preencha os 200 px do card sem distorção.

---

### Dificuldade 8 — Notificação de proximidade da ISS gerando spam

**O problema:** O timer de refresh chama `nextPass()` a cada 5 s. A ISS leva cerca de 8 minutos para cruzar um raio de 100 km, o que geraria ~96 notificações durante uma única passagem sobre São Paulo.

**Como resolvi:** Adicionei um cooldown em memória (`_lastProximityNotif`) de 10 minutos em `NotificationService.checkIssProximity()`. A notificação só é disparada se:
1. A distância calculada pela fórmula de Haversine for ≤ 100 km, **e**
2. Pelo menos 10 minutos tiverem passado desde o último envio.

Para facilitar testes sem esperar uma passagem real, a tela de Perfil tem um botão "Simular ISS sobre SP (10s)" que força as coordenadas de São Paulo por 10 s e reseta o cooldown — garantindo que a notificação dispare nos próximos 5 s.

---

## Vídeo demonstrativo

> _https://drive.google.com/file/d/1CLunMd3Emmsa-eoMB6ZnmqKej0WCm488/view?usp=sharing_
