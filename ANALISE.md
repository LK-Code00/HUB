# Analise do HUB.lua

## Base e escopo

Revisao da versao local em `bb43614`, conferida byte a byte com o arquivo servido por `https://raw.githubusercontent.com/LK-Code00/HUB/main/HUB.lua` no inicio do trabalho. O codigo e um Hub cliente de Roblox/Luau: interface, acompanhamento de camera, Highlight, classificacao de jogadores, preferencias e efeitos graficos. Nao implementa exploracao de vulnerabilidade do servidor. Nao carrega bibliotecas remotas nem transmite diagnosticos automaticamente.

As alteracoes estao no arquivo independente `HUB.lua`. As APIs opcionais de arquivo e clipboard continuam opcionais.

## Problemas e correcoes

| Problema identificado | Consequencia | Correcao |
| --- | --- | --- |
| `bind` guardava todas as conexoes; respawn e troca de camera apenas desconectavam as antigas | O registro retinha referencias ao longo da sessao | `unbind` desconecta e remove a entrada; encerramento limpa registros |
| Saida de jogador nao limpava `metadata` e `Decisions` imediatamente | Dados obsoletos permaneciam em memoria | Limpeza no evento `PlayerRemoving` |
| Filtro de amigos desligado gravava `other` sem consulta | Reativar o filtro poderia incluir amigos | Consulta independente do estado do filtro |
| Erro de amizade ficava permanentemente em `unknown` | Falha transitoria podia bloquear jogador ate reiniciar | Ate tres tentativas com espera crescente e verificacao de sessao/jogador antes e depois da chamada |
| Classificacao manual de inimigo antecedia o teste generico de partida | Marcacao antiga podia incluir jogador de outra partida | Exclusao de partida antes da preferencia manual; prioridade sobre amizade preservada |
| Selecao FFA manual sobrevivia a uma passagem sem contexto de partida | Voltar a uma pasta reutilizada podia recuperar o modo anterior | Limpeza da escolha quando a atualizacao observa ausencia de contexto |
| Busca validava visibilidade e o callback de camera repetia a mesma validacao no mesmo quadro | Raycast duplicado na aquisicao e revalidacao periodica | Retorno conjunto de alvo, posicao e projecao; uso somente no mesmo callback, sem cache entre quadros |
| Todo candidato no FOV recebia raycast antes da comparacao de prioridade | Trabalho desnecessario com candidatos mais distantes do centro | Comparacao geometrica primeiro; candidato obstruido nao impede fallback visivel |
| Cada troca de ajuste grafico percorria todos os descendentes da cena | Custo proporcional ao mapa, inclusive objetos sem efeitos | Cadastro inicial e incremental de particulas/pos-efeitos; alteracoes percorrem somente candidatos |
| Slider de shaders destruia e recriava efeitos | Alocacoes e eventos repetidos durante arraste | Reutilizacao de ColorCorrection e Bloom |
| Nova aplicacao de override podia perder uma mudanca intermediaria feita pelo jogo | Restauracao voltava a valor mais antigo | Atualizacao do valor de restauracao quando ha mudanca observavel |
| Ajustes persistentes nao tinham controles na interface | Distancia, intervalos e filtros exigiam edicao externa | Seis controles adicionais ligados a configuracao e persistencia existentes |
| Descoberta de equipes dependia da espera do ESP | ESP de 5 segundos atrasava tambem a classificacao | Temporizadores separados; espera de manutencao limitada a 100 ms |

## Validacao realizada

- Compilacao do arquivo completo com Luau oficial 0.744, commit `32c28089305f488f901aaf1dbf3fd1cb65fa3d11`.
- 89 verificacoes comportamentais aprovadas: 67 iniciais, 11 de otimizacao e 11 para modelos de ranked.
- Registro de conexoes manteve o mesmo tamanho apos 40 respawns e 40 renovacoes do listener de viewport; nenhuma entrada desconectada permaneceu no registro.
- Cenario simulado com um candidato: um raycast na aquisicao e um na revalidacao periodica, sem segunda chamada no mesmo quadro.
- Cenario com dois candidatos: candidato mais distante nao recebe raycast quando o mais proximo e visivel; recebe quando o mais proximo esta obstruido.
- Alteracoes graficas apos inicializacao realizaram zero chamadas a `Workspace:GetDescendants`; dez alteracoes de intensidade preservaram a mesma instancia de Bloom.
- Controles novos, restauracao do perfil, falha/repeticao de consulta de amizade, encerramento, conflito de partida, perda de contexto FFA e independencia dos temporizadores foram exercitados.

O mock passou a emitir `ChildAdded` e `DescendantAdded` ao mudar `Parent`, incluindo descendentes de modelos inseridos. Isso permite verificar descoberta por eventos sem depender de varreduras que o codigo real nao faz mais.

Reproduzir:

```sh
luau-compile HUB.lua > /tmp/hub-bytecode.txt
python3 tests/run.py /caminho/para/luau
```

## Limites tecnicos e verificacao no cliente

Estes resultados verificam logica simulada e compilacao, nao FPS, renderizacao ou desempenho medido no Roblox. Nenhuma sessao real de Roblox foi executada neste ambiente. Portanto, nao ha garantia de todas as opcoes funcionarem em qualquer jogo/executor.

- Equipes e partidas genericas ainda dependem de atributos/ValueBases replicados e da atualizacao periodica. Trocas genericas podem levar aproximadamente 0,9 segundo mais o atraso de agendamento para refletir no cache. A estrutura A/B do Sniper Duels recebe verificacao adicional ao validar alvos.
- O modo de partida precisa de dados atuais ou escolha manual. Pastas A/B e preferencias de fila nao demonstram, isoladamente, FFA ou equipes.
- Personagens genericos precisam de associacao a `Player.Character`. No Sniper Duels, modelos diretos nas pastas A/B da partida local tambem sao reconhecidos, mesmo sem Player, com Humanoid vivo e peca suportada. Outros NPCs ou sistemas customizados nao sao cobertos automaticamente. Modelos sem Player nao possuem filtros de amizade ou classificacao por UserId.
- A mira controla a camera local. Nao garante acerto, dano, compensacao de projeteis ou alteracao de regras do servidor. Respeitar controle manual pode manter a mira pausada enquanto houver entrada continua.
- Highlight, limites de renderizacao do dispositivo, alcance de streaming e objetos ausentes no cliente continuam sujeitos ao Roblox. A distancia configurada limita a mira, nao os destaques.
- O teste de visibilidade segue um raycast ao ponto de mira; materiais transparentes e regras especiais de colisao do jogo nao sao deduzidos pelo Hub.
- O cadastro grafico faz uma varredura completa inicial. A restauracao detecta mudancas pelo valor atual; nao consegue atribuir autoria quando o jogo escreve exatamente o mesmo valor do override.
- Reduzir intervalos aumenta frequencia de trabalho; nao equivale automaticamente a maior desempenho. Os valores padrao foram preservados.
- Testar em desktop e mobile: todos os controles, scroll das paginas maiores, arraste/toque, respawn, transicao lobby/partida, troca de camera, objetos graficos novos, fechamento e reexecucao.

A revisao preserva o escopo das funcoes existentes e corrige falhas verificaveis. Integracoes adicionais de jogo dependem de dados observados naquele cliente e versao.

## Correcao de ranked baseada no diagnostico recebido

O cliente mostrou `Jogadores disponiveis: 1`, local em B e o modelo `A/ghostspy097` vivo, sem Player associado. A causa no codigo era dupla: `findTarget` e o ciclo do ESP enumeravam somente `Players:GetPlayers`, e `targetInfo` exigia `GetPlayerFromCharacter`. O modo desconhecido nao era o bloqueio para lados opostos; `ForceFFA` generico tambem nao podia corrigir a ausencia do candidato.

A descoberta agora combina Players e modelos da partida, com validacao estrutural em tempo de uso, listeners de morte e limpeza quando o modelo sai do conjunto. Nenhuma consulta de identidade remota foi adicionada. A interface informa adversarios encontrados por modelo, e o diagnostico explica a indisponibilidade de amizade. Onze testes novos reproduzem o cliente com um Player, mira/ESP, ausencia de ForceFFA, equipes, FFA confirmado, morte com vida replicada atrasada, armazenamento de mortos, filtros geometricos, escopo por universo/partida, streaming tardio, associacao posterior e rejeicao de Character antigo.

Os resultados sao de simulacao. Confirmar no cliente real gerando novo diagnostico apos carregar a atualizacao.
