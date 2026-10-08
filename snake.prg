/*
 * Snake Arcade by Jair Lima
 *
 * Jogo Snake em modo texto (Harbour 3.0 + GTWIN) com a experiencia de
 * fliperama: tela de abertura animada, vidas, fases com obstaculos,
 * velocidade crescente, fruta bonus com tempo, placar de recordes com
 * iniciais e efeitos sonoros sintetizados (WAV gerado em tempo de execucao
 * e tocado de forma assincrona via hbwin).
 *
 * Fonte propositalmente em ASCII puro: os glifos de bloco/caixa sao
 * montados com Chr() (codepage OEM do console).
 */

#include "inkey.ch"
#include "setcurs.ch"
#include "hbgtinfo.ch"

#define FW         36            // largura do campo em celulas (cada celula = 2 colunas)
#define FH         19            // altura do campo em celulas
#define X0          4            // coluna inicial do campo
#define Y0          4            // linha inicial do campo
#define NFOOD_LVL   8            // frutas para passar de fase
#define HI_FILE    "snake.sco"
#define SND_FLAGS  131075        // SND_ASYNC + SND_FILENAME + SND_NODEFAULT

#define BLK        Chr( 219 )
#define SHD        Chr( 178 )
#define MSH        Chr( 177 )

STATIC s_aHi
STATIC s_cTmp
STATIC s_lSnd := .T.

PROCEDURE Main( cArg )

   hb_gtInfo( HB_GTI_WINTITLE, "Snake Arcade by Jair Lima" )

   InitSound()
   LoadHi()

   IF cArg != NIL .AND. Lower( cArg ) == "--selftest"
      SelfTest()
      RETURN
   ENDIF

   IF MaxRow() < 24 .OR. MaxCol() < 79
      ? "Snake Arcade by Jair Lima precisa de um terminal de pelo menos 80x25."
      RETURN
   ENDIF

   SetCursor( SC_NONE )
   SetColor( "W/N" )

   DO WHILE TitleScreen()
      PlayGame()
   ENDDO

   SetColor( "W/N" )
   CLS
   SetCursor( SC_NORMAL )
   ? "Obrigado por jogar Snake Arcade by Jair Lima!"
   ?

RETURN

// ---------------------------------------------------------------------
// Tela de abertura
// ---------------------------------------------------------------------

STATIC FUNCTION TitleScreen()

   LOCAL aLet := { ;
      { " ####", "#    ", " ### ", "    #", "#### " }, ;
      { "#   #", "##  #", "# # #", "#  ##", "#   #" }, ;
      { " ### ", "#   #", "#####", "#   #", "#   #" }, ;
      { "#   #", "#  # ", "###  ", "#  # ", "#   #" }, ;
      { "#####", "#    ", "#### ", "#    ", "#####" } }
   LOCAL aClr := { "R+/N", "Y+/N", "G+/N", "C+/N", "M+/N" }
   LOCAL nTick := 0, nSx := 0, k, i, r, nCol, cRow, nLen := 14

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "S N A K E   A R C A D E   by Jair Lima", 80 ), "N/W" )

   hb_DispOutAt( 8, 0, PadC( "- - -  A R C A D E   E D I T I O N  - - -", 80 ), "W/N" )

   hb_DispOutAt( 10, 0, PadC( "HIGH SCORES", 80 ), "Y+/N" )
   FOR i := 1 TO Len( s_aHi )
      hb_DispOutAt( 10 + i, 30, Str( i, 1 ) + "  " + s_aHi[ i ][ 1 ] + "  " + StrZero( s_aHi[ i ][ 2 ], 6 ), ;
         IIF( i == 1, "G+/N", "W/N" ) )
   NEXT

   hb_DispOutAt( 22, 0, PadC( "SETAS ou WASD: mover   P: pausa   M: som   ESC: sair", 80 ), "W/N" )
   hb_DispOutAt( 24, 0, PadC( "(c) Jair Lima - Harbour + GTWIN", 79 ), "N+/N" )

   DO WHILE .T.

      // logo colorido com ciclo de cores
      FOR i := 1 TO 5
         nCol := 9 + ( i - 1 ) * 13
         FOR r := 1 TO 5
            cRow := StrTran( StrTran( aLet[ i ][ r ], "#", BLK + BLK ), " ", "  " )
            hb_DispOutAt( 2 + r, nCol, cRow, aClr[ ( Int( nTick / 3 ) + i ) % 5 + 1 ] )
         NEXT
      NEXT

      // "INSERT COIN" piscando
      IF nTick % 10 < 6
         hb_DispOutAt( 18, 0, PadC( "*** INSERT COIN - PRESS ENTER ***", 80 ), "R+/N" )
      ELSE
         hb_DispOutAt( 18, 0, Space( 80 ), "W/N" )
      ENDIF

      // cobra de demonstracao atravessando a tela
      hb_DispOutAt( 20, 0, Space( 80 ), "W/N" )
      FOR i := 1 TO nLen
         IF nSx - i >= 0 .AND. nSx - i <= 79
            hb_DispOutAt( 20, nSx - i, SHD, "G/N" )
         ENDIF
      NEXT
      IF nSx >= 0 .AND. nSx <= 79
         hb_DispOutAt( 20, nSx, BLK, "G+/N" )
      ENDIF
      IF nSx + 4 <= 79 .AND. nSx + 4 >= 0
         hb_DispOutAt( 20, nSx + 4, "o", "R+/N" )
      ENDIF
      nSx++
      IF nSx > 79 + nLen
         nSx := 0
      ENDIF

      hb_DispOutAt( 23, 0, PadC( IIF( s_lSnd, "SOM: LIGADO", "SOM: DESLIGADO" ), 80 ), "N+/N" )

      k := Inkey( 0.07 )
      nTick++

      DO CASE
      CASE k == K_ENTER .OR. k == 32
         PlaySfx( "coin" )
         Inkey( 0.5 )
         RETURN .T.
      CASE k == K_ESC
         RETURN .F.
      CASE k == Asc( "m" ) .OR. k == Asc( "M" )
         s_lSnd := ! s_lSnd
      ENDCASE

   ENDDO

RETURN .T.

// ---------------------------------------------------------------------
// Jogo
// ---------------------------------------------------------------------

STATIC PROCEDURE PlayGame()

   LOCAL nScore := 0, nLives := 3, nLevel := 1, nEaten := 0, nExtra := 1000
   LOCAL aSnake, aObs, aFood, aBonus, aQ
   LOCAL nDx, nDy, nDelay, nNext, nHx, nHy, nGrow, nBonusT, nBonusMax, nTick, nMid, aLast
   LOCAL k, d, lDead, lNew, lQuit := .F., aHead, i

   nMid := Int( FH / 2 )

   DrawFrame()
   aObs := MakeObs( nLevel )
   nDelay := LevelDelay( nLevel )

   DO WHILE nLives > 0 .AND. ! lQuit

      aSnake := { { 3, nMid }, { 4, nMid }, { 5, nMid }, { 6, nMid } }
      nDx := 1
      nDy := 0
      aQ := {}
      nGrow := 0
      aBonus := NIL
      nBonusT := 0
      nBonusMax := 1
      nTick := 0
      lDead := .F.
      lNew := .F.
      aFood := NewFood( aSnake, aObs, NIL )

      Hud( nScore, nLives, nLevel, nEaten, 0 )
      RedrawField( aSnake, aObs, aFood, aBonus, nTick )
      Banner( "READY!", "G+/N" )
      PlaySfx( "start" )
      Inkey( 1.3 )
      RedrawField( aSnake, aObs, aFood, aBonus, nTick )
      hb_keyClear()

      DO WHILE ! lDead .AND. ! lNew .AND. ! lQuit

         nNext := hb_MilliSeconds() + nDelay
         DO WHILE hb_MilliSeconds() < nNext
            k := Inkey( 0.01 )
            IF k == 0
               LOOP
            ENDIF
            d := KeyToDir( k )
            IF d != NIL
               // compara com a ultima direcao efetiva: descarta repeticao e reversao
               aLast := IIF( Len( aQ ) > 0, ATail( aQ ), { nDx, nDy } )
               IF ! ( d[ 1 ] == aLast[ 1 ] .AND. d[ 2 ] == aLast[ 2 ] ) .AND. ;
                  ! ( d[ 1 ] == -aLast[ 1 ] .AND. d[ 2 ] == -aLast[ 2 ] )
                  IF Len( aQ ) >= 2
                     aQ[ 2 ] := d
                  ELSE
                     AAdd( aQ, d )
                  ENDIF
               ENDIF
            ELSEIF k == Asc( "p" ) .OR. k == Asc( "P" )
               PlaySfx( "pause" )
               Banner( "PAUSED - press any key", "Y+/N" )
               Inkey( 0 )
               RedrawField( aSnake, aObs, aFood, aBonus, nTick )
               nNext := hb_MilliSeconds() + nDelay
            ELSEIF k == Asc( "m" ) .OR. k == Asc( "M" )
               s_lSnd := ! s_lSnd
            ELSEIF k == K_ESC
               Banner( "QUIT GAME? (S/N)", "R+/N" )
               DO WHILE .T.
                  k := Inkey( 0 )
                  IF k == Asc( "s" ) .OR. k == Asc( "S" ) .OR. k == Asc( "y" ) .OR. k == Asc( "Y" )
                     lQuit := .T.
                     EXIT
                  ELSEIF k == Asc( "n" ) .OR. k == Asc( "N" ) .OR. k == K_ESC
                     EXIT
                  ENDIF
               ENDDO
               IF lQuit
                  EXIT
               ENDIF
               RedrawField( aSnake, aObs, aFood, aBonus, nTick )
               nNext := hb_MilliSeconds() + nDelay
            ENDIF
         ENDDO

         IF lQuit
            EXIT
         ENDIF

         nTick++

         // aplica proxima direcao da fila (sem reversao de 180 graus)
         IF Len( aQ ) > 0
            d := aQ[ 1 ]
            hb_ADel( aQ, 1, .T. )
            IF ! ( d[ 1 ] == -nDx .AND. d[ 2 ] == -nDy )
               nDx := d[ 1 ]
               nDy := d[ 2 ]
            ENDIF
         ENDIF

         aHead := ATail( aSnake )
         nHx := aHead[ 1 ] + nDx
         nHy := aHead[ 2 ] + nDy

         lDead := ( nHx < 0 .OR. nHx >= FW .OR. nHy < 0 .OR. nHy >= FH )
         IF ! lDead
            lDead := HitObs( aObs, nHx, nHy )
         ENDIF
         IF ! lDead
            lDead := HitSnake( aSnake, nHx, nHy, nGrow == 0 )
         ENDIF

         IF lDead
            PlaySfx( "die" )
            FOR i := 1 TO 8
               DrawSnake( aSnake, IIF( i % 2 == 1, "R+/N", "W+/N" ) )
               Inkey( 0.12 )
            NEXT
            nLives--
            Inkey( 0.4 )
            LOOP
         ENDIF

         // remove a cauda antes de desenhar a nova cabeca
         IF nGrow > 0
            nGrow--
         ELSE
            PutCell( aSnake[ 1 ][ 1 ], aSnake[ 1 ][ 2 ], "  ", "W/N" )
            hb_ADel( aSnake, 1, .T. )
         ENDIF

         PutCell( aHead[ 1 ], aHead[ 2 ], SHD + SHD, "G/N" )
         AAdd( aSnake, { nHx, nHy } )
         PutCell( nHx, nHy, BLK + BLK, "G+/N" )

         // fruta normal
         IF aFood != NIL .AND. nHx == aFood[ 1 ] .AND. nHy == aFood[ 2 ]
            nScore += 10 * nLevel
            nGrow += 2
            nEaten++
            PlaySfx( "eat" )
            aFood := NewFood( aSnake, aObs, aBonus )
            IF aFood == NIL
               lNew := .T.          // tabuleiro cheio: fase concluida
            ELSE
               PutCell( aFood[ 1 ], aFood[ 2 ], "()", "R+/N" )
            ENDIF
            IF nEaten % 3 == 0 .AND. aBonus == NIL .AND. nEaten < NFOOD_LVL .AND. aFood != NIL
               aBonus := NewFood( aSnake, aObs, aFood )
               // duracao fixa de ~7 segundos reais, independente da velocidade da fase
               nBonusMax := Max( 1, Int( 7000 / nDelay ) )
               nBonusT := nBonusMax
            ENDIF
            IF nEaten >= NFOOD_LVL
               lNew := .T.
            ENDIF
         ENDIF

         // fruta bonus (com tempo)
         IF aBonus != NIL
            IF nHx == aBonus[ 1 ] .AND. nHy == aBonus[ 2 ]
               nScore += 50 + Int( nBonusT * nDelay / 100 )
               PlaySfx( "bonus" )
               aBonus := NIL
               nBonusT := 0
            ELSE
               nBonusT--
               IF nBonusT <= 0
                  PutCell( aBonus[ 1 ], aBonus[ 2 ], "  ", "W/N" )
                  aBonus := NIL
                  nBonusT := 0
               ELSE
                  PutCell( aBonus[ 1 ], aBonus[ 2 ], "$$", IIF( nTick % 2 == 0, "Y+/N", "R+/N" ) )
               ENDIF
            ENDIF
         ENDIF

         // vidas extras: consome todos os marcos de 1000 pontos alcancados
         DO WHILE nScore >= nExtra
            nExtra += 1000
            IF nLives < 5
               nLives++
               PlaySfx( "level" )
            ENDIF
         ENDDO

         Hud( nScore, nLives, nLevel, nEaten, Int( nBonusT * 20 / nBonusMax ) )

      ENDDO

      IF lNew .AND. ! lQuit
         nLevel++
         nEaten := 0
         nScore += 100 * ( nLevel - 1 )
         nDelay := LevelDelay( nLevel )
         PlaySfx( "level" )
         Hud( nScore, nLives, nLevel, nEaten, 0 )
         Banner( "LEVEL " + LTrim( Str( nLevel ) ) + " !", "Y+/N" )
         Inkey( 1.8 )
         aObs := MakeObs( nLevel )
      ENDIF

   ENDDO

   IF ! lQuit
      Banner( "G A M E   O V E R", "R+/N" )
      PlaySfx( "gameover" )
      Inkey( 3 )
      hb_keyClear()
   ENDIF

   CheckHi( nScore )

RETURN

STATIC FUNCTION LevelDelay( nLevel )
RETURN Max( 40, 140 - 12 * ( nLevel - 1 ) )

STATIC FUNCTION KeyToDir( k )

   DO CASE
   CASE k == K_UP .OR. k == Asc( "w" ) .OR. k == Asc( "W" )
      RETURN { 0, -1 }
   CASE k == K_DOWN .OR. k == Asc( "s" ) .OR. k == Asc( "S" )
      RETURN { 0, 1 }
   CASE k == K_LEFT .OR. k == Asc( "a" ) .OR. k == Asc( "A" )
      RETURN { -1, 0 }
   CASE k == K_RIGHT .OR. k == Asc( "d" ) .OR. k == Asc( "D" )
      RETURN { 1, 0 }
   ENDCASE

RETURN NIL

STATIC FUNCTION HitObs( aObs, x, y )
RETURN AScan( aObs, {| c | c[ 1 ] == x .AND. c[ 2 ] == y } ) > 0

STATIC FUNCTION HitSnake( aSnake, x, y, lSkipTail )

   LOCAL i

   FOR i := IIF( lSkipTail, 2, 1 ) TO Len( aSnake )
      IF aSnake[ i ][ 1 ] == x .AND. aSnake[ i ][ 2 ] == y
         RETURN .T.
      ENDIF
   NEXT

RETURN .F.

STATIC FUNCTION NewFood( aSnake, aObs, aOther )

   LOCAL x, y, aFree := {}

   // enumera as celulas livres e sorteia uma: nunca devolve posicao ocupada
   FOR y := 0 TO FH - 1
      FOR x := 0 TO FW - 1
         IF HitSnake( aSnake, x, y, .F. ) .OR. HitObs( aObs, x, y )
            LOOP
         ENDIF
         IF aOther != NIL .AND. aOther[ 1 ] == x .AND. aOther[ 2 ] == y
            LOOP
         ENDIF
         AAdd( aFree, { x, y } )
      NEXT
   NEXT

   IF Empty( aFree )
      RETURN NIL
   ENDIF

RETURN aFree[ hb_RandomInt( 1, Len( aFree ) ) ]

STATIC FUNCTION MakeObs( nLevel )

   LOCAL aObs := {}, nBlocks := Min( ( nLevel - 1 ) * 2, 12 )
   LOCAL i, j, nLen, lH, x, y, cx, cy, nMid := Int( FH / 2 )

   FOR i := 1 TO nBlocks
      nLen := hb_RandomInt( 3, 6 )
      lH := ( hb_RandomInt( 0, 1 ) == 0 )
      x := hb_RandomInt( 1, FW - 2 )
      y := hb_RandomInt( 1, FH - 2 )
      FOR j := 0 TO nLen - 1
         cx := x + IIF( lH, j, 0 )
         cy := y + IIF( lH, 0, j )
         IF cx < 1 .OR. cx > FW - 2 .OR. cy < 1 .OR. cy > FH - 2
            LOOP
         ENDIF
         // zona segura: faixa central por onde a cobra nasce
         IF Abs( cy - nMid ) <= 1 .AND. cx <= Int( FW / 2 ) + 2
            LOOP
         ENDIF
         IF ! HitObs( aObs, cx, cy )
            AAdd( aObs, { cx, cy } )
         ENDIF
      NEXT
   NEXT

RETURN aObs

// ---------------------------------------------------------------------
// Desenho
// ---------------------------------------------------------------------

STATIC PROCEDURE PutCell( x, y, cTxt, cClr )
   hb_DispOutAt( Y0 + y, X0 + 2 * x, cTxt, cClr )
RETURN

STATIC PROCEDURE DrawFrame()

   LOCAL i, cClr := "B+/N"

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "S N A K E   A R C A D E   by Jair Lima", 80 ), "N/W" )

   hb_DispOutAt( Y0 - 1, X0 - 1, Chr( 201 ) + Replicate( Chr( 205 ), 2 * FW ) + Chr( 187 ), cClr )
   FOR i := 0 TO FH - 1
      hb_DispOutAt( Y0 + i, X0 - 1, Chr( 186 ), cClr )
      hb_DispOutAt( Y0 + i, X0 + 2 * FW, Chr( 186 ), cClr )
   NEXT
   hb_DispOutAt( Y0 + FH, X0 - 1, Chr( 200 ) + Replicate( Chr( 205 ), 2 * FW ) + Chr( 188 ), cClr )
   hb_DispOutAt( Y0 + FH + 1, 0, PadC( "SETAS/WASD mover   P pausa   M som   ESC sair", 80 ), "N+/N" )

RETURN

STATIC PROCEDURE Hud( nScore, nLives, nLevel, nEaten, nBonusT )

   LOCAL nHi := Max( nScore, s_aHi[ 1 ][ 2 ] )

   hb_DispOutAt( 1, 4, "SCORE", "W/N" )
   hb_DispOutAt( 1, 10, StrZero( Min( nScore, 999999 ), 6 ), "G+/N" )
   hb_DispOutAt( 1, 22, "HI", "W/N" )
   hb_DispOutAt( 1, 25, StrZero( nHi, 6 ), "Y+/N" )
   hb_DispOutAt( 1, 38, "LEVEL", "W/N" )
   hb_DispOutAt( 1, 44, StrZero( nLevel, 2 ), "C+/N" )
   hb_DispOutAt( 1, 54, "LIVES", "W/N" )
   hb_DispOutAt( 1, 60, PadR( Replicate( BLK + " ", nLives ), 10 ), "R+/N" )

   hb_DispOutAt( 2, 4, "FOOD ", "W/N" )
   hb_DispOutAt( 2, 9, Replicate( BLK, nEaten ) + Replicate( MSH, NFOOD_LVL - nEaten ), "G/N" )
   hb_DispOutAt( 2, 38, "BONUS", "W/N" )
   hb_DispOutAt( 2, 44, PadR( Replicate( BLK, Int( nBonusT / 4 ) ), 20 ), "Y+/N" )

RETURN

STATIC PROCEDURE DrawSnake( aSnake, cClr )

   LOCAL i

   FOR i := 1 TO Len( aSnake )
      PutCell( aSnake[ i ][ 1 ], aSnake[ i ][ 2 ], IIF( i == Len( aSnake ), BLK + BLK, SHD + SHD ), cClr )
   NEXT

RETURN

STATIC PROCEDURE RedrawField( aSnake, aObs, aFood, aBonus, nTick )

   LOCAL i

   FOR i := 0 TO FH - 1
      hb_DispOutAt( Y0 + i, X0, Space( 2 * FW ), "W/N" )
   NEXT
   FOR i := 1 TO Len( aObs )
      PutCell( aObs[ i ][ 1 ], aObs[ i ][ 2 ], MSH + MSH, "W+/B" )
   NEXT
   FOR i := 1 TO Len( aSnake ) - 1
      PutCell( aSnake[ i ][ 1 ], aSnake[ i ][ 2 ], SHD + SHD, "G/N" )
   NEXT
   PutCell( ATail( aSnake )[ 1 ], ATail( aSnake )[ 2 ], BLK + BLK, "G+/N" )
   IF aFood != NIL
      PutCell( aFood[ 1 ], aFood[ 2 ], "()", "R+/N" )
   ENDIF
   IF aBonus != NIL
      PutCell( aBonus[ 1 ], aBonus[ 2 ], "$$", IIF( nTick % 2 == 0, "Y+/N", "R+/N" ) )
   ENDIF

RETURN

STATIC PROCEDURE Banner( cMsg, cClr )

   LOCAL c := "  " + cMsg + "  "
   LOCAL nCol := X0 + FW - Int( Len( c ) / 2 )
   LOCAL nRow := Y0 + Int( FH / 2 )

   hb_DispOutAt( nRow - 1, nCol - 1, Space( Len( c ) + 2 ), cClr )
   hb_DispOutAt( nRow, nCol - 1, " " + c + " ", cClr )
   hb_DispOutAt( nRow + 1, nCol - 1, Space( Len( c ) + 2 ), cClr )

RETURN

// ---------------------------------------------------------------------
// Recordes
// ---------------------------------------------------------------------

STATIC PROCEDURE LoadHi()

   LOCAL cFile := hb_DirBase() + HI_FILE
   LOCAL aLines, cLine, aTmp := {}

   IF File( cFile )
      aLines := hb_ATokens( StrTran( MemoRead( cFile ), Chr( 13 ), "" ), Chr( 10 ) )
      FOR EACH cLine IN aLines
         IF Len( cLine ) >= 5
            AAdd( aTmp, { Upper( Left( cLine, 3 ) ), Val( SubStr( cLine, 5 ) ) } )
         ENDIF
      NEXT
   ENDIF

   IF Len( aTmp ) >= 5
      ASize( aTmp, 5 )
      s_aHi := aTmp
   ELSE
      s_aHi := { { "JAL", 1000 }, { "ABC", 800 }, { "SNK", 600 }, { "PAI", 400 }, { "ZZZ", 200 } }
   ENDIF

RETURN

STATIC FUNCTION SaveHi()

   LOCAL cTxt := "", a

   FOR EACH a IN s_aHi
      cTxt += a[ 1 ] + " " + LTrim( Str( a[ 2 ] ) ) + Chr( 13 ) + Chr( 10 )
   NEXT

RETURN hb_MemoWrit( hb_DirBase() + HI_FILE, cTxt )

STATIC PROCEDURE CheckHi( nScore )

   LOCAL nPos := 0, i, cName

   FOR i := 1 TO Len( s_aHi )
      IF nScore > s_aHi[ i ][ 2 ]
         nPos := i
         EXIT
      ENDIF
   NEXT

   IF nPos == 0 .OR. nScore <= 0
      RETURN
   ENDIF

   PlaySfx( "hiscore" )
   cName := EnterInitials( nScore )
   hb_AIns( s_aHi, nPos, { cName, nScore }, .T. )
   ASize( s_aHi, 5 )
   IF ! SaveHi()
      hb_DispOutAt( 17, 0, PadC( "ATENCAO: recorde nao gravado (pasta sem permissao)", 80 ), "R+/N" )
      Inkey( 3 )
   ENDIF

RETURN

STATIC FUNCTION EnterInitials( nScore )

   LOCAL aCh := { 65, 65, 65 }, nPos := 1, k, i, cClr

   SetColor( "W/N" )
   CLS
   hb_DispOutAt( 0, 0, PadC( "S N A K E   A R C A D E   by Jair Lima", 80 ), "N/W" )
   hb_DispOutAt( 6, 0, PadC( "*** NEW HIGH SCORE ***", 80 ), "Y+/N" )
   hb_DispOutAt( 8, 0, PadC( "SCORE " + StrZero( nScore, 6 ), 80 ), "G+/N" )
   hb_DispOutAt( 11, 0, PadC( "ENTER YOUR INITIALS", 80 ), "W/N" )
   hb_DispOutAt( 20, 0, PadC( "CIMA/BAIXO: letra   DIREITA/ENTER: proxima   ESQ: voltar", 80 ), "N+/N" )

   hb_keyClear()

   DO WHILE .T.

      FOR i := 1 TO 3
         cClr := IIF( i == nPos, "N/W", "W+/N" )
         hb_DispOutAt( 14, 35 + ( i - 1 ) * 4, " " + Chr( aCh[ i ] ) + " ", cClr )
      NEXT

      k := Inkey( 0 )

      DO CASE
      CASE k == K_UP
         aCh[ nPos ] := IIF( aCh[ nPos ] >= 90, 65, aCh[ nPos ] + 1 )
         PlaySfx( "pause" )
      CASE k == K_DOWN
         aCh[ nPos ] := IIF( aCh[ nPos ] <= 65, 90, aCh[ nPos ] - 1 )
         PlaySfx( "pause" )
      CASE k == K_LEFT
         nPos := Max( 1, nPos - 1 )
      CASE k == K_RIGHT .OR. k == K_ENTER
         IF nPos == 3
            EXIT
         ENDIF
         nPos++
         PlaySfx( "eat" )
      CASE ( k >= 65 .AND. k <= 90 ) .OR. ( k >= 97 .AND. k <= 122 )
         aCh[ nPos ] := Asc( Upper( Chr( k ) ) )
         PlaySfx( "eat" )
         IF nPos == 3
            EXIT
         ENDIF
         nPos++
      ENDCASE

   ENDDO

   hb_DispOutAt( 14, 35 + ( 3 - 1 ) * 4, " " + Chr( aCh[ 3 ] ) + " ", "W+/N" )
   PlaySfx( "level" )
   Inkey( 1 )

RETURN Chr( aCh[ 1 ] ) + Chr( aCh[ 2 ] ) + Chr( aCh[ 3 ] )

// ---------------------------------------------------------------------
// Som: WAV 8 bits sintetizado em onda quadrada, tocado via winmm
// ---------------------------------------------------------------------

STATIC PROCEDURE InitSound()

   s_cTmp := GetEnv( "TEMP" )
   IF Empty( s_cTmp )
      s_cTmp := "."
   ENDIF
   IF ! Right( s_cTmp, 1 ) == "\"
      s_cTmp += "\"
   ENDIF

   MakeWav( "coin",     { { 988, 988, 70 }, { 1319, 1319, 330 } } )
   MakeWav( "start",    { { 523, 523, 90 }, { 659, 659, 90 }, { 784, 784, 90 }, { 1047, 1047, 260 } } )
   MakeWav( "eat",      { { 500, 1100, 75 } } )
   MakeWav( "bonus",    { { 1047, 1047, 60 }, { 1319, 1319, 60 }, { 1568, 1568, 60 }, { 2093, 2093, 160 } } )
   MakeWav( "die",      { { 700, 120, 650 } } )
   MakeWav( "level",    { { 523, 523, 90 }, { 659, 659, 90 }, { 784, 784, 90 }, { 1047, 1047, 90 }, ;
                          { 784, 784, 90 }, { 1047, 1047, 320 } } )
   MakeWav( "gameover", { { 392, 392, 280 }, { 330, 330, 280 }, { 262, 262, 280 }, { 196, 196, 700 } } )
   MakeWav( "pause",    { { 600, 600, 50 }, { 400, 400, 80 } } )
   MakeWav( "hiscore",  { { 784, 784, 100 }, { 988, 988, 100 }, { 1175, 1175, 100 }, { 1568, 1568, 100 }, ;
                          { 1175, 1175, 100 }, { 1568, 1568, 400 } } )

RETURN

STATIC PROCEDURE MakeWav( cName, aNotes )

   LOCAL nRate := 11025
   LOCAL cData := "", a, i, nSamp, nPh, f, nAmp, nVal, cHdr

   FOR EACH a IN aNotes
      nSamp := Int( a[ 3 ] * nRate / 1000 )
      nPh := 0
      FOR i := 1 TO nSamp
         f := a[ 1 ] + ( a[ 2 ] - a[ 1 ] ) * i / nSamp
         nPh += f / nRate
         nPh -= Int( nPh )
         nAmp := 70 * ( 1 - 0.6 * i / nSamp )
         nVal := IIF( nPh < 0.5, 128 + nAmp, 128 - nAmp )
         cData += Chr( Int( nVal ) )
      NEXT
   NEXT

   cHdr := "RIFF" + L2Bin( 36 + Len( cData ) ) + "WAVEfmt " + L2Bin( 16 ) + I2Bin( 1 ) + I2Bin( 1 ) + ;
      L2Bin( nRate ) + L2Bin( nRate ) + I2Bin( 1 ) + I2Bin( 8 ) + "data" + L2Bin( Len( cData ) )

   hb_MemoWrit( s_cTmp + "snk_" + cName + ".wav", cHdr + cData )

RETURN

STATIC PROCEDURE PlaySfx( cName )

   IF s_lSnd
      wapi_PlaySound( s_cTmp + "snk_" + cName + ".wav", NIL, SND_FLAGS )
   ENDIF

RETURN

// ---------------------------------------------------------------------
// Autoteste sem interface (snake --selftest)
// ---------------------------------------------------------------------

STATIC PROCEDURE SelfTest()

   LOCAL aSnake := { { 3, 9 }, { 4, 9 }, { 5, 9 }, { 6, 9 } }
   LOCAL aObs, aFood, aFull, i, nBad := 0, cWav

   ? "WAV em: " + s_cTmp
   FOR EACH cWav IN { "coin", "start", "eat", "bonus", "die", "level", "gameover", "pause", "hiscore" }
      ? PadR( cWav, 10 ) + IIF( File( s_cTmp + "snk_" + cWav + ".wav" ), "OK " + ;
         LTrim( Str( hb_FSize( s_cTmp + "snk_" + cWav + ".wav" ) ) ) + " bytes", "FALTANDO" )
   NEXT

   FOR i := 1 TO 12
      aObs := MakeObs( i )
      aFood := NewFood( aSnake, aObs, NIL )
      IF HitObs( aObs, aFood[ 1 ], aFood[ 2 ] ) .OR. HitSnake( aSnake, aFood[ 1 ], aFood[ 2 ], .F. )
         nBad++
      ENDIF
      IF HitSnake( aSnake, 7, 9, .F. ) .OR. HitObs( aObs, 7, 9 ) .OR. HitObs( aObs, 10, 9 )
         nBad++
      ENDIF
   NEXT
   // regras deterministas: cauda que sai nao colide, cauda que fica colide
   IF HitSnake( aSnake, 3, 9, .T. ) .OR. ! HitSnake( aSnake, 3, 9, .F. ) .OR. ! HitSnake( aSnake, 4, 9, .T. )
      nBad++
      ? "FALHA: regra da cauda"
   ENDIF
   // tabuleiro cheio: NewFood deve devolver NIL, nunca uma celula ocupada
   aFull := {}
   FOR i := 0 TO FW * FH - 1
      AAdd( aFull, { i % FW, Int( i / FW ) } )
   NEXT
   IF NewFood( aFull, {}, NIL ) != NIL
      nBad++
      ? "FALHA: NewFood em tabuleiro cheio"
   ENDIF
   // um unico espaco livre: NewFood deve achar exatamente ele
   ADel( aFull, 100 )
   ASize( aFull, Len( aFull ) - 1 )
   aFood := NewFood( aFull, {}, NIL )
   IF aFood == NIL .OR. aFood[ 1 ] != 99 % FW .OR. aFood[ 2 ] != Int( 99 / FW )
      nBad++
      ? "FALHA: NewFood com uma celula livre"
   ENDIF
   ? "Fases testadas: 12, falhas: " + LTrim( Str( nBad ) )
   ? "Recordes: " + LTrim( Str( Len( s_aHi ) ) ) + " entradas, topo " + s_aHi[ 1 ][ 1 ] + " " + LTrim( Str( s_aHi[ 1 ][ 2 ] ) )
   PlaySfx( "level" )
   hb_idleSleep( 1.5 )
   ? "Autoteste concluido: " + IIF( nBad == 0, "OK", "COM FALHAS" )
   hb_MemoWrit( hb_DirBase() + "snake_selftest.log", ;
      "falhas=" + LTrim( Str( nBad ) ) + hb_eol() )
   ErrorLevel( IIF( nBad == 0, 0, 1 ) )

RETURN
