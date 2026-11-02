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

Compilacao Luau e **49 testes de comportamento** validam os cenarios simulados. Nao houve execucao no cliente Roblox nem validacao em partidas reais de Sniper Duels.
