# Segunda opinião técnica: Snake Arcade by Jair Lima

## Status após conferência (Claude, 2026-10-08)

Revisão feita pelo GitHub Copilot (o Codex estava sem cota). Cada achado foi conferido contra o código e, quando dependia da API, contra um teste compilado.

**Achado nº 1 é FALSO (descartado).** Teste em Harbour 3.0.0: `hb_MilliSeconds()` retorna `212658288694228`, valor absoluto que inclui a data, monotônico e que NÃO reinicia à meia-noite. Quem reinicia é `Seconds()`. O loop de tick original estava correto e não deve ser trocado por aritmética modular. A justificativa de "rollover" também aparece nos itens 4 (sugestão com `86400000`), e deve ser ignorada.

Já corrigidos no `snake.prg` (build e autoteste passam, saída 0):

| Item | Situação |
|------|----------|
| 2 spawn de comida com `{0,0}` | Corrigido: lista de células livres, `NIL` se cheio (fase concluída) |
| 4 duração do bônus em ticks | Corrigido: ~7 s reais, barra proporcional, pontos pelo tempo restante |
| 3 recorde sem aviso de falha de gravação | Parcial: `SaveHi()` agora retorna o resultado e o jogo avisa. Caminho em `%APPDATA%` fica para distribuição |
| 5 fila de teclas | Corrigido: descarta repetição/reversão, fila cheia substitui a última |
| 6 vidas extras | Corrigido: `DO WHILE nScore >= nExtra` único, vale também para o bônus |
| 7 autoteste | Ampliado: regra da cauda, tabuleiro cheio, uma célula livre, código de saída 1 em falha, `snake_selftest.log` |
| 8 largura do placar | Corrigido: `Min( nScore, 999999 )` na exibição |

Pendentes (baixo risco hoje): 9 WAVs sob demanda, 10 curva de dificuldade (depende de teste de jogabilidade), 11 conectividade dos obstáculos, 12 recordes parciais, 13 limpeza dos WAVs, 14 HUD só quando mudar, 15 alternativa ASCII para glifos.

---

Revisão estática de `snake.prg`, considerando Harbour 3.0.0, GTWIN, o projeto em `PROJECT.md` e o arquivo de build informado. Os números referem-se às linhas atuais de `snake.prg`. Não alterei o código do jogo.

## Conclusão

A estrutura central está bem pensada: movimento separado da leitura de teclado, fila curta de direções, desenho incremental e verificação da cauda que vai sair neste tick. As colisões com as bordas do tabuleiro são checadas antes de acessar a posição seguinte, e a colisão com a cauda está correta: `HitSnake(..., nGrow == 0)` ignora a cauda somente quando ela será removida no mesmo movimento. Os principais problemas confirmados são a espera que pode atravessar a meia-noite e travar o tick, o spawn que inventa a célula `{0,0}` quando falha, a duração do bônus que varia com a velocidade e a persistência de recordes sem tratar falhas de escrita. A fila de teclas, a geração aleatória de obstáculos, o limite visual do placar e a inicialização do som também merecem ajustes.

## Achados priorizados

### Alta

1. **[DESCARTADO, FALSO: `hb_MilliSeconds()` não reinicia à meia-noite, ver Status acima] O loop pode ficar preso até o próximo dia ao cruzar a meia-noite.** Linhas 193-195 comparam diretamente o horário em milissegundos do relógio. `hb_MilliSeconds()` é um contador de milissegundos do dia, portanto volta a zero a meia-noite. Se `nNext` for maior que o valor máximo do dia, a condição continua verdadeira depois do rollover e o jogo deixa de avançar por um período muito longo.

   Sugestão: comparar tempo decorrido com aritmética modular, ou usar um contador monotonicamente crescente. Exemplo mantendo o contador existente:
   ```harbour
   nStart := hb_MilliSeconds()
   DO WHILE ( hb_MilliSeconds() - nStart + 86400000 ) % 86400000 < nDelay
      k := Inkey( 0.01 )
      // processar entrada
   ENDDO
   ```
   O trecho pressupõe que cada espera é inferior a 24 horas, o que é verdade para este tick.

2. **Falha de spawn vira comida válida na origem do campo.** `NewFood()` tenta 1000 coordenadas aleatórias e, se não achar uma livre, retorna `{ 0, 0 }` (linhas 389-405). A coordenada pode estar ocupada pela cobra ou por obstáculo; o jogo desenha a fruta sobre a ocupação e pode deixá-la impossível de consumir. Conforme o tabuleiro se enche, rejeição aleatória também passa a desperdiçar tentativas.

   Sugestão: montar uma lista de todas as células livres e escolher uma delas; retornar `NIL` se a lista estiver vazia e tratar isso como tabuleiro concluído. Assim não há coordenada sentinela que pareça uma fruta real:
   ```harbour
   aFree := {}
   FOR y := 0 TO FH - 1
      FOR x := 0 TO FW - 1
         IF ! HitSnake( aSnake, x, y, .F. ) .AND. ! HitObs( aObs, x, y ) .AND. ;
               ( aOther == NIL .OR. aOther[ 1 ] != x .OR. aOther[ 2 ] != y )
            AAdd( aFree, { x, y } )
         ENDIF
      NEXT
   NEXT
   IF Len( aFree ) == 0
      RETURN NIL
   ENDIF
   RETURN aFree[ hb_RandomInt( 1, Len( aFree ) ) ]
   ```
   Adaptar os chamadores para lidar com `NIL`.

3. **Recordes podem falhar silenciosamente em instalações sem permissão de escrita.** `LoadHi()` e `SaveHi()` usam `hb_DirBase() + HI_FILE` (linhas 532 e 560), que aponta para a pasta-base do executável, não necessariamente para uma pasta gravável. O retorno da gravação não é verificado. Em uma pasta protegida, como uma instalação sob `Program Files`, o jogo continua sem persistir placares e não informa o jogador.

   Sugestão: escolher um caminho por usuário gravável, criar/verificar sua pasta no início e verificar a gravação. Se a operação falhar, preservar o placar em memória e avisar em vez de declarar sucesso:
   ```harbour
   IF ! hb_MemoWrit( cHiFile, cTxt )
      // informar que o recorde não foi salvo
   ENDIF
   ```
   Manter `hb_DirBase()` apenas como alternativa explícita, não como garantia de permissão.

4. **O tempo do bônus fica mais curto conforme a cobra acelera.** O bônus começa em 70 ticks (linha 292) e perde um tick por movimento (linha 316). `LevelDelay()` cai de 140 ms para 40 ms (linha 357), então a mesma contagem representa cerca de 9,7 segundos na primeira fase e 2,8 segundos nas fases mais rápidas. Ainda por cima, o contador já diminui no tick em que o bônus nasce.

   Sugestão: guardar o instante de expiração em milissegundos e comparar tempo decorrido, com a mesma proteção de rollover do loop; ou definir um número de movimentos deliberado e manter a regra igual para todas as fases. Exemplo conceitual para duração real:
   ```harbour
   nBonusStart := hb_MilliSeconds()
   lExpired := ( hb_MilliSeconds() - nBonusStart + 86400000 ) % 86400000 >= 7000
   ```
   Atualizar o HUD com o tempo restante derivado desse instante e não decrementar no próprio tick de criação.

### Media

5. **A fila de direções enche com repetições e descarta uma curva válida.** Linhas 200-202 guardam as duas primeiras teclas sem eliminar direções duplicadas ou validar a reversão contra a última direção pendente. Ao chegar a duas entradas, uma curva nova é simplesmente ignorada. Teclas repetidas pelo sistema podem ocupar os dois lugares antes de chegar a curva que o jogador queria.

   Sugestão: comparar a nova tecla com a direção efetiva mais recente, isto é, a última da fila ou a direção atual. Descartar duplicatas e reversões antes de adicionar, e definir uma política explícita para fila cheia, por exemplo substituir a segunda entrada por uma curva nova válida.
   ```harbour
   IF Len( aQ ) == 2
      dLast := aQ[ 1 ]
   ELSEIF Len( aQ ) == 1
      dLast := aQ[ 1 ]
   ELSE
      dLast := { nDx, nDy }
   ENDIF
   IF ( d[ 1 ] != dLast[ 1 ] .OR. d[ 2 ] != dLast[ 2 ] ) .AND. ;
         ! ( d[ 1 ] == -dLast[ 1 ] .AND. d[ 2 ] == -dLast[ 2 ] )
      IF Len( aQ ) < 2
         AAdd( aQ, d )
      ELSE
         aQ[ 2 ] := d
      ENDIF
   ENDIF
   ```

6. **A concessão de vidas extras trata no máximo um marco por evento de pontuação.** Nas linhas 294-295 e 311-312, o código usa um `IF` e avança `nExtra` apenas 1000 pontos. Uma recompensa que atravesse mais de um limite concede uma vida e deixa limites antigos pendentes; eventos posteriores podem então conceder vidas em sequência. Além disso, a vida concedida ao coletar bônus não toca o som que a vida concedida ao comer fruta toca.

   Sugestão: centralizar a regra numa rotina chamada após qualquer pontuação e consumir todos os marcos alcançados:
   ```harbour
   DO WHILE nScore >= nExtra
      nExtra += 1000
      nLives := Min( nLives + 1, 5 )
      PlaySfx( "level" )
   ENDDO
   ```
   A pontuação por conclusão de fase (linhas 331-334) também não verifica marcos de vida. Centralize a concessão depois de qualquer alteração de score. Se o limite de cinco vidas for atingido, ainda avance `nExtra` para evitar acumular recompensas antigas.

7. **O autoteste não testa colisão de movimento nem as condições que seu texto sugere.** Em `SelfTest()` (linhas 707-729), o primeiro teste verifica que a comida não foi gerada em cobra/obstáculo. O segundo verifica se obstáculos foram gerados em duas células de uma faixa segura; não exercita parede, auto-colisão, entrada na cauda que sai, crescimento, bônus, vidas ou recordes. Os testes usam uma cobra fixa e resultados aleatórios, sem falhas que validem as regras do motor.

   Sugestão: extrair regras puras para funções testáveis e fornecer mapas deterministas. Criar casos explícitos para avançar para cada borda, colidir com corpo, entrar na cauda com e sem crescimento, tabuleiro sem células livres, expirar/coletar bônus e cruzar um ou mais marcos de vida. Fazer o processo retornar resultado diferente de sucesso se qualquer caso falhar.
   ```harbour
   IF HitSnake( aSnake, aSnake[ 1 ][ 1 ], aSnake[ 1 ][ 2 ], .T. ) .OR. ;
         ! HitSnake( aSnake, aSnake[ 1 ][ 1 ], aSnake[ 1 ][ 2 ], .F. )
      nBad++
   ENDIF
   ```

8. **O placar tem largura mínima, não largura máxima.** `StrZero(nScore, 6)` e `StrZero(nLevel, 2)` (linhas 466 e 469) podem produzir mais caracteres que o espaço reservado. Como nível e pontuação não têm teto no motor, placares acima de seis dígitos ou níveis acima de 99 invadem os campos vizinhos do HUD.

   Sugestão: definir limites de jogo e de gravação coerentes com a tela, ou calcular largura e truncar/rolar explicitamente antes de desenhar. Testar a largura antes de chamar `hb_DispOutAt()` e atualizar o restante da linha para apagar caracteres antigos.
   ```harbour
   nScore := Min( nScore, 9999999999 )
   hb_DispOutAt( 1, 10, PadL( LTrim( Str( nScore ) ), 10 ), "G+/N" )
   ```
   Reservar dez colunas no HUD e aplicar o mesmo limite de forma consistente ao arquivo de recordes.

9. **A criação dos WAVs é feita em toda inicialização, antes de selecionar o autoteste.** `Main()` chama `InitSound()` antes de interpretar `--selftest` (linhas 34-43); `InitSound()` sintetiza nove arquivos (646-668) usando concatenação de um byte por iteração em `MakeWav()` (670-691). Isso adiciona trabalho de início, escreve sempre os mesmos arquivos em `%TEMP%` e pode falhar sem aviso se a pasta estiver indisponível ou sem permissão.

   Sugestão: processar os argumentos antes de iniciar subsistemas; sintetizar os WAVs sob demanda ou uma vez por execução, somente quando o som estiver habilitado; verificar o resultado de cada escrita. Para o autoteste, separar o teste do motor da criação/toque de áudio, com uma opção específica para verificar WAV.
   ```harbour
   IF cArg == "--selftest"
      LoadHi()
      SelfTest()
      RETURN
   ENDIF
   InitSound()
   LoadHi()
   ```

10. **A curva de dificuldade e pontuação precisa de teste de jogabilidade.** `LevelDelay()` reduz 12 ms por fase de 140 ms até o piso de 40 ms (linha 357), ou seja, de cerca de 7 para 25 movimentos por segundo; os obstáculos aumentam até o limite de 12 blocos (linhas 407-408). Cada fase exige oito frutas, cada fruta cresce a cobra em duas células e a pontuação vale `10 * nLevel` (linhas 284-285), além do bônus de conclusão. A aceleração é forte nas primeiras fases e depois para, enquanto o comprimento e a pontuação continuam crescendo. É um risco de balanceamento, pois `PROJECT.md` também registra que a sensação de velocidade ainda não foi testada.

    Sugestão: testar partidas por fase e ajustar uma tabela explícita de intervalo por nível, crescimento por fruta, pontos e bônus de conclusão. Medir movimentos por segundo e duração média para concluir fase; calibrar também quantas vidas extras a pontuação concede. Evitar que o bônus de conclusão aumente sem limite sem uma meta de score definida.
    ```harbour
    aDelay := { 140, 128, 116, 104, 92, 80, 68, 56, 48, 40 }
    nDelay := aDelay[ Min( nLevel, Len( aDelay ) ) ]
    ```
    Usar valores medidos em teste de jogo, não assumir que esta tabela sugerida é a curva final.

11. **Geração de obstáculos não garante uma faixa jogável nem conectividade.** `MakeObs()` (linhas 407-432) rejeita cada segmento que sai do limite ou cai na área inicial, mas não verifica se o conjunto resultante bloqueia uma passagem ou cria bolsos inacessíveis. O espaço é amplo e os blocos são limitados, então é um risco de geração, não uma falha reproduzida.

    Sugestão: após gerar obstáculos, validar que há células livres suficientes e que as regiões relevantes do tabuleiro permanecem conectadas; repetir a geração com limite de tentativas e uma configuração segura determinística como alternativa.
    ```harbour
    IF ! HasPath( aObs, aSpawn, aFood )
       LOOP
    ENDIF
    ```
    `HasPath()` representa uma busca de conectividade sobre as células não bloqueadas.

### Baixa

12. **O arquivo de recordes parcialmente válido é descartado como um todo.** `LoadHi()` só adota a tabela lida se houver pelo menos cinco linhas (linhas 530-550). Um arquivo truncado com um a quatro recordes válidos é substituído pelo placar padrão. Também não valida iniciais, formato numérico, valores negativos ou ordenação antes de usá-los.

    Sugestão: aceitar de zero a cinco registros válidos, filtrar linha por linha, ordenar por pontuação decrescente e completar os lugares faltantes com valores padrão. Gravar primeiro em arquivo temporário e substituir o arquivo anterior apenas depois de validar a escrita.
    ```harbour
    IF Len( aTmp ) > 0
       s_aHi := aTmp
       ASize( s_aHi, Min( Len( s_aHi ), 5 ) )
    ENDIF
    ```
    Não substituir uma tabela parcialmente válida pelos valores padrão.

13. **Arquivos de som ficam no `%TEMP%` e não são limpos.** `InitSound()` usa `GetEnv("TEMP")` e, quando vazio, grava no diretório corrente (`.`) (linhas 648-653). `MakeWav()` sobrescreve nomes fixos `snk_*.wav` e não trata erro (691); não há limpeza ao sair. Isso acumula arquivos e torna o fallback dependente de o diretório corrente ser gravável.

    Sugestão: validar a pasta temporária, falhar com aviso ou desabilitar som se não for possível gravar, usar nomes exclusivos por execução e remover apenas os arquivos criados pelo próprio processo ao encerrar. Não usar o diretório corrente como fallback silencioso.
    ```harbour
    IF ! hb_MemoWrit( cWav, cData )
       s_lSnd := .F.
       RETURN
    ENDIF
    ```

14. **O desenho incremental ainda escreve HUD completo em todos os ticks.** `Hud()` é chamado a cada movimento (linha 327) e redesenha score, recorde, nível, vidas, barra de comida e bônus mesmo quando a maioria não mudou (461-479). Isso não apaga o campo, mas multiplica chamadas de saída e pode contribuir para cintilação em terminais lentos ou remotos.

    Sugestão: guardar o último estado desenhado e atualizar cada campo apenas quando seu valor mudar; medir a diferença em GTWIN antes de trocar o desenho incremental existente.
    ```harbour
    IF nScore != nOldScore
       hb_DispOutAt( 1, 10, StrZero( nScore, 6 ), "G+/N" )
       nOldScore := nScore
    ENDIF
    ```

15. **O campo usa glifos OEM sem verificar a codepage ativa.** `Chr(219)`, `Chr(178)`, `Chr(201)` e similares (26-28, 445-452) dependem da página de código e da fonte do console. Em um terminal com codepage diferente, blocos e moldura podem virar caracteres incorretos.

    Sugestão: documentar e testar a combinação suportada de GTWIN, codepage e fonte no terminal real. Manter uma alternativa ASCII simples para ambientes onde os glifos de byte OEM não renderizem corretamente.
    ```harbour
    cBlock := IIF( lOemConsole, Chr( 219 ), "[]" )
    ```
    Selecionar o modo explicitamente conforme o terminal testado, sem inferir codepage somente pela presença do GTWIN.

## Conferência de APIs Harbour

Compilei um programa de teste isolado numa pasta temporária fora do projeto com `C:\hb30\bin\hbmk2.exe`, `-gtwin` e `hbwin.hbc`. O Harbour 3.0.0 traduziu as chamadas usadas no teste sem erro: `hb_MilliSeconds()`, `hb_DirBase()`, `GetEnv()`, `hb_FSize()`, `hb_RandomInt()`, `hb_gtInfo()`, `hb_DispOutAt()`, `hb_keyClear()`, `hb_idleSleep()`, `hb_MemoWrit()` e `wapi_PlaySound()`. O resultado confirma a tradução PRG para C nessa instalação, não a vinculação do executável, a existência de arquivos/diretórios graváveis ou a reprodução de áudio.
