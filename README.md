# SkySight

Aplicativo mobile desenvolvido em Flutter para registro de observações astronômicas. O usuário pode fotografar o céu, registrar o que viu (Lua, planetas, meteoros, ISS etc.), ver a Foto Astronômica do Dia da NASA e acompanhar a passagem da Estação Espacial Internacional sobre sua localização.

---

## Proposta da aplicação

### Problema
Amantes de astronomia não têm uma forma simples e integrada de registrar suas observações pessoais. Aplicativos existentes são complexos ou focados em profissionais, faltam soluções que unam **captura de foto + GPS + dados astronômicos em tempo real** numa interface acessível.

### Público-alvo
Estudantes, curiosos e entusiastas de astronomia que querem manter um diário visual das próprias observações do céu.

### O que o app faz
- **Registra observações**: foto tirada na hora, localização GPS automática, título com autocomplete (Lua, Marte, Saturno, ISS…) e descrição livre
- **Foto Astronômica do Dia (APOD)**: integração com a API da NASA, com cache local, a imagem é baixada uma vez por dia e exibida offline; quando é vídeo existe tap para abrir
- **ISS em tempo real**: posição atual e countdown até a próxima passagem sobre a localização do usuário, com notificação local 5 minutos antes
- **Histórico**: listagem de todos os registros com busca por nome, filtro por período, swipe para excluir
- **Notificações**: passagem da ISS (agendada automaticamente) e APOD diário às 9h (configurável)
- **Perfil**: toggles para ativar/desativar cada tipo de notificação, logout

---

## Tecnologias utilizadas

| Tecnologia | Uso |
|---|---|
| Flutter (Dart) | Framework mobile — Android e iOS |
| Supabase | Auth (email/senha), banco de dados (PostgreSQL), Storage (fotos) |
| NASA APOD API | Foto Astronômica do Dia |
| wheretheiss.at API | Posição atual da ISS em tempo real |
| Open Notify API | Horário de próxima passagem da ISS (fallback para wheretheiss.at) |
| `flutter_local_notifications` | Notificações locais agendadas |
| `geolocator` | GPS do dispositivo |
| `image_picker` | Câmera / galeria |
| `share_plus` | Compartilhamento nativo do sistema |
| `shared_preferences` | Cache de preferências e metadados do APOD |
| `path_provider` | Armazenamento local da imagem do APOD |
| `url_launcher` | Abrir vídeos/links externos |
| `timezone` | Agendamento de notificações com fuso horário correto |

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
│   ├── auth_screen.dart                # Login e cadastro (TabBar)
│   ├── main_screen.dart                # BottomNavigationBar principal
│   ├── home_screen.dart                # APOD + ISS + registros recentes
│   ├── history_screen.dart             # Histórico com busca e filtro
│   ├── observation_detail_screen.dart  # Detalhe de um registro
│   ├── new_observation_screen.dart     # Câmera + GPS
│   ├── observation_form_screen.dart    # Formulário de registro
│   └── profile_screen.dart            # Perfil e configurações
├── services/
│   ├── supabase_service.dart           # Inicialização do Supabase
│   ├── nasa_service.dart               # Integração com API da NASA
│   ├── iss_service.dart                # Integração com APIs da ISS
│   ├── observation_service.dart        # CRUD de observações
│   ├── notification_service.dart       # Notificações locais
│   └── apod_cache_service.dart         # Cache local do APOD
└── widgets/
    └── supabase_image.dart             # Widget que carrega imagens via signed URL
```

---

## Diário de desenvolvimento

### Dificuldade 1 — Credenciais do Supabase e o `.env` que sumia

**O problema:** Comecei usando `flutter_dotenv` para manter as credenciais do Supabase fora do código-fonte. Funcionou perfeitamente no computador de desenvolvimento, mas quando rodei no tablet, o app travava na tela inicial com `EmptyEnvFileError`. O arquivo `.env` estava listado no `.gitignore` e, ao rodar o app em outro dispositivo, ele simplesmente não existia. O Flutter tenta carregar o asset em runtime e falha silenciosamente, congelando o app.

**Como resolvi:** Removi completamente o `flutter_dotenv` e hardcodei as credenciais diretamente em `lib/main.dart`. Como o repositório é privado, essa é uma solução aceitável para o contexto acadêmico. A solução "correta" em produção seria usar variáveis de ambiente, mas para desbloquear o desenvolvimento essa troca foi necessária.

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

### Dificuldade 3 — API da ISS completamente fora do ar

**O problema:** A `api.open-notify.org/iss-pass.json` é a única API gratuita e sem necessidade de chave para prever passagens da ISS. Durante o desenvolvimento ela ficou completamente indisponível. O DNS do servidor não resolvia, causando `SocketException: Failed host lookup`. O código original capturava esse erro e exibia "Sem conexão com a internet", o que era incorreto e confuso com internet funcionando normalmente.

O problema maior: `SocketException: Failed host lookup` é **idêntico** tanto para "sem internet" quanto para "servidor específico fora do ar".

**Como resolvi:** Implementei uma estratégia de dois níveis com APIs independentes:
1. Tenta `open-notify` para obter horário exato de passagem
2. Se qualquer erro ocorrer (incluindo `SocketException`), tenta `api.wheretheiss.at/v1/satellites/25544`. Uma API completamente diferente, com infraestrutura separada, que retorna a posição atual da ISS
3. Somente se o fallback também lançar `SocketException` é que o erro de "Sem conexão" é exibido

Isso resolveu o problema: o usuário vê a posição atual da ISS mesmo com a API principal fora, e a mensagem de "sem conexão" só aparece quando é verdade.

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

## Vídeo demonstrativo

> _ link do vídeo de demonstração aqui._


