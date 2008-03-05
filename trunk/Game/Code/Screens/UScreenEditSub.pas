unit UScreenEditSub;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}
{$I switches.inc}

uses
    UMenu,
    UMusic,
    SDL,
    SysUtils,
    UFiles,
    UTime,
    USongs,
    USong,
    UIni,
    ULog,
    UTexture,
    UMenuText,
    ULyrics_bak,
    ULyrics,
    Math,
    OpenGL12,
    {$IFDEF UseMIDIPort}
    MidiOut,
    {$ENDIF}
    UThemes;

type
  TScreenEditSub = class(TMenu)
    private
      //Variable is True if no SOng is loaded 
      Error:        Boolean;
      
      TextNote:     integer;
      TextSentence: integer;
      TextTitle:    integer;
      TextArtist:   integer;
      TextMp3:      integer;
      TextBPM:      integer;
      TextGAP:      integer;
      TextDebug:    integer;
      TextNStart:   integer;
      TextNDlugosc: integer;
      TextNTon:     integer;
      TextNText:    integer;
      AktNuta:      integer;
      PlaySentence: boolean;
      PlaySentenceMidi: boolean;
      PlayStopTime: real;
      LastClick:    integer;
      Click:        boolean;
      CopySrc:      integer;

      {$IFDEF UseMIDIPort}
      MidiOut:      TMidiOutput;
      {$endif}

      MidiStart:    real;
      MidiStop:     real;
      MidiTime:     real;
      MidiPos:      real;
      MidiLastNote: integer;

      TextEditMode: boolean;

      procedure NewBeat;
      procedure CzesciDivide;
      procedure CzesciMultiply;
      procedure LyricsCapitalize;
      procedure LyricsCorrectSpaces;
      procedure FixTimings;
      procedure DivideSentence;
      procedure JoinSentence;
      procedure DivideNote;
      procedure DeleteNote;
      procedure TransposeNote(Transpose: integer);
      procedure ChangeWholeTone(Tone: integer);
      procedure MoveAllToEnd(Move: integer);
      procedure MoveTextToRight;
      procedure MarkSrc;
      procedure PasteText;
      procedure CopySentence(Src, Dst: integer);
      procedure CopySentences(Src, Dst, Num: integer);
      //Note Name Mod
      function GetNoteName(Note: Integer): String;
    public
      Tex_Background:     TTexture;
      FadeOut:            boolean;
      constructor Create; override;
      procedure onShow; override;
      function ParseInput(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean; override;
      function ParseInputEditText(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean;
      function Draw: boolean; override;
      procedure onHide; override;
  end;

implementation
uses UGraphic, UDraw, UMain, USkins, ULanguage;

// Method for input parsing. If False is returned, GetNextWindow
// should be checked to know the next window to load;
function TScreenEditSub.ParseInput(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean;
var
  SDL_ModState:  Word;
  R:    real;
begin
  Result := true;

  if TextEditMode then begin
    Result := ParseInputEditText(PressedKey, ScanCode, PressedDown);
  end else begin

  SDL_ModState := SDL_GetModState and (KMOD_LSHIFT + KMOD_RSHIFT
    + KMOD_LCTRL + KMOD_RCTRL + KMOD_LALT  + KMOD_RALT {+ KMOD_CAPS});

  If (PressedDown) then begin // Key Down
    case PressedKey of

      SDLK_ESCAPE,
      SDLK_BACKSPACE :
        begin
          FadeTo(@ScreenSong);
        end;

      SDLK_Q:
        begin
          Result := false;
        end;

      SDLK_BACKQUOTE:
        begin
          // Increase Note Length (same as Alt + Right)
          Inc(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc);
          if AktNuta = Lines[0].Line[Lines[0].Akt].HighNote then
            Inc(Lines[0].Line[Lines[0].Akt].Koniec);
        end;

      SDLK_EQUALS:
        begin
          // Increase BPM
          if SDL_ModState = 0 then
            CurrentSong.BPM[0].BPM := Round((CurrentSong.BPM[0].BPM * 5) + 1) / 5; // (1/20)
          if SDL_ModState = KMOD_LSHIFT then
            CurrentSong.BPM[0].BPM := CurrentSong.BPM[0].BPM + 4; // (1/1)
          if SDL_ModState = KMOD_LCTRL then
            CurrentSong.BPM[0].BPM := Round((CurrentSong.BPM[0].BPM * 25) + 1) / 25; // (1/100)
        end;

      SDLK_MINUS:
        begin
          // Decrease BPM
          if SDL_ModState = 0 then
            CurrentSong.BPM[0].BPM := Round((CurrentSong.BPM[0].BPM * 5) - 1) / 5;
          if SDL_ModState = KMOD_LSHIFT then
            CurrentSong.BPM[0].BPM := CurrentSong.BPM[0].BPM - 4;
          if SDL_ModState = KMOD_LCTRL then
            CurrentSong.BPM[0].BPM := Round((CurrentSong.BPM[0].BPM * 25) - 1) / 25;
        end;

      SDLK_0:
        begin
          // Increase GAP
          if SDL_ModState = 0 then
            CurrentSong.GAP := CurrentSong.GAP + 10;
          if SDL_ModState = KMOD_LSHIFT then
            CurrentSong.GAP := CurrentSong.GAP + 1000;
        end;

      SDLK_9:
        begin
          // Decrease GAP
          if SDL_ModState = 0 then
            CurrentSong.GAP := CurrentSong.GAP - 10;
          if SDL_ModState = KMOD_LSHIFT then
            CurrentSong.GAP := CurrentSong.GAP - 1000;
        end;

      SDLK_KP_PLUS:
        begin
          // Increase tone of all notes
          if SDL_ModState = 0 then
            ChangeWholeTone(1);
          if SDL_ModState = KMOD_LSHIFT then
            ChangeWholeTone(12);
        end;

      SDLK_KP_MINUS:
        begin
          // Decrease tone of all notes
          if SDL_ModState = 0 then
            ChangeWholeTone(-1);
          if SDL_ModState = KMOD_LSHIFT then
            ChangeWholeTone(-12);
        end;

      SDLK_SLASH:
        begin
          if SDL_ModState = 0 then begin
            // Insert start of sentece
            if AktNuta > 0 then
              DivideSentence;
          end;

          if SDL_ModState = KMOD_LSHIFT then begin
            // Join next sentence with current
            if Lines[0].Akt < Lines[0].High  then
              JoinSentence;
          end;

          if SDL_ModState = KMOD_LCTRL then begin
            // divide note
            DivideNote;
          end;

        end;

      SDLK_S:
        begin
          // Save Song
          if SDL_ModState = KMOD_LSHIFT then
            SaveSong(CurrentSong, Lines[0], CurrentSong.Path + CurrentSong.FileName, true)
          else
            SaveSong(CurrentSong, Lines[0], CurrentSong.Path + CurrentSong.FileName, false);

          {if SDL_ModState = KMOD_LSHIFT or KMOD_LCTRL + KMOD_LALT then
            // Save Song
            SaveSongDebug(CurrentSong, Lines[0], 'C:\song.asm', false);}

        end;

      SDLK_D:
        begin
          // Divide lengths by 2
          CzesciDivide;
        end;

      SDLK_M:
        begin
          // Multiply lengths by 2
          CzesciMultiply;
        end;

      SDLK_C:
        begin
          // Capitalize letter at the beginning of line
          if SDL_ModState = 0 then
            LyricsCapitalize;

          // Correct spaces
          if SDL_ModState = KMOD_LSHIFT then
            LyricsCorrectSpaces;

          // Copy sentence
          if SDL_ModState = KMOD_LCTRL then
            MarkSrc;
        end;

      SDLK_V:
        begin
          // Paste text
          if SDL_ModState = KMOD_LCTRL then begin
            if Lines[0].Line[Lines[0].Akt].IlNut >= Lines[0].Line[CopySrc].IlNut then
              PasteText
            else
              beep;
          end;

          if SDL_ModState = KMOD_LCTRL + KMOD_LSHIFT then begin
            CopySentence(CopySrc, Lines[0].Akt);
          end;
        end;

      SDLK_4:
        begin
          if SDL_ModState = KMOD_LCTRL + KMOD_LSHIFT then begin
            CopySentence(CopySrc, Lines[0].Akt);
            CopySentence(CopySrc+1, Lines[0].Akt+1);
            CopySentence(CopySrc+2, Lines[0].Akt+2);
            CopySentence(CopySrc+3, Lines[0].Akt+3);
          end;

          if SDL_ModState = KMOD_LCTRL + KMOD_LSHIFT + KMOD_LALT then begin
            CopySentences(CopySrc, Lines[0].Akt, 4);
          end;
        end;
      SDLK_5:
        begin
          if SDL_ModState = KMOD_LCTRL + KMOD_LSHIFT then begin
            CopySentence(CopySrc, Lines[0].Akt);
            CopySentence(CopySrc+1, Lines[0].Akt+1);
            CopySentence(CopySrc+2, Lines[0].Akt+2);
            CopySentence(CopySrc+3, Lines[0].Akt+3);
            CopySentence(CopySrc+4, Lines[0].Akt+4);
          end;

          if SDL_ModState = KMOD_LCTRL + KMOD_LSHIFT + KMOD_LALT then begin
            CopySentences(CopySrc, Lines[0].Akt, 5);
          end;
        end;

      SDLK_T:
        begin
          // Fixes timings between sentences
          FixTimings;
        end;

      SDLK_F4:
        begin
          // Enter Text Edit Mode
          TextEditMode := true;
        end;

      SDLK_P:
        begin
          if SDL_ModState = 0 then begin
            // Play Sentence
            Click := true;
            AudioPlayback.Stop;
            R := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].StartNote);
            if R <= AudioPlayback.Length then
            begin
              AudioPlayback.Position := R;
              PlayStopTime := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].Koniec);
              PlaySentence := true;
              AudioPlayback.Play;
              LastClick := -100;
            end;
          end;

          if SDL_ModState = KMOD_LSHIFT then begin
            PlaySentenceMidi := true;

            MidiTime := USTime.GetTime;
            MidiStart := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].StartNote);
            MidiStop := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].Koniec);

            LastClick := -100;
          end;
          if SDL_ModState = KMOD_LSHIFT or KMOD_LCTRL then begin
            PlaySentenceMidi := true;
            MidiTime  := USTime.GetTime;
            MidiStart := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].StartNote);
            MidiStop  := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].Koniec);
            LastClick := -100;

            PlaySentence := true;
            Click := true;
            AudioPlayback.Stop;
            AudioPlayback.Position := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].StartNote)+0{-0.10};
            PlayStopTime := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].Koniec)+0;
            AudioPlayback.Play;
            LastClick := -100;
          end;
        end;

      SDLK_SPACE:
        begin
          // Play Sentence
          PlaySentenceMidi := false; // stop midi
          PlaySentence := true;
          Click := false;
          AudioPlayback.Stop;
          AudioPlayback.Position := GetTimeFromBeat(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start);
          PlayStopTime := (GetTimeFromBeat(
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start +
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc));
          AudioPlayback.Play;
          LastClick := -100;
        end;

      SDLK_RETURN:
        begin
        end;

      SDLK_LCTRL:
        begin
        end;

      SDLK_DELETE:
        begin
          if SDL_ModState = KMOD_LCTRL then begin
            // moves text to right in current sentence
            DeleteNote;
          end;
        end;

      SDLK_PERIOD:
        begin
          // moves text to right in current sentence
          MoveTextToRight;
        end;

      SDLK_RIGHT:
        begin
          // right
          if SDL_ModState = 0 then begin
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 0;
            Inc(AktNuta);
            if AktNuta = Lines[0].Line[Lines[0].Akt].IlNut then AktNuta := 0;
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;
            Lyric.Selected := AktNuta;
          end;

          // ctrl + right
          if SDL_ModState = KMOD_LCTRL then begin
            if Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc > 1 then begin
              Dec(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc);
              Inc(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start);
              if AktNuta = 0 then begin
                Inc(Lines[0].Line[Lines[0].Akt].Start);
                Inc(Lines[0].Line[Lines[0].Akt].StartNote);
              end;
            end;
          end;

          // shift + right
          if SDL_ModState = KMOD_LSHIFT then begin
            Inc(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start);
            if AktNuta = 0 then begin
              Inc(Lines[0].Line[Lines[0].Akt].Start);
              Inc(Lines[0].Line[Lines[0].Akt].StartNote);
            end;
            if AktNuta = Lines[0].Line[Lines[0].Akt].HighNote then
              Inc(Lines[0].Line[Lines[0].Akt].Koniec);
          end;

          // alt + right
          if SDL_ModState = KMOD_LALT then begin
            Inc(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc);
            if AktNuta = Lines[0].Line[Lines[0].Akt].HighNote then
              Inc(Lines[0].Line[Lines[0].Akt].Koniec);
          end;

          // alt + ctrl + shift + right = move all from cursor to right
          if SDL_ModState = KMOD_LALT + KMOD_LCTRL + KMOD_LSHIFT then begin
            MoveAllToEnd(1);
          end;

        end;

      SDLK_LEFT:
        begin
          // left
          if SDL_ModState = 0 then begin
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 0;
            Dec(AktNuta);
            if AktNuta = -1 then AktNuta := Lines[0].Line[Lines[0].Akt].HighNote;
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;
            Lyric.Selected := AktNuta;
          end;

          // ctrl + left
          if SDL_ModState = KMOD_LCTRL then begin
            Dec(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start);
            Inc(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc);
            if AktNuta = 0 then begin
              Dec(Lines[0].Line[Lines[0].Akt].Start);
              Dec(Lines[0].Line[Lines[0].Akt].StartNote);
            end;
          end;

          // shift + left
          if SDL_ModState = KMOD_LSHIFT then begin
            Dec(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start);

            // resizing sentences
            if AktNuta = 0 then begin
              Dec(Lines[0].Line[Lines[0].Akt].Start);
              Dec(Lines[0].Line[Lines[0].Akt].StartNote);
            end;

            if AktNuta = Lines[0].Line[Lines[0].Akt].HighNote then
              Dec(Lines[0].Line[Lines[0].Akt].Koniec);

          end;

          // alt + left
          if SDL_ModState = KMOD_LALT then begin
            if Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc > 1 then begin
              Dec(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc);
              if AktNuta = Lines[0].Line[Lines[0].Akt].HighNote then
                Dec(Lines[0].Line[Lines[0].Akt].Koniec);
            end;
          end;

          // alt + ctrl + shift + right = move all from cursor to left
          if SDL_ModState = KMOD_LALT + KMOD_LCTRL + KMOD_LSHIFT then begin
            MoveAllToEnd(-1);
          end;

        end;

      SDLK_DOWN:
        begin
          {$IFDEF UseMIDIPort}
          // skip to next sentence
          if SDL_ModState = 0 then begin
            MidiOut.PutShort($81, Lines[0].Line[Lines[0].Akt].Note[MidiLastNote].Ton + 60, 127);
            PlaySentenceMidi := false;

            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 0;
            Inc(Lines[0].Akt);
            AktNuta := 0;
            if Lines[0].Akt > Lines[0].High then Lines[0].Akt := 0;
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;

            Lyric.AddCzesc(Lines[0].Akt);
            Lyric.Selected := 0;
            AudioPlayback.Stop;
            PlaySentence := false;
          end;

          // decrease tone
          if SDL_ModState = KMOD_LCTRL then begin
            TransposeNote(-1);
          end;
          {$endif}

        end;

      SDLK_UP:
        begin
          {$IFDEF UseMIDIPort}
          // skip to previous sentence
          if SDL_ModState = 0 then begin
            MidiOut.PutShort($81, Lines[0].Line[Lines[0].Akt].Note[MidiLastNote].Ton + 60, 127);
            PlaySentenceMidi := false;

            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 0;
            Dec(Lines[0].Akt);
            AktNuta := 0;
            if Lines[0].Akt = -1 then Lines[0].Akt := Lines[0].High;
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;

            Lyric.AddCzesc(Lines[0].Akt);
            Lyric.Selected := 0;
            AudioPlayback.Stop;
            PlaySentence := false;
          end;

          // increase tone
          if SDL_ModState = KMOD_LCTRL then begin
            TransposeNote(1);
          end;
          {$endif}
        end;

      // Golden Note Patch
      SDLK_G:
        begin
          case Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc of
            0: Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc := 2;
            1: Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc := 2;
            2: Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc := 1;
          end; // case
          Lines[0].Line[Lines[0].Akt].Note[AktNuta].Freestyle := False;
        end;

      // Freestyle Note Patch
      SDLK_F:
        begin
           case Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc of
            0:
            begin;
              Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc := 1;
              Lines[0].Line[Lines[0].Akt].Note[AktNuta].Freestyle := False;
            end;
            1,2:
            begin;
              Lines[0].Line[Lines[0].Akt].Note[AktNuta].Wartosc := 0;
              Lines[0].Line[Lines[0].Akt].Note[AktNuta].Freestyle := True;
            end;
          end; // case

        end;


      end;
    end;
  end; // if
end;

function TScreenEditSub.ParseInputEditText(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean;
var
  SDL_ModState:  Word;
begin
  // used when in Text Edit Mode
  Result := true;

  SDL_ModState := SDL_GetModState and (KMOD_LSHIFT + KMOD_RSHIFT
    + KMOD_LCTRL + KMOD_RCTRL + KMOD_LALT  + KMOD_RALT {+ KMOD_CAPS});

  If (PressedDown) Then
  begin // Key Down
    case PressedKey of

      SDLK_ESCAPE:
        begin
          FadeTo(@ScreenSong);
        end;
      SDLK_F4, SDLK_RETURN:
        begin
          // Exit Text Edit Mode
          TextEditMode := false;
        end;
      SDLK_0..SDLK_9, SDLK_A..SDLK_Z, SDLK_SPACE, SDLK_MINUS, SDLK_EXCLAIM, SDLK_COMMA, SDLK_SLASH, SDLK_ASTERISK, SDLK_QUESTION, SDLK_QUOTE, SDLK_QUOTEDBL:
        begin
          Lines[0].Line[Lines[0].Akt].Note[AktNuta].Tekst :=
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Tekst + chr(ScanCode);
        end;
      SDLK_BACKSPACE:
        begin
          Delete(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Tekst,
            Length(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Tekst), 1);
        end;
      SDLK_RIGHT:
        begin
          // right
          if SDL_ModState = 0 then begin
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 0;
            Inc(AktNuta);
            if AktNuta = Lines[0].Line[Lines[0].Akt].IlNut then AktNuta := 0;
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;
            Lyric.Selected := AktNuta;
          end;
        end;
      SDLK_LEFT:
        begin
          // left
          if SDL_ModState = 0 then begin
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 0;
            Dec(AktNuta);
            if AktNuta = -1 then AktNuta := Lines[0].Line[Lines[0].Akt].HighNote;
            Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;
            Lyric.Selected := AktNuta;
          end;
      end;
    end;
  end;
end;

procedure TScreenEditSub.NewBeat;
begin
    // click
{    for Pet := 0 to Lines[0].Line[Lines[0].Akt].HighNut do
  if (Lines[0].Line[Lines[0].Akt].Note[Pet].Start = Czas.AktBeat) then begin
      // old}
//    Music.PlayClick;
end;

procedure TScreenEditSub.CzesciDivide;
var
  C:    integer;
  N:    integer;
begin                    
  CurrentSong.BPM[0].BPM := CurrentSong.BPM[0].BPM / 2;
  for C := 0 to Lines[0].High do begin
    Lines[0].Line[C].Start :=     Lines[0].Line[C].Start div 2;
    Lines[0].Line[C].StartNote := Lines[0].Line[C].StartNote div 2;
    Lines[0].Line[C].Koniec :=    Lines[0].Line[C].Koniec div 2;
    for N := 0 to Lines[0].Line[C].HighNote do begin
      Lines[0].Line[C].Note[N].Start :=   Lines[0].Line[C].Note[N].Start div 2;
      Lines[0].Line[C].Note[N].Dlugosc := Round(Lines[0].Line[C].Note[N].Dlugosc / 2);
    end; // N
  end; // C
end;

procedure TScreenEditSub.CzesciMultiply;
var
  C:    integer;
  N:    integer;
begin
  CurrentSong.BPM[0].BPM := CurrentSong.BPM[0].BPM * 2;
  for C := 0 to Lines[0].High do begin
    Lines[0].Line[C].Start :=     Lines[0].Line[C].Start * 2;
    Lines[0].Line[C].StartNote := Lines[0].Line[C].StartNote * 2;
    Lines[0].Line[C].Koniec :=    Lines[0].Line[C].Koniec * 2;
    for N := 0 to Lines[0].Line[C].HighNote do begin
      Lines[0].Line[C].Note[N].Start :=   Lines[0].Line[C].Note[N].Start * 2;
      Lines[0].Line[C].Note[N].Dlugosc := Lines[0].Line[C].Note[N].Dlugosc * 2;
    end; // N
  end; // C
end;

procedure TScreenEditSub.LyricsCapitalize;
var
  C:    integer;
  N:    integer; // temporary
  S:    string;
begin
  // temporary
{  for C := 0 to Lines[0].High do
    for N := 0 to Lines[0].Line[C].HighNut do
      Lines[0].Line[C].Note[N].Tekst := AnsiLowerCase(Lines[0].Line[C].Note[N].Tekst);}

  for C := 0 to Lines[0].High do begin
    S := AnsiUpperCase(Copy(Lines[0].Line[C].Note[0].Tekst, 1, 1));
    S := S + Copy(Lines[0].Line[C].Note[0].Tekst, 2, Length(Lines[0].Line[C].Note[0].Tekst)-1);
    Lines[0].Line[C].Note[0].Tekst := S;
  end; // C
end;

procedure TScreenEditSub.LyricsCorrectSpaces;
var
  C:    integer;
  N:    integer;
begin
  for C := 0 to Lines[0].High do begin
    // correct starting spaces in the first word
    while Copy(Lines[0].Line[C].Note[0].Tekst, 1, 1) = ' ' do
      Lines[0].Line[C].Note[0].Tekst := Copy(Lines[0].Line[C].Note[0].Tekst, 2, 100);

    // move spaces on the start to the end of the previous note
    for N := 1 to Lines[0].Line[C].HighNote do begin
      while (Copy(Lines[0].Line[C].Note[N].Tekst, 1, 1) = ' ') do begin
        Lines[0].Line[C].Note[N].Tekst := Copy(Lines[0].Line[C].Note[N].Tekst, 2, 100);
        Lines[0].Line[C].Note[N-1].Tekst := Lines[0].Line[C].Note[N-1].Tekst + ' ';
      end;
    end; // N

    // correct '-'  to '- '
    for N := 0 to Lines[0].Line[C].HighNote do begin
      if Lines[0].Line[C].Note[N].Tekst = '-' then
        Lines[0].Line[C].Note[N].Tekst := '- ';
    end; // N

    // add space to the previous note when the current word is '- '
    for N := 1 to Lines[0].Line[C].HighNote do begin
      if Lines[0].Line[C].Note[N].Tekst  = '- ' then
        Lines[0].Line[C].Note[N-1].Tekst := Lines[0].Line[C].Note[N-1].Tekst + ' ';
    end; // N

    // correct too many spaces at the end of note
    for N := 0 to Lines[0].Line[C].HighNote do begin
      while Copy(Lines[0].Line[C].Note[N].Tekst, Length(Lines[0].Line[C].Note[N].Tekst)-1, 2) = '  ' do
        Lines[0].Line[C].Note[N].Tekst := Copy(Lines[0].Line[C].Note[N].Tekst, 1, Length(Lines[0].Line[C].Note[N].Tekst)-1);
    end; // N

    // and correct if there is no space at the end of sentence
    N := Lines[0].Line[C].HighNote;
    if Copy(Lines[0].Line[C].Note[N].Tekst, Length(Lines[0].Line[C].Note[N].Tekst), 1) <> ' ' then
      Lines[0].Line[C].Note[N].Tekst := Lines[0].Line[C].Note[N].Tekst + ' ';

  end; // C
end;

procedure TScreenEditSub.FixTimings;
var
  C:    integer;
  S:    integer;
  Min:  integer;
  Max:  integer;
begin
  for C := 1 to Lines[0].High do begin
    with Lines[0].Line[C-1] do begin
      Min := Note[HighNote].Start + Note[HighNote].Dlugosc;
      Max := Lines[0].Line[C].StartNote;
      case (Max - Min) of
        0:    S := Max;
        1:    S := Max;
        2:    S := Max - 1;
        3:    S := Max - 2;
        else
          if ((Max - Min) > 4) then
            S := Min + 2
          else
            S := Max;
      end; // case

      Lines[0].Line[C].Start := S;
    end; // with
  end; // for
end;

procedure TScreenEditSub.DivideSentence;
var
  C:      integer;
  CStart: integer;
  CNew:   integer;
  CLen:   integer;
  N:      integer;
  NStart: integer;
  NHigh:  integer;
  NNewL:  integer;
begin
  // increase sentence length by 1
  CLen := Length(Lines[0].Line);
  SetLength(Lines[0].Line, CLen + 1);
  Inc(Lines[0].Ilosc);
  Inc(Lines[0].High);

  // move needed sentences to one forward. newly has the copy of divided sentence
  CStart := Lines[0].Akt;
  for C := CLen-1 downto CStart do
    Lines[0].Line[C+1] := Lines[0].Line[C];

  // clear and set new sentence
  CNew := CStart + 1;
  NStart := AktNuta;
  Lines[0].Line[CNew].Start := Lines[0].Line[CStart].Note[NStart].Start;
  Lines[0].Line[CNew].StartNote := Lines[0].Line[CStart].Note[NStart].Start;
  Lines[0].Line[CNew].Lyric := '';
  Lines[0].Line[CNew].LyricWidth := 0;
  Lines[0].Line[CNew].Koniec := 0;
  Lines[0].Line[CNew].BaseNote := 0; // 0.5.0: we modify it later in this procedure
  Lines[0].Line[CNew].IlNut := 0;
  Lines[0].Line[CNew].HighNote := -1;
  SetLength(Lines[0].Line[CNew].Note, 0);

  // move right notes to new sentences
  NHigh := Lines[0].Line[CStart].HighNote;
  for N := NStart to NHigh do begin
    NNewL := Lines[0].Line[CNew].IlNut;
    SetLength(Lines[0].Line[CNew].Note, NNewL + 1);
    Lines[0].Line[CNew].Note[NNewL] := Lines[0].Line[CStart].Note[N];

    // increase sentence counters
    Inc(Lines[0].Line[CNew].IlNut);
    Inc(Lines[0].Line[CNew].HighNote);
    Lines[0].Line[CNew].Koniec := Lines[0].Line[CNew].Note[NNewL].Start +
      Lines[0].Line[CNew].Note[NNewL].Dlugosc;
  end;

  // clear old notes and set sentence counters
  Lines[0].Line[CStart].HighNote := NStart - 1;
  Lines[0].Line[CStart].IlNut := Lines[0].Line[CStart].HighNote + 1;
  Lines[0].Line[CStart].Koniec := Lines[0].Line[CStart].Note[NStart-1].Start +
    Lines[0].Line[CStart].Note[NStart-1].Dlugosc;
  SetLength(Lines[0].Line[CStart].Note, Lines[0].Line[CStart].IlNut);

  // 0.5.0: modify BaseNote
  Lines[0].Line[CNew].BaseNote := 120;
  for N := 0 to Lines[0].Line[CNew].IlNut do
    if Lines[0].Line[CNew].Note[N].Ton < Lines[0].Line[CNew].BaseNote then
      Lines[0].Line[CNew].BaseNote := Lines[0].Line[CNew].Note[N].Ton;

  Lines[0].Akt := Lines[0].Akt + 1;
  AktNuta := 0;
  Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;
  Lyric.AddCzesc(Lines[0].Akt);

end;

procedure TScreenEditSub.JoinSentence;
var
  C:      integer;
  N:      integer;
  NStart: integer;
  NDst:   integer;
begin
  C := Lines[0].Akt;

  // set new sentence
  NStart := Lines[0].Line[C].IlNut;
  Lines[0].Line[C].IlNut := Lines[0].Line[C].IlNut + Lines[0].Line[C+1].IlNut;
  Lines[0].Line[C].HighNote := Lines[0].Line[C].HighNote + Lines[0].Line[C+1].IlNut;
  SetLength(Lines[0].Line[C].Note, Lines[0].Line[C].IlNut);

  // move right notes to new sentences
  for N := 0 to Lines[0].Line[C+1].HighNote do begin
    NDst := NStart + N;
    Lines[0].Line[C].Note[NDst] := Lines[0].Line[C+1].Note[N];
  end;

  // increase sentence counters
  NDst := Lines[0].Line[C].HighNote;
  Lines[0].Line[C].Koniec := Lines[0].Line[C].Note[NDst].Start +
    Lines[0].Line[C].Note[NDst].Dlugosc;

  // move needed sentences to one backward.
  for C := Lines[0].Akt + 1 to Lines[0].High - 1 do
    Lines[0].Line[C] := Lines[0].Line[C+1];

  // increase sentence length by 1
  SetLength(Lines[0].Line, Length(Lines[0].Line) - 1);
  Dec(Lines[0].Ilosc);
  Dec(Lines[0].High);
end;

procedure TScreenEditSub.DivideNote;
var
  C:    integer;
  N:    integer;
  NLen: integer;
begin
  C := Lines[0].Akt;

  NLen := Lines[0].Line[C].IlNut + 1;
  SetLength(Lines[0].Line[C].Note, NLen);
  Inc(Lines[0].Line[C].HighNote);
  Inc(Lines[0].Line[C].IlNut);

  // we copy all notes including selected one
  for N := Lines[0].Line[C].HighNote downto AktNuta+1 do begin
    Lines[0].Line[C].Note[N] := Lines[0].Line[C].Note[N-1];
  end;

  // me slightly modify new note
  Lines[0].Line[C].Note[AktNuta].Dlugosc := 1;
  Inc(Lines[0].Line[C].Note[AktNuta+1].Start);
  Dec(Lines[0].Line[C].Note[AktNuta+1].Dlugosc);
  Lines[0].Line[C].Note[AktNuta+1].Tekst := '- ';
  Lines[0].Line[C].Note[AktNuta+1].Color := 0;
end;

procedure TScreenEditSub.DeleteNote;
var
  C:    integer;
  N:    integer;
  NLen: integer;
begin
  C := Lines[0].Akt;

  //Do Not delete Last Note
  if (Lines[0].High > 0) OR (Lines[0].Line[C].HighNote > 0) then
  begin

    // we copy all notes from the next to the selected one
    for N := AktNuta+1 to Lines[0].Line[C].HighNote do begin
      Lines[0].Line[C].Note[N-1] := Lines[0].Line[C].Note[N];
    end;

    NLen := Lines[0].Line[C].IlNut - 1;

    if (NLen > 0) then
    begin
      SetLength(Lines[0].Line[C].Note, NLen);
      Dec(Lines[0].Line[C].HighNote);
      Dec(Lines[0].Line[C].IlNut);


      // me slightly modify new note
      if AktNuta > Lines[0].Line[C].HighNote then Dec(AktNuta);
        Lines[0].Line[C].Note[AktNuta].Color := 1;
    end
    //Last Note of current Sentence Deleted - > Delete Sentence
    else
    begin
      //Move all Sentences after the current to the Left
      for N := C+1 to Lines[0].High do
        Lines[0].Line[N-1] := Lines[0].Line[N];

      //Delete Last Sentence
      SetLength(Lines[0].Line, Lines[0].High);
      Lines[0].High := High(Lines[0].Line);
      Lines[0].Ilosc := Length(Lines[0].Line);

      AktNuta := 0;
      if (C > 0) then
        Lines[0].Akt := C - 1
      else
        Lines[0].Akt := 0;

      Lines[0].Line[Lines[0].Akt].Note[AktNuta].Color := 1;
    end;
  end;
end;

procedure TScreenEditSub.TransposeNote(Transpose: integer);
begin
  Inc(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Ton, Transpose);
end;

procedure TScreenEditSub.ChangeWholeTone(Tone: integer);
var
  C:  integer;
  N:  integer;
begin
  for C := 0 to Lines[0].High do begin
    Lines[0].Line[C].BaseNote := Lines[0].Line[C].BaseNote + Tone;
    for N := 0 to Lines[0].Line[C].HighNote do
      Lines[0].Line[C].Note[N].Ton := Lines[0].Line[C].Note[N].Ton + Tone;
  end;
end;

procedure TScreenEditSub.MoveAllToEnd(Move: integer);
var
  C:    integer;
  N:    integer;
  NStart: integer;
begin
  for C := Lines[0].Akt to Lines[0].High do begin
    NStart := 0;
    if C = Lines[0].Akt then NStart := AktNuta;
    for N := NStart to Lines[0].Line[C].HighNote do begin
      Inc(Lines[0].Line[C].Note[N].Start, Move); // move note start

      if N = 0 then begin // fix beginning
        Inc(Lines[0].Line[C].Start, Move);
        Inc(Lines[0].Line[C].StartNote, Move);
      end;

      if N = Lines[0].Line[C].HighNote then // fix ending
        Inc(Lines[0].Line[C].Koniec, Move);

    end; // for
  end; // for
end;

procedure TScreenEditSub.MoveTextToRight;
var
  C:      integer;
  N:      integer;
  NHigh:  integer;
begin
{  C := Lines[0].Akt;

  for N := Lines[0].Line[C].HighNut downto 1 do begin
    Lines[0].Line[C].Note[N].Tekst := Lines[0].Line[C].Note[N-1].Tekst;
  end; // for

  Lines[0].Line[C].Note[0].Tekst := '- ';}

  C := Lines[0].Akt;
  NHigh := Lines[0].Line[C].HighNote;

  // last word
  Lines[0].Line[C].Note[NHigh].Tekst := Lines[0].Line[C].Note[NHigh-1].Tekst + Lines[0].Line[C].Note[NHigh].Tekst;

  // other words
  for N := NHigh - 1 downto AktNuta + 1 do begin
    Lines[0].Line[C].Note[N].Tekst := Lines[0].Line[C].Note[N-1].Tekst;
  end; // for
  Lines[0].Line[C].Note[AktNuta].Tekst := '- ';
end;

procedure TScreenEditSub.MarkSrc;
begin
  CopySrc := Lines[0].Akt;
end;

procedure TScreenEditSub.PasteText;
var
  C:    integer;
  N:    integer;
begin
  C := Lines[0].Akt;

  for N := 0 to Lines[0].Line[CopySrc].HighNote do
    Lines[0].Line[C].Note[N].Tekst := Lines[0].Line[CopySrc].Note[N].Tekst;
end;

procedure TScreenEditSub.CopySentence(Src, Dst: integer);
var
  N:      integer;
  Time1:  integer;
  Time2:  integer;
  TD:  integer;
begin
  Time1 := Lines[0].Line[Src].Note[0].Start;
  Time2 := Lines[0].Line[Dst].Note[0].Start;
  TD := Time2-Time1;

  SetLength(Lines[0].Line[Dst].Note, Lines[0].Line[Src].IlNut);
  Lines[0].Line[Dst].IlNut := Lines[0].Line[Src].IlNut;
  Lines[0].Line[Dst].HighNote := Lines[0].Line[Src].HighNote;
  for N := 0 to Lines[0].Line[Src].HighNote do begin
    Lines[0].Line[Dst].Note[N].Tekst := Lines[0].Line[Src].Note[N].Tekst;
    Lines[0].Line[Dst].Note[N].Dlugosc := Lines[0].Line[Src].Note[N].Dlugosc;
    Lines[0].Line[Dst].Note[N].Ton := Lines[0].Line[Src].Note[N].Ton;
    Lines[0].Line[Dst].Note[N].Start := Lines[0].Line[Src].Note[N].Start + TD;
  end;
  N := Lines[0].Line[Src].HighNote;
  Lines[0].Line[Dst].Koniec := Lines[0].Line[Dst].Note[N].Start + Lines[0].Line[Dst].Note[N].Dlugosc;
end;

procedure TScreenEditSub.CopySentences(Src, Dst, Num: integer);
var
  C:      integer;
begin
//  Lyric := TLyric.Create;


  // create place for new sentences
  SetLength(Lines[0].Line, Lines[0].Ilosc + Num - 1);

  // moves sentences next to the destination
  for C := Lines[0].High downto Dst + 1 do begin
    Lines[0].Line[C + Num - 1] := Lines[0].Line[C];
  end;

  // prepares new sentences: sets sentence start and create first note
  for C := 1 to Num-1 do begin
    Lines[0].Line[Dst + C].Start := Lines[0].Line[Dst + C - 1].StartNote +
      (Lines[0].Line[Src + C].StartNote - Lines[0].Line[Src + C - 1].StartNote);
    SetLength(Lines[0].Line[Dst + C].Note, 1);
    Lines[0].Line[Dst + C].IlNut := 1;
    Lines[0].Line[Dst + C].HighNote := 0;
    Lines[0].Line[Dst + C].Note[0].Start := Lines[0].Line[Dst + C].Start;
    Lines[0].Line[Dst + C].Note[0].Dlugosc := 1;
    Lines[0].Line[Dst + C].StartNote := Lines[0].Line[Dst + C].Start;
    Lines[0].Line[Dst + C].Koniec := Lines[0].Line[Dst + C].Start + 1;
  end;

  // increase counters
  Lines[0].Ilosc := Lines[0].Ilosc + Num - 1;
  Lines[0].High := Lines[0].High + Num - 1;

  for C := 0 to Num-1 do
    CopySentence(Src + C, Dst + C);
end;


constructor TScreenEditSub.Create;
begin
  inherited Create;
  SetLength(Player, 1);

  // linijka
  AddStatic(20, 10, 80, 30, 0, 0, 0, Skin.GetTextureFileName('ButtonF'), 'JPG', 'Font Black');
  AddText(40, 17, 1, 6, 1, 1, 1, 'Line');
  TextSentence := AddText(120, 14, 1, 8, 0, 0, 0, '0 / 0');

  // Note
  AddStatic(220, 10, 80, 30, 0, 0, 0, Skin.GetTextureFileName('ButtonF'), 'JPG', 'Font Black');
  AddText(242, 17, 1, 6, 1, 1, 1, 'Note');
  TextNote := AddText(320, 14, 1, 8, 0, 0, 0, '0 / 0');

  // file info
  AddStatic(150, 50, 500, 150, 0, 0, 0, Skin.GetTextureFileName('Bar'), 'JPG', 'Font Black');
  AddStatic(151, 52, 498, 146,  1, 1, 1, Skin.GetTextureFileName('Bar'), 'JPG', 'Font Black');
  AddText(180, 65,  0, 8, 0, 0, 0, 'Title:');
  AddText(180, 90,  0, 8, 0, 0, 0, 'Artist:');
  AddText(180, 115, 0, 8, 0, 0, 0, 'Mp3:');
  AddText(180, 140, 0, 8, 0, 0, 0, 'BPM:');
  AddText(180, 165, 0, 8, 0, 0, 0, 'GAP:');

  TextTitle :=  AddText(250, 65,  0, 8, 0, 0, 0, 'a');
  TextArtist := AddText(250, 90,  0, 8, 0, 0, 0, 'b');
  TextMp3 :=    AddText(250, 115, 0, 8, 0, 0, 0, 'c');
  TextBPM :=    AddText(250, 140, 0, 8, 0, 0, 0, 'd');
  TextGAP :=    AddText(250, 165, 0, 8, 0, 0, 0, 'e');

{  AddInteraction(2, TextTitle);
  AddInteraction(2, TextArtist);
  AddInteraction(2, TextMp3);
  AddInteraction(2, TextBPM);
  AddInteraction(2, TextGAP);}

  // note info
  AddText(20, 190,  0, 8, 0, 0, 0, 'Start:');
  AddText(20, 215,  0, 8, 0, 0, 0, 'Duration:');
  AddText(20, 240,  0, 8, 0, 0, 0, 'Tone:');
  AddText(20, 265,  0, 8, 0, 0, 0, 'Text:');

  TextNStart :=   AddText(120, 190,  0, 8, 0, 0, 0, 'a');
  TextNDlugosc := AddText(120, 215,  0, 8, 0, 0, 0, 'b');
  TextNTon :=     AddText(120, 240,  0, 8, 0, 0, 0, 'c');
  TextNText :=    AddText(120, 265,  0, 8, 0, 0, 0, 'd');

  // debug
  TextDebug :=  AddText(30, 550, 0, 8, 0, 0, 0, '');

end;

procedure TScreenEditSub.onShow;
begin
  inherited;

  Log.LogStatus('Initializing', 'TEditScreen.onShow');
  Lyric := TLyric.Create;

  ResetSingTemp;

  try
    Error := not CurrentSong.LoadSong();
  except
    Error := True;
  end;

  if Error then
  begin
    //Error Loading Song -> Go back to Song Screen and Show some Error Message
    FadeTo(@ScreenSong);
    ScreenPopupError.ShowPopup (Language.Translate('ERROR_CORRUPT_SONG'));
    Exit;
  end
  else begin
  {$IFDEF UseMIDIPort}
    MidiOut := TMidiOutput.Create(nil);
    if Ini.Debug = 1 then
      MidiOut.ProductName := 'Microsoft GS Wavetable SW Synth'; // for my kxproject without midi table
    MidiOut.Open;
  {$ENDIF}
    Text[TextTitle].Text :=   CurrentSong.Title;
    Text[TextArtist].Text :=  CurrentSong.Artist;
    Text[TextMp3].Text :=     CurrentSong.Mp3;

    Lines[0].Akt := 0;
    AktNuta := 0;
    Lines[0].Line[0].Note[0].Color := 1;

    AudioPlayback.Open(CurrentSong.Path + CurrentSong.Mp3);
    //Set Down Music Volume for Better hearability of Midi Sounds
    //Music.SetVolume(40);

    Lyric.Clear;
    Lyric.X := 400;
    Lyric.Y := 500;
    Lyric.Align := 1;
    Lyric.Size := 14;
    Lyric.ColR := 0;
    Lyric.ColG := 0;
    Lyric.ColB := 0;
    Lyric.ColSR := Skin_FontHighlightR;
    Lyric.ColSG := Skin_FontHighlightG;
    Lyric.ColSB := Skin_FontHighlightB;
    Lyric.Style := 0;
    Lyric.AddCzesc(0);
    Lyric.Selected := 0;

    NotesH := 7;
    NotesW := 4;

  end;

//  Interaction := 0;
  TextEditMode := false;
end;

function TScreenEditSub.Draw: boolean;
var
  Min:    integer;
  Sec:    integer;
  Tekst:  string;
  Pet:    integer;
  AktBeat:  integer;
begin
  glClearColor(1,1,1,1);

  // midi music
  if PlaySentenceMidi then begin
    MidiPos := USTime.GetTime - MidiTime + MidiStart;

    {$IFDEF UseMIDIPort}
    // stop the music
    if (MidiPos > MidiStop) then begin
      MidiOut.PutShort($81, Lines[0].Line[Lines[0].Akt].Note[MidiLastNote].Ton + 60, 127);
      PlaySentenceMidi := false;
    end;
    {$ENDIF}

    // click
    AktBeat := Floor(GetMidBeat(MidiPos - CurrentSong.GAP / 1000));
    Text[TextDebug].Text := IntToStr(AktBeat);

    if AktBeat <> LastClick then begin
      for Pet := 0 to Lines[0].Line[Lines[0].Akt].HighNote do
        if (Lines[0].Line[Lines[0].Akt].Note[Pet].Start = AktBeat) then
        begin

          {$IFDEF UseMIDIPort}
          LastClick := AktBeat;
          if Pet > 0 then
            MidiOut.PutShort($81, Lines[0].Line[Lines[0].Akt].Note[Pet-1].Ton + 60, 127);
          MidiOut.PutShort($91, Lines[0].Line[Lines[0].Akt].Note[Pet].Ton + 60, 127);
          MidiLastNote := Pet;
          {$ENDIF}

        end;
    end;
  end; // if PlaySentenceMidi

  // mp3 music
  if PlaySentence then begin
    // stop the music
    if (AudioPlayback.Position > PlayStopTime) then
    begin
      AudioPlayback.Stop;
      PlaySentence := false;
    end;

    // click
    if (Click) and (PlaySentence) then begin
//      AktBeat := Floor(CurrentSong.BPM[0].BPM * (Music.Position - CurrentSong.GAP / 1000) / 60);
      AktBeat := Floor(GetMidBeat(AudioPlayback.Position - CurrentSong.GAP / 1000));
      Text[TextDebug].Text := IntToStr(AktBeat);
      if AktBeat <> LastClick then begin
        for Pet := 0 to Lines[0].Line[Lines[0].Akt].HighNote do
          if (Lines[0].Line[Lines[0].Akt].Note[Pet].Start = AktBeat) then
          begin
            AudioPlayback.PlaySound( SoundLib.Click );
            LastClick := AktBeat;
          end;
      end;
    end; // click
  end; // if PlaySentence
  

  Text[TextSentence].Text := IntToStr(Lines[0].Akt + 1) + ' / ' + IntToStr(Lines[0].Ilosc);
  Text[TextNote].Text := IntToStr(AktNuta + 1) + ' / ' + IntToStr(Lines[0].Line[Lines[0].Akt].IlNut);

  // Song info
  Text[TextBPM].Text := FloatToStr(CurrentSong.BPM[0].BPM / 4);
  Text[TextGAP].Text := FloatToStr(CurrentSong.GAP);

  //Error reading Variables when no Song is loaded
  if not Error then
  begin
    // Note info
    Text[TextNStart].Text :=    IntToStr(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Start);
    Text[TextNDlugosc].Text :=  IntToStr(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Dlugosc);
    Text[TextNTon].Text :=      IntToStr(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Ton) + ' ( ' + GetNoteName(Lines[0].Line[Lines[0].Akt].Note[AktNuta].Ton) + ' )';
    Text[TextNText].Text :=              Lines[0].Line[Lines[0].Akt].Note[AktNuta].Tekst;
  end;

  // Text Edit Mode
  if TextEditMode then
    Text[TextNText].Text := Text[TextNText].Text + '|'; 

  // draw static menu
  inherited Draw;

  // draw notes
  SingDrawNoteLines(20, 300, 780, 15);
  //Error Drawing when no Song is loaded
  if not Error then
  begin
    SingDrawBeatDelimeters(40, 300, 760, 0);
    EditDrawCzesc(40, 405, 760, 0, 15);
  end;

  // draw text
  Lyric.Draw;

end;

procedure TScreenEditSub.onHide;
begin
  {$IFDEF UseMIDIPort}
  MidiOut.Close;
  MidiOut.Free;
  {$ENDIF}
  //Music.SetVolume(100);
end;

function TScreenEditSub.GetNoteName(Note: Integer): String;
var N1, N2: Integer;
begin
  if (Note > 0) then
  begin
    N1 := Note mod 12;
    N2 := Note div 12;
  end
  else
  begin
    N1 := (Note + (-Trunc(Note/12)+1)*12) mod 12;
    N2 := -1;
  end;



  case N1 of
    0: Result := 'c';
    1: Result := 'c#';
    2: Result := 'd';
    3: Result := 'd#';
    4: Result := 'e';
    5: Result := 'f';
    6: Result := 'f#';
    7: Result := 'g';
    8: Result := 'g#';
    9: Result := 'a';
    10: Result := 'b';
    11: Result := 'h';
  end;

  case N2 of
    0: Result := UpperCase(Result); //Normal Uppercase Note, 1: Normal lowercase Note
    2: Result := Result + '''';     //One Striped
    3: Result := Result + '''''';   //Two Striped
    4: Result := Result + ''''''''; //etc.
    5: Result := Result + '''''''''';
    6: Result := Result + '''''''''''';
    7: Result := Result + '''''''''''''';
  end;
end;

end.
