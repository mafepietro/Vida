# Vida

App pessoal para iPhone e Apple Watch que junta tudo do dia a dia: remédios, contas, água, humor, tarefas e viagens.

Plano completo: veja o documento "Plano do app Vida" no projeto.

## O que já funciona

- **Hoje:** remédios do dia, com toque para marcar como tomado, e avisos de receita.
- **Remédios:** cadastro com horários, estoque (por quantidade ou por dias), "Comprei mais", aviso para pedir nova receita X dias antes de acabar.
- **Lembretes:** alarme em cada horário com os botões "Tomei", "Lembrar em 10 min" e "Pular esta dose". Aviso diário às 10h para pedir receita até você marcar "Já pedi".
- **Aviso de expiração:** com a conta gratuita da Apple o app expira a cada 7 dias. O app avisa 2 dias e 1 dia antes.

## Como instalar no iPhone (conta gratuita)

Precisa de: Mac com Xcode 26, iPhone com iOS 26 e um cabo.

1. **Baixe o código:** no GitHub, botão verde **Code → Open with Xcode**, ou **Download ZIP** e abra o arquivo `Vida.xcodeproj`.
2. **Entre com seu Apple ID no Xcode:** menu **Xcode → Settings → Accounts → +** e escolha Apple ID.
3. **Escolha a equipe:** na barra lateral clique em **Vida** (ícone azul), depois no alvo **Vida → Signing & Capabilities**. Em **Team**, escolha **"Seu Nome (Personal Team)"**.
   - Se aparecer erro dizendo que o identificador já existe, troque o **Bundle Identifier** para algo único, como `com.seunome.vida`.
4. **Ligue o iPhone no Mac** e escolha ele no topo da janela do Xcode (onde aparece o nome do aparelho).
5. **Ative o Modo de Desenvolvedor no iPhone** (só na primeira vez): **Ajustes → Privacidade e Segurança → Modo de Desenvolvedor**. O iPhone reinicia.
6. Aperte **▶︎** (ou Cmd+R) no Xcode.
7. **Confie no app** (só na primeira vez): **Ajustes → Geral → VPN e Gerenciamento de Dispositivos**, toque no seu e-mail e em **Confiar**.
8. Abra o Vida e permita as notificações.

### Toda semana

O app para de abrir depois de 7 dias. Para renovar: ligue o iPhone no Mac, abra o projeto no Xcode e aperte **▶︎**. Seus dados continuam no celular, **desde que você não apague o app**.

## Tecnologia

- Swift 5 + SwiftUI, iOS 26
- SwiftData (dados guardados só no iPhone, sem iCloud)
- Notificações locais (UserNotifications)

## Organização do código

```
Vida/
  VidaApp.swift            início do app
  RootView.swift           abas
  Models/                  dados (Medication, DoseLog) e contas do estoque
  Services/                banco de dados, notificações, ações, aviso de expiração
  Views/Today/             tela Hoje
  Views/Medications/       lista, detalhe e formulário de remédios
```
