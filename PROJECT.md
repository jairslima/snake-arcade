# Snake Arcade by Jair Lima

Jogo Snake em modo texto (terminal), escrito em Harbour 3.0.0, criado para mostrar o potencial de jogos ASCII estilo fliperama com Clipper/Harbour, incluindo som.

## Stack e dependências

- Harbour 3.0.0 (Rev. 16951) em `C:\hb30\bin`, GT `-gtwin` (console real do Windows, roda dentro do terminal)
- `hbwin` (`wapi_PlaySound`) para tocar os efeitos sonoros de forma assíncrona
- Sem dependências externas: os WAVs são sintetizados no código (onda quadrada, 8 bits, 11025 Hz) e gravados em `%TEMP%\snk_*.wav` a cada execução

## Estrutura

```
snake.prg    - todo o jogo (abertura, jogo, recordes, som, autoteste)
snake.hbp    - projeto hbmk2 (-gtwin, hbwin.hbc)
build.bat    - compila snake.exe
snake.sco    - placar de recordes (criado ao gravar o primeiro recorde, ao lado do .exe)
```

## Comandos

```
build.bat                  REM compila snake.exe
snake.exe                  REM joga (terminal mínimo 80x25)
snake.exe --selftest       REM gera os WAVs, testa spawn/colisão de 12 fases e toca um som (sem UI)
```

## Como se joga

Setas ou WASD movem, P pausa, M liga/desliga o som, ESC sai. Cada fruta `()` vale 10 x fase e faz crescer. A cada 3 frutas surge uma bonus `$$` piscando por tempo limitado (50 + tempo restante). 8 frutas passam de fase: mais velocidade e mais obstáculos. 3 vidas (máximo 5), vida extra a cada 1000 pontos. Top 5 de recordes com iniciais de 3 letras, estilo fliperama.

## Decisões

- **Tick por relógio** (`hb_MilliSeconds()` + `Inkey(0.01)`), não `Inkey(tempo)`: assim apertar tecla não acelera a cobra. Fila de até 2 direções evita perder curvas rápidas e proíbe reversão de 180 graus.
- **Desenho incremental**: só cabeça, cauda, frutas e HUD são redesenhados por tick (sem flicker). Tela cheia só em pausa/retorno de banner.
- **Cada célula = 2 colunas** para o campo ficar quadrado (36 x 19 células, 72 x 19 caracteres).
- **Fonte em ASCII puro**: glifos de bloco/caixa via `Chr(219/178/177/201...)` (codepage OEM), evitando o problema de CP437 do `produtos.prg`.
- **Som**: um canal só (`SND_ASYNC`), um efeito novo corta o anterior. Sem música de fundo de propósito, pois `PlaySound` não mixa canais.

## Estado atual (2026-10-08)

Compila sem erros, autoteste passa (saída 0, `snake_selftest.log`). Usuário já jogou e gravou recorde. Segunda opinião do Copilot em `REVIEW.md` (achado do rollover de `hb_MilliSeconds()` refutado por teste) e guia de reuso em `BEST_PRACTICES.md`. Correções aplicadas: spawn por lista de células livres, fila de teclas, bônus em ~7 s reais, vidas extras em laço, aviso de recorde não gravado, autoteste ampliado.

## Próximos passos / ideias

- Ajustar velocidade/dificuldade conforme o teste do usuário
- Música de fundo (exigiria mixagem ou `winmm` MCI com segundo canal)
- Outros jogos do mesmo molde: Pong, Tetris, Space Invaders
- Deploy opcional: copiar `snake.exe` para `C:\Users\jairs\bin\` e criar atalho

## Problemas conhecidos

- Nenhum confirmado até agora.
