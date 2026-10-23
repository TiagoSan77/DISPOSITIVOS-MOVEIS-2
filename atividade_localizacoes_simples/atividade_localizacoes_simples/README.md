# Atividade 1 — versão simplificada para estudar

Este projeto foi reduzido para facilitar o estudo. O código principal está em `lib/main.dart` e usa poucos arquivos.

## Como usar

1. Crie um projeto nativo Flutter no computador:
   ```bash
   flutter create atividade_localizacoes
   ```
2. Substitua o `pubspec.yaml` pelo deste ZIP.
3. Copie a pasta `lib/` deste ZIP para o projeto criado.
4. No `android/app/src/main/AndroidManifest.xml`, adicione estas permissões logo depois da abertura da tag `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
   <uses-permission android:name="android.permission.WAKE_LOCK" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   ```
   Preserve as tags `<application>` e `<activity>` que o `flutter create` gerou.
5. Execute:
   ```bash
   flutter pub get
   flutter run
   ```

## O que o app faz

- Solicita permissão e verifica se o GPS está ligado.
- Usa um stream de posições; no Android solicita intervalo de 20 segundos e mostra notificação durante a coleta.
- Salva latitude, longitude, precisão e instante UTC no SQLite local.
- Mostra até 100 posições recentes em lista.
- Mostra os registros em um mapa OpenStreetMap.
- Permite apagar todos os registros com confirmação.

## Simplificações e limitações

Para deixar o código mais fácil de estudar, a lógica está concentrada em `main.dart`. Isso **não segue integralmente** a recomendação do professor de separar modelo, serviço, repositório e telas em arquivos diferentes.

A coleta em segundo plano depende das permissões e regras da versão do Android. Teste em aparelho real. O projeto não implementa cache offline dos tiles do mapa e ainda usa o ícone padrão do Flutter; esses itens precisam ser completados para cumprir todo o enunciado. Rode `flutter analyze` e teste antes de entregar.
