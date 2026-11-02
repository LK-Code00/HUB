# Investigacao de compatibilidade com Sniper Duels

## Resultado e limites

Foram identificadas e corrigidas falhas verificaveis no classificador do Hub. A pesquisa publica **nao revela a estrutura replicada das rankeds**, portanto esta entrega nao certifica funcionamento em todos os modos. O relato recebido confirma que o Hub permanece visivel na ranked; o funcionamento com classificacao manual ainda nao foi testado no jogo.

A compatibilidade agora depende dos sinais da partida e do personagem, sem lista fechada de nomes de modos nem bloqueio por um unico PlaceId. Ainda e necessario conferir uma ranked real com o diagnostico incorporado.

## Evidencias publicas consultadas

| Fonte | Evidencia | Limite |
| --- | --- | --- |
| [Pagina oficial](https://www.roblox.com/pt/games/109397169461300/SNIPER-DUELS) | Descreve duelos 1v1 a 4v4, 12v12 ocasional, FFA e modos temporarios; titulo anuncia Ranked. | Nao documenta equipes, atributos ou personagens das rankeds. |
| [Place para universo](https://apis.roblox.com/universes/v1/places/109397169461300/universe) | O place informado pertence ao universo **7264587281**. | Um PlaceId nao representa necessariamente todos os lugares da experiencia. |
| [Metadados oficiais da experiencia](https://games.roblox.com/v1/games?universeIds=7264587281) | Confirma o universo, o criador LOCKED IN NETWORK, a descricao de modos e `MorphToR6`. | R6 e a configuracao da experiencia; nao prova como cada personagem de ranked e montado. |
| [Lugares do universo](https://develop.roblox.com/v1/universes/7264587281/places?limit=100&sortOrder=Asc) | Lista o principal, Trading Hub, dois hotfix places e lugares de teste. | Nenhum lugar listado identifica inequivocamente um servidor ranked. Nao e prova de que ranked use um lugar separado. |
| [Emblemas oficiais](https://badges.roblox.com/v1/universes/7264587281/badges?limit=100&sortOrder=Asc) | Free-From-All cita FFA; Always Loaded cita One in the Chamber; Coronation cita Crown Control; Guardian Angel cita reviver jogadores em modos que permitem revive. Ha tambem emblemas de bilhar no Trading Hub. | Emblemas indicam modos/mecanicas existentes, nao garantem disponibilidade atual nem o formato de equipes. |
| [Player: documentacao oficial](https://create.roblox.com/docs/reference/engine/classes/Player) | Team/Neutral sao propriedades gerais; Character pode ainda apontar para o modelo antigo durante a substituicao. | Uma equipe de lobby nao comprova a equipe interna de uma rodada. |
| [TeleportService: documentacao oficial](https://create.roblox.com/docs/reference/engine/classes/TeleportService) | Teleportes podem transportar jogadores entre lugares e servidores. | A pesquisa nao comprovou um teleporte especifico da ranked; nao foi adicionado carregamento automatico de codigo remoto. |

### Busca em fontes externas

Foram consultados mecanismos de busca e dois repositorios publicos relacionados ao nome do jogo. Google e DuckDuckGo nao forneceram resultados utilizaveis neste ambiente; os resultados do Bing nao esclareceram as rankeds.

- [jimlindsay6677/sniper-duels, revisao consultada](https://github.com/jimlindsay6677/sniper-duels/tree/732e78192d8629d70b7182d1fd78b80701712ceb): o arquivo `script v2` tinha um invólucro de codigos numericos. A leitura estatica do texto resultante mostrou comparacoes genericas de `Player.Team`, sem esquema confirmado de ranked.
- [NEYZIXXX/Script_SniperDuel_Roblox_CoqNu, revisao consultada](https://github.com/NEYZIXXX/Script_SniperDuel_Roblox_CoqNu/tree/735965465b63e4d12c809a72f73a56290cf1e8b2): codigo ofuscado; nao foi usado como evidencia do modelo de equipes.

Nenhum desses scripts externos foi executado ou incorporado ao Hub.

## Falhas corrigidas no Hub

1. **ID zero descartado:** o normalizador tratava `0` como ausencia. Agora IDs zero sao preservados.
2. **Equipe de lobby prevalecia:** marcadores replicados de rodada agora sao examinados antes de Roblox.Team. Personagem atual tem prioridade sobre metadados persistentes do Player para a mesma chave.
3. **Aliases incompletos bloqueavam jogadores:** uma partida confirmada por uma chave compartilhada nao e descartada so porque um alias secundario esta ausente. Conflitos entre chaves compartilhadas continuam bloqueando.
4. **Categoria de fila mascarava modo:** `Ranked` sozinho nao indica FFA nem equipes. Um valor desconhecido nao encerra a busca por um modo reconhecido. Um modo local reconhecido tem prioridade sobre um global.
5. **Leitura limitada a filhos diretos:** sao consultados atributos e ValueBases em containers de dados de partida/equipe, ate dois niveis e 24 containers por raiz. Nao ha busca completa no Workspace por quadro.
6. **Morte permanecia apos revive:** um personagem antes morto volta a ser elegivel apos transicao replicada de vida positiva/estado vivo. Died sozinho continua bloqueando mesmo se a vida ainda estiver desatualizada.
7. **Peca temporariamente ausente:** Torso/UpperTorso sao alternativas quando Head e HumanoidRootPart nao estiverem disponiveis.
8. **Falta de explicacao dos filtros:** cada jogador recebe uma decisao com motivo; o diagnostico inclui universo/place, equipe, neutralidade, vida, estado, peca, distancia, tela, FOV, visibilidade e marcadores relevantes.

Os nomes candidatos, como MatchTeam ou RankedMatchId, sao heuristicas opcionais, **nao nomes internos confirmados do Sniper Duels**. Se nao houver evidencia suficiente, Auto continua exibindo equipe desconhecida. Classificacoes explicitas de Inimigo/Aliado e campos personalizados continuam disponiveis; lobby/espectador explicitamente marcado e excluido.

## Conferencia no jogo

1. Entrar em uma ranked, abrir **Jogadores → Gerar diagnostico** durante uma rodada ativa.
2. Verificar o motivo do adversario: amizade, equipe, partida incompleta, espectador ou desconhecido.
3. Usar **Copiar** para obter o texto; se o ambiente nao oferecer clipboard, o botao imprime o relatorio no console.
4. Testar a classificacao manual **Inimigo**. Se funcionar, a pendencia esta na identificacao automatica. Se nao funcionar, conferir personagem, vida e peca disponivel; comparar com o jogador local.
5. Preencher **Campos da partida** apenas com chaves realmente observadas no relatorio. Vazio restaura a deteccao automatica. Os campos sao salvos no perfil atual.
6. Conferir aliado e adversario em 1v1, equipes, FFA, ranked, revive, troca de rodada e retorno ao lobby. Em LTMs, nao assumir FFA somente pelo nome do modo.

Compilacao Luau e **58 testes de comportamento** validam os cenarios simulados. Nao houve execucao no cliente Roblox nem validacao em partidas reais de Sniper Duels.

## Historico: primeiro diagnostico de uma partida real (regra de grupos revisada abaixo)

O relato seguinte confirmou um disparo indevido em colega. O diagnostico mostrou o jogador local e outro jogador em `Workspace.Characters.{mesmo-guid}.B.<nome>`, ambos com `Team=nil` e `Neutral=true`. A decisao do colega era **INCLUIDO: FFA manual**. `LastModesSelected = 1v1,2v2` registra preferencias de fila; nao identifica equipe nem modo atual.

A causa demonstrada e a combinacao de FFA manual com a ausencia de leitura da hierarquia de personagens. Foi acrescentado um adaptador restrito ao universo 7264587281, com comparacao por instancia da partida e nome do lado A/B:

- mesma pasta de equipe: bloqueado, mesmo com FFA, filtro de equipe desligado ou uma classificacao manual antiga;
- lados A/B diferentes na mesma partida: candidato, respeitando vida, amizade/relacao explicita, FOV e visibilidade;
- partidas diferentes ou estrutura incompleta: bloqueado;
- troca de lado/partida: revalidacao direta no acompanhamento, sem aguardar o cache;
- fora do universo ou fora do formato reconhecido: o adaptador nao inventa equipes.

A pasta **B** e sua correspondencia com colegas foram observadas. A estrutura simetrica **A** como lado oposto e uma inferencia limitada, coberta por testes sinteticos; ainda nao apareceu em um diagnostico de adversario enviado. O relatorio recebido continha apenas dois Players. O diagnostico agora enumera os modelos A/B da partida atual e sua associacao com Players para investigar adversarios ausentes, sem transforma-los automaticamente em alvos.

Nove cenarios adicionais cobrem a reproducao com FFA ligado, ESP e mira, adversario A simulado, outra partida, estrutura incompleta, relacoes antigas, amizade, troca de equipe, perda de estrutura, escopo por universo e modelos sem Player associado. A compilacao e os **58 testes** passaram. A alteracao publicada ainda precisa de verificacao na ranked real.

## Correcao apos diagnostico real de FFA

O diagnostico seguinte foi identificado como FFA e mostrou cinco participantes vivos no mesmo grupo **A**, todos com `Player.Character` associado. O sexto personagem estava em `ReplicatedStorage._DEAD_CHARACTERS`, com vida 25 e estado None. A regra anterior que tratava A/B como prova de equipes estava errada: a mesma estrutura e usada para organizar participantes de FFA. Essa regra foi substituida.

`LastModesSelected` variava entre `FFA_Standard,_LTM`, `_LTM` e listas contendo 2v2/3v3/4v4/12v12/FFA. Logo, nao e uma fonte valida do modo atual. Nem a quantidade de jogadores nem a ausencia de ocupantes em B comprovam FFA; uma equipe pode estar ausente durante carregamento ou apos eliminacao.

O Hub separa agora identidade da partida de modo de combate. Auto consulta campos atuais de modo, incluindo a pasta da partida; reconhecer `FFA_Standard` nesses campos e suportado, mas **o nome de um campo de modo atual do Sniper Duels ainda nao foi confirmado pelo diagnostico**. Quando nao existe esse sinal, **Jogadores → Modo desta partida → FFA / Equipes** resolve explicitamente a ambiguidade. Essa escolha nao persiste fora da instancia da partida, nao e salva em disco e nao e inferida das preferencias da fila.

Em FFA confirmado, participantes vivos da mesma partida podem ser adversarios mesmo no mesmo grupo A. Em Equipes, o grupo local continua excluido. Partidas diferentes, personagens em armazenamento de mortos, aliados manuais e demais filtros continuam bloqueados. Um adversario elegivel para ESP nao e necessariamente elegivel para a mira: no diagnostico recebido, todos os adversarios estavam sem linha de visao, e o unico adversario na tela estava fora do FOV.

Foram acrescentados nove testes para FFA com grupo unico, selecao via interface, modo atual FFA_Standard, escopo por partida, mudanca para equipes, limpeza de alvos/ESP, filtros e nao persistencia da escolha. **Compilacao Luau e 67 testes simulados passaram**; a atualizacao ainda precisa de conferencia no cliente Roblox.
