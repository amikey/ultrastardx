unit UMain;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses
  SDL,
  UGraphic,
  UMusic,
  URecord,
  UTime,
  SysUtils,
  UDisplay,
  UIni,
  ULog,
  ULyrics,
  UScreenSing,
  USong,
  gl,
  UThemes;

type
  PPLayerNote = ^TPlayerNote;
  TPlayerNote = record
    Start:     integer;
    Length:    integer;
    Detect:    real;    // accurate place, detected in the note
    Tone:      real;
    Perfect:   boolean; // true if the note matches the original one, lit the star
    Hit:       boolean; // true if the note Hits the Line
  end;

  PPLayer = ^TPlayer;
  TPlayer = record
    Name:         string;

    // Index in Teaminfo record
    TeamID:       Byte;
    PlayerID:     Byte;

    // Scores
    Score:        real;
    ScoreLine:    real;
    ScoreGolden:  real;

    ScoreInt:       integer;
    ScoreLineInt:   integer;
    ScoreGoldenInt: integer;
    ScoreTotalInt:  integer;

    // LineBonus Mod
    ScoreLast:    Real;//Last Line Score

    // PerfectLineTwinkle Mod (effect)
    LastSentencePerfect: Boolean;

    //Meter:        real;

    HighNote:   integer; // index of last note (= High(Note)?)
    LengthNote: integer; // number of notes (= Length(Note)?).
    Note:       array of TPlayerNote;
  end;


var
  // Absolute Paths
  GamePath:         string;
  SoundPath:        string;
  SongPath:         string;
  LogPath:          string;
  ThemePath:        string;
  SkinsPath:        string;
  ScreenshotsPath:  string;
  CoversPath:       string;
  LanguagesPath:    string;
  PluginPath:       string;
  VisualsPath:      string;
  ResourcesPath:    string;
  PlayListPath:     string;

  UserSongPath:     string = '';
  UserCoversPath:   string = '';
  UserPlaylistPath: string = '';

  Done:     Boolean;
  Event:    TSDL_event;
  // FIXME: ConversionFileName should not be global
  ConversionFileName: string;
  Restart:  boolean;

  // player and music info
  Player:       array of TPlayer;
  PlayersPlay:  integer;

  CurrentSong : TSong;

const
  MAX_SONG_SCORE = 10000;     // max. achievable points per song
  MAX_SONG_LINE_BONUS = 1000; // max. achievable line bonus per song

procedure InitializePaths;

Procedure Main;
procedure MainLoop;
procedure CheckEvents;
procedure Sing(Screen: TScreenSing);
procedure NewSentence(Screen: TScreenSing);
procedure NewBeat(Screen: TScreenSing); // executed when on then new beat
procedure NewBeatClick(Screen: TScreenSing); // executed when on then new beat for click
procedure NewBeatDetect(Screen: TScreenSing); // executed when on then new beat for detection
//procedure NewHalf; // executed when in the half between beats
procedure NewNote(Screen: TScreenSing); // detect note
function  GetMidBeat(Time: real): real;
function  GetTimeFromBeat(Beat: integer): real;
procedure ClearScores(PlayerNum: integer);

implementation

uses
  USongs,
  UJoystick,
  math,
  UCommandLine,
  ULanguage,
  SDL_ttf,
  USkins,
  UCovers,
  UCatCovers,
  UDataBase,
  UPlaylist,
  UDLLManager,
  UParty,
  UConfig,
  UCore,
  UCommon,
  UGraphicClasses,
  UPluginDefs,
  UPlatform;




procedure Main;
var
  WndTitle: string;
begin
  try
    WndTitle := USDXVersionStr;

    if Platform.TerminateIfAlreadyRunning( {var} WndTitle) then
      Exit;
      
    // fix floating-point exceptions (FPE)
    DisableFloatingPointExceptions();
    // fix the locale for string-to-float parsing in C-libs
    SetDefaultNumericLocale();

    //------------------------------
    //StartUp - Create Classes and Load Files
    //------------------------------

    // Initialize SDL
    // Without SDL_INIT_TIMER SDL_GetTicks() might return strange values
    SDL_Init(SDL_INIT_VIDEO or SDL_INIT_TIMER);

    USTime := TTime.Create;
    VideoBGTimer := TRelativeTimer.Create;

    // Commandline Parameter Parser
    Params := TCMDParams.Create;

    // Log + Benchmark
    Log := TLog.Create;
    Log.Title := WndTitle;
    Log.FileOutputEnabled := not Params.NoLog;
    Log.BenchmarkStart(0);

    // Language
    Log.BenchmarkStart(1);
    Log.LogStatus('Initialize Paths', 'Initialization');
    InitializePaths;
    Log.LogStatus('Load Language', 'Initialization');
    Language := TLanguage.Create;

    // Add Const Values:
    Language.AddConst('US_VERSION', USDXVersionStr);
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Language', 1);

    // SDL_ttf
    Log.BenchmarkStart(1);
    Log.LogStatus('Initialize SDL_ttf', 'Initialization');
    TTF_Init();
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Initializing SDL_ttf', 1);

    // Skin
    Log.BenchmarkStart(1);
    Log.LogStatus('Loading Skin List', 'Initialization');
    Skin := TSkin.Create;
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Skin List', 1);

    // Ini + Paths
    Log.BenchmarkStart(1);
    Log.LogStatus('Load Ini', 'Initialization');
    Ini := TIni.Create;
    Ini.Load;

    // Load Languagefile
    if (Params.Language <> -1) then
      Language.ChangeLanguage(ILanguage[Params.Language])
    else
      Language.ChangeLanguage(ILanguage[Ini.Language]);

    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Ini', 1);

    // Sound
    Log.BenchmarkStart(1);
    Log.LogStatus('Initialize Sound', 'Initialization');
    InitializeSound();
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Initializing Sound', 1);

    // Lyrics-engine with media reference timer
    LineState := TLineState.Create();

    // Theme
    Log.BenchmarkStart(1);
    Log.LogStatus('Load Themes', 'Initialization');
    Theme := TTheme.Create(ThemePath + ITheme[Ini.Theme] + '.ini', Ini.Color);
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Themes', 1);

    // Covers Cache
    Log.BenchmarkStart(1);
    Log.LogStatus('Creating Covers Cache', 'Initialization');
    Covers := TCovers.Create;
    Log.LogBenchmark('Loading Covers Cache Array', 1);
    Log.BenchmarkStart(1);

    // Category Covers
    Log.BenchmarkStart(1);
    Log.LogStatus('Creating Category Covers Array', 'Initialization');
    CatCovers:= TCatCovers.Create;
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Category Covers Array', 1);

    // Songs
    //Log.BenchmarkStart(1);
    Log.LogStatus('Creating Song Array', 'Initialization');
    Songs := TSongs.Create;
    //Songs.LoadSongList;

    Log.LogStatus('Creating 2nd Song Array', 'Initialization');
    CatSongs := TCatSongs.Create;

    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Songs', 1);

    // PluginManager
    Log.BenchmarkStart(1);
    Log.LogStatus('PluginManager', 'Initialization');
    DLLMan := TDLLMan.Create;   // Load PluginList
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading PluginManager', 1);

    {// Party Mode Manager
    Log.BenchmarkStart(1);
    Log.LogStatus('PartySession Manager', 'Initialization');
    PartySession := TPartySession.Create;   //Load PartySession

    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading PartySession Manager', 1);      }

    // Graphics
    Log.BenchmarkStart(1);
    Log.LogStatus('Initialize 3D', 'Initialization');
    Initialize3D(WndTitle);
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Initializing 3D', 1);

    // Score Saving System
    Log.BenchmarkStart(1);
    Log.LogStatus('DataBase System', 'Initialization');
    DataBase := TDataBaseSystem.Create;

    if (Params.ScoreFile = '') then
      DataBase.Init (Platform.GetGameUserPath + 'Ultrastar.db')
    else
      DataBase.Init (Params.ScoreFile);

    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading DataBase System', 1);

    // Playlist Manager
    Log.BenchmarkStart(1);
    Log.LogStatus('Playlist Manager', 'Initialization');
    PlaylistMan := TPlaylistManager.Create;
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Playlist Manager', 1);

    // GoldenStarsTwinkleMod
    Log.BenchmarkStart(1);
    Log.LogStatus('Effect Manager', 'Initialization');
    GoldenRec := TEffectManager.Create;
    Log.BenchmarkEnd(1);
    Log.LogBenchmark('Loading Particel System', 1);

    // Joypad
    if (Ini.Joypad = 1) OR (Params.Joypad) then
    begin
      Log.BenchmarkStart(1);
      Log.LogStatus('Initialize Joystick', 'Initialization');
      Joy := TJoy.Create;
      Log.BenchmarkEnd(1);
      Log.LogBenchmark('Initializing Joystick', 1);
    end;

    Log.BenchmarkEnd(0);
    Log.LogBenchmark('Loading Time', 0);

    Log.LogStatus('Creating Core', 'Initialization');
    {Core := TCore.Create(
      USDXShortVersionStr,
      MakeVersion(USDX_VERSION_MAJOR,
                  USDX_VERSION_MINOR,
                  USDX_VERSION_RELEASE,
                  chr(0))
    );  }

    Log.LogStatus('Running Core', 'Initialization');
    //Core.Run;

    //------------------------------
    //Start- Mainloop
    //------------------------------
    Log.LogStatus('Main Loop', 'Initialization');
    MainLoop;

  finally
    //------------------------------
    //Finish Application
    //------------------------------

    // TODO:
    // call an uninitialize routine for every initialize step
    // or at least use the corresponding Free-Methods

    FinalizeSound();

    TTF_Quit();
    SDL_Quit();

    (*
    {$ifdef WIN32}
      if assigned(LCD) and (Ini.LPT = 1) then
        LCD.Clear;
      if assigned(Light) and (Ini.LPT = 2) then
        Light.TurnOff;
    {$endif}
     *)

    if assigned(Log) then
    begin
      Log.LogStatus('Main Loop', 'Finished');
      Log.Free;
    end;
  end;
end;

procedure MainLoop;
var
  Delay:    integer;
const
  MAX_FPS = 100;
begin
  Delay := 0;
  SDL_EnableKeyRepeat(125, 125);

  CountSkipTime();  // JB - for some reason this seems to be needed when we use the SDL Timer functions.
  while not Done do
  begin
    // joypad
    if (Ini.Joypad = 1) or (Params.Joypad) then
      Joy.Update;

    // keyboard events
    CheckEvents;

    // display
    done := not Display.Draw;
    SwapBuffers;

    // light
    //Light.Refresh;

    // delay
    CountMidTime;

    Delay := Floor(1000 / MAX_FPS - 1000 * TimeMid);

    if Delay >= 1 then
      SDL_Delay(Delay); // dynamic, maximum is 100 fps

    CountSkipTime;

    // reinitialization of graphics
    if Restart then
    begin
      Reinitialize3D;
      Restart := false;
    end;

  end;
End;

procedure CheckEvents;
begin
  if Assigned(Display.NextScreen) then
    Exit;
    
  while SDL_PollEvent( @event ) = 1 do
  begin
    case Event.type_ of
      SDL_QUITEV:
      begin
        Display.Fade := 0;
        Display.NextScreenWithCheck := nil;
        Display.CheckOK := True;
      end;
      {
      SDL_MOUSEBUTTONDOWN:
        with Event.button Do
        begin
          if State = SDL_BUTTON_LEFT Then
          begin
            //
          end;
        end;
      }
      SDL_VIDEORESIZE:
      begin
        ScreenW := Event.resize.w;
        ScreenH := Event.resize.h;
        // Note: do NOT call SDL_SetVideoMode here. This would create a new
        // OpenGL render-context and all texture data would be invalidated.
      end;
      SDL_KEYDOWN:
        begin
          // remap the "keypad enter" key to the "standard enter" key
          if (Event.key.keysym.sym = SDLK_KP_ENTER) then
            Event.key.keysym.sym := SDLK_RETURN;

          if (Event.key.keysym.sym = SDLK_F11) or
             ((Event.key.keysym.sym = SDLK_RETURN) and
              ((Event.key.keysym.modifier and KMOD_ALT) <> 0)) then // toggle full screen
          begin
            Ini.FullScreen := integer( not boolean( Ini.FullScreen ) );

            // FIXME: SDL_SetVideoMode creates a new OpenGL RC so we have to
            // reload all texture data (-> whitescreen bug).
            // Only Linux is able to handle screen-switching this way.
            {$IFDEF LINUX}
            if boolean( Ini.FullScreen ) then
            begin
              SDL_SetVideoMode(ScreenW, ScreenH, (Ini.Depth+1) * 16, SDL_OPENGL or SDL_FULLSCREEN);
              SDL_ShowCursor(0);
            end
            else
            begin
              SDL_SetVideoMode(ScreenW, ScreenH, (Ini.Depth+1) * 16, SDL_OPENGL or SDL_RESIZABLE);
              SDL_ShowCursor(1);
            end;

            glViewPort(0, 0, ScreenW, ScreenH);
            {$ENDIF}
          end
          // if print is pressed -> make screenshot and save to screenshot path
          else if (Event.key.keysym.sym = SDLK_SYSREQ) or (Event.key.keysym.sym = SDLK_PRINT) then
            Display.SaveScreenShot
          // if there is a visible popup then let it handle input instead of underlying screen
          // shoud be done in a way to be sure the topmost popup has preference (maybe error, then check)
          else if (ScreenPopupError <> nil) and (ScreenPopupError.Visible) then
            done := not ScreenPopupError.ParseInput(Event.key.keysym.sym, WideChar(Event.key.keysym.unicode), True)
          else if (ScreenPopupCheck <> nil) and (ScreenPopupCheck.Visible) then
            done := not ScreenPopupCheck.ParseInput(Event.key.keysym.sym, WideChar(Event.key.keysym.unicode), True)
          else
          begin
            // check if screen wants to exit
            done := not Display.CurrentScreen^.ParseInput(Event.key.keysym.sym, WideChar(Event.key.keysym.unicode), True);

            // if screen wants to exit
            if done then
            begin
              // if question option is enabled then show exit popup
              if (Ini.AskbeforeDel = 1) then
              begin
                Display.CurrentScreen^.CheckFadeTo(nil,'MSG_QUIT_USDX');
              end
              else // if ask-for-exit is disabled then simply exit
              begin
                Display.Fade := 0;
                Display.NextScreenWithCheck := nil;
                Display.CheckOK := True;
              end;
            end;

          end;
        end;
      SDL_JOYAXISMOTION:
        begin
          // not implemented
        end;
      SDL_JOYBUTTONDOWN:
        begin
          // not implemented
        end;
    end; // case
  end; // while
end;

function GetTimeForBeats(BPM, Beats: real): real;
begin
  Result := 60 / BPM * Beats;
end;

function GetBeats(BPM, msTime: real): real;
begin
  Result := BPM * msTime / 60;
end;

procedure GetMidBeatSub(BPMNum: integer; var Time: real; var CurBeat: real);
var
  NewTime:  real;
begin
  if High(CurrentSong.BPM) = BPMNum then
  begin
    // last BPM
    CurBeat := CurrentSong.BPM[BPMNum].StartBeat + GetBeats(CurrentSong.BPM[BPMNum].BPM, Time);
    Time := 0;
  end
  else
  begin
    // not last BPM
    // count how much time is it for start of the new BPM and store it in NewTime
    NewTime := GetTimeForBeats(CurrentSong.BPM[BPMNum].BPM, CurrentSong.BPM[BPMNum+1].StartBeat - CurrentSong.BPM[BPMNum].StartBeat);

    // compare it to remaining time
    if (Time - NewTime) > 0 then
    begin
      // there is still remaining time
      CurBeat := CurrentSong.BPM[BPMNum].StartBeat;
      Time := Time - NewTime;
    end
    else
    begin
      // there is no remaining time
      CurBeat := CurrentSong.BPM[BPMNum].StartBeat + GetBeats(CurrentSong.BPM[BPMNum].BPM, Time);
      Time := 0;
    end; // if
  end; // if
end;

function GetMidBeat(Time: real): real;
var
  CurBeat:  real;
  CurBPM:   integer;
  //TopBeat:  real;
  //TempBeat: real;
  //TempTime: real;
begin
  Result := 0;
  if Length(CurrentSong.BPM) = 1 then
    Result := Time * CurrentSong.BPM[0].BPM / 60;

  // 2 BPMs
  {
  if Length(CurrentSong.BPM) > 1 then begin
    // new system
    CurBeat := 0;
    TopBeat := GetBeats(CurrentSong.BPM[0].BPM, Time);
    if TopBeat > CurrentSong.BPM[1].StartBeat then begin
      // analyze second BPM
      Time := Time - GetTimeForBeats(CurrentSong.BPM[0].BPM, CurrentSong.BPM[1].StartBeat - CurBeat);
      CurBeat := CurrentSong.BPM[1].StartBeat;
      TopBeat := GetBeats(CurrentSong.BPM[1].BPM, Time);
      Result := CurBeat + TopBeat;

    end
    else
    begin
      // first part
      Result := TopBeat;
    end;
  end;
  }

  // more BPMs
  if Length(CurrentSong.BPM) > 1 then
  begin
    CurBeat := 0;
    CurBPM := 0;
    while (Time > 0) do
    begin
      GetMidBeatSub(CurBPM, Time, CurBeat);
      Inc(CurBPM);
    end;

    Result := CurBeat;
  end;
end;

function GetTimeFromBeat(Beat: integer): real;
var
  CurBPM:   integer;
begin
  Result := 0;
  if Length(CurrentSong.BPM) = 1 then
    Result := CurrentSong.GAP / 1000 + Beat * 60 / CurrentSong.BPM[0].BPM;

  // more BPMs
  if Length(CurrentSong.BPM) > 1 then
  begin
    Result := CurrentSong.GAP / 1000;
    CurBPM := 0;
    while (CurBPM <= High(CurrentSong.BPM)) and
          (Beat > CurrentSong.BPM[CurBPM].StartBeat) do
    begin
      if (CurBPM < High(CurrentSong.BPM)) and
         (Beat >= CurrentSong.BPM[CurBPM+1].StartBeat) then
      begin
        // full range
        Result := Result + (60 / CurrentSong.BPM[CurBPM].BPM) *
                           (CurrentSong.BPM[CurBPM+1].StartBeat - CurrentSong.BPM[CurBPM].StartBeat);
      end;

      if (CurBPM = High(CurrentSong.BPM)) or
         (Beat < CurrentSong.BPM[CurBPM+1].StartBeat) then
      begin
        // in the middle
        Result := Result + (60 / CurrentSong.BPM[CurBPM].BPM) *
                           (Beat - CurrentSong.BPM[CurBPM].StartBeat);
      end;
      Inc(CurBPM);
    end;

    {
    while (Time > 0) do
    begin
      GetMidBeatSub(CurBPM, Time, CurBeat);
      Inc(CurBPM);
    end;
    }
  end; // if}
end;

procedure Sing(Screen: TScreenSing);
var
  Count:    integer;
  CountGr:  integer;
  CP:       integer;
  Done:     real;
  N:        integer;
begin
  LineState.OldBeat := LineState.CurrentBeat;
  // new system with variable BPM in function
  LineState.MidBeat := GetMidBeat(LineState.CurrentTime -
                                  (CurrentSong.Gap {+ 90 I've forgotten for what it is}) / 1000);
  LineState.CurrentBeat := Floor(LineState.MidBeat);

  //LineState.OldHalf := LineState.AktHalf;
  //LineState.MidHalf := LineState.MidBeat + 0.5;
  //LineState.AktHalf := Floor(LineState.MidHalf);

  LineState.OldBeatC := LineState.CurrentBeatC;
  LineState.MidBeatC := GetMidBeat(LineState.CurrentTime - (CurrentSong.Gap) / 1000);
  LineState.CurrentBeatC := Floor(LineState.MidBeatC);

  LineState.OldBeatD := LineState.CurrentBeatD;
  // MidBeat with additional GAP
  LineState.MidBeatD := -0.5+GetMidBeat(LineState.CurrentTime - (CurrentSong.Gap + 120 + 20) / 1000);
  LineState.CurrentBeatD := Floor(LineState.MidBeatD);
  LineState.FracBeatD := Frac(LineState.MidBeatD);

  // sentences routines
  for CountGr := 0 to 0 do //High(Gracz)
  begin;
    CP := CountGr;
    // old parts
    LineState.OldLine := Lines[CP].Current;

    // choose current parts
    for Count := 0 to Lines[CP].High do
    begin
      if LineState.CurrentBeat >= Lines[CP].Line[Count].Start then
        Lines[CP].Current := Count;
    end;

    // clean player note if there is a new line 
    // (optimization on halfbeat time)
    if Lines[CP].Current <> LineState.OldLine then
      NewSentence(Screen);

  end; // for CountGr

  // execute operations on beat 
  if (LineState.CurrentBeat >= 0) and (LineState.OldBeat <> LineState.CurrentBeat) then
    NewBeat(Screen);

  // make some operations on clicks
  if {(LineState.CurrentBeatC >= 0) and }(LineState.OldBeatC <> LineState.CurrentBeatC) then
    NewBeatClick(Screen);

  // make some operations when detecting new voice pitch
  if (LineState.CurrentBeatD >= 0) and (LineState.OldBeatD <> LineState.CurrentBeatD) then
    NewBeatDetect(Screen);

  // execute operations on beat field 
//  if (LineState.AktHalf >= 1) and (LineState.OldHalf <> LineState.AktHalf) then
//    NewHalf;

  // remove moving text
  Done := 1;
  for N := 0 to Lines[0].Line[Lines[0].Current].HighNote do
  begin
    if (Lines[0].Line[Lines[0].Current].Note[N].Start <= LineState.MidBeat) and
       (Lines[0].Line[Lines[0].Current].Note[N].Start + Lines[0].Line[Lines[0].Current].Note[N].Length >= LineState.MidBeat) then
    begin
      Done := (LineState.MidBeat - Lines[0].Line[Lines[0].Current].Note[N].Start) / (Lines[0].Line[Lines[0].Current].Note[N].Length);
    end;
  end;

  N := Lines[0].Line[Lines[0].Current].HighNote;

  // if last note is used
  {// todo: Lyrics
  if (Ini.LyricsEffect = 1) and (Done = 1) and
    (LineState.MidBeat > Lines[0].Line[Lines[0].Current].Note[N].Start + Lines[0].Line[Lines[0].Current].Note[N].Length)
    then Screen.LyricMain.Selected := -1;

  if Done > 1 then Done := 1;
  Screen.LyricMain.Done := Done;
  }

  // use Done with LCD
  {
  with ScreenSing do begin
    if LyricMain.Selected >= 0 then begin
      LCD.MoveCursor(1, LyricMain.SelectedLetter + Round((LyricMain.SelectedLength-1) * Done));
      LCD.ShowCursor;
    end;
  end;
  }
end;

procedure NewSentence(Screen: TScreenSing);
var
  i: Integer;
begin
  // clean note of player
  for i := 0 to High(Player) do
  begin
    Player[i].LengthNote := 0;
    Player[i].HighNote := -1;
    SetLength(Player[i].Note, 0);
  end;

  // add words to lyrics
  with Screen do
  begin
    {LyricMain.AddCzesc(Lines[0].Current);
    if Lines[0].Current < Lines[0].High then
      LyricSub.AddCzesc(Lines[0].Current+1)
    else
      LyricSub.Clear;}
    while (not Lyrics.LineinQueue) and (Lyrics.LineCounter <= High(Lines[0].Line)) do
      Lyrics.AddLine(@Lines[0].Line[Lyrics.LineCounter]);
  end;

  //Screen.UpdateLCD;
  
  // on sentence change...
  Screen.onSentenceChange(Lines[0].Current);
end;

procedure NewBeat(Screen: TScreenSing);
var
  Count:      integer;
  //TempBeat: integer;
begin
  // add a text mark
  //SingScreen.LyricMain.Selected := -1;
  for Count := 0 to Lines[0].Line[Lines[0].Current].HighNote do
    if (Lines[0].Line[Lines[0].Current].Note[Count].Start = LineState.CurrentBeat) then
    begin
      // operates on currently beated note
      //Todo: Lyrics
      //Sender.LyricMain.Selected := Count;

      //LCD.MoveCursor(1, ScreenSing.LyricMain.SelectedLetter);
      //LCD.ShowCursor;

      //LCD.MoveCursorBR(Sender.LyricMain.SelectedLetter);
      //LCD.ShowCursor;
    end;
end;

procedure NewBeatClick;
var
  Count:    integer;
  //LPT_1:  integer;
  //LPT_2:  integer;
begin
  //LPT_1 := 1;
  //LPT_2 := 1;

  // beat click
  if ((Ini.BeatClick = 1) and
      ((LineState.CurrentBeatC + Lines[0].Resolution + Lines[0].NotesGAP) mod Lines[0].Resolution = 0)) then
  begin
    AudioPlayback.PlaySound(SoundLib.Click);
  end;

  {
  // debug system on LPT
  if ((LineState.CurrentBeatC + Lines[0].Resolution + Lines[0].NotesGAP) mod Lines[0].Resolution = 0) then
  begin
    LPT_1 := 0;
    Light.LightOne(0, 150);

    Light.LightOne(1, 200); // beat light
    if ParamStr(1) = '-doublelights' then
      Light.LightOne(0, 200); // beat light


    if ((LineState.CurrentBeatC + Lines[0].Resolution + Lines[0].NotesGAP) mod (Lines[0].Resolution * 2) = 0) then
      Light.LightOne(0, 150)
    else
      Light.LightOne(1, 150)
  end;
  }

  for Count := 0 to Lines[0].Line[Lines[0].Current].HighNote do
  begin
    if (Lines[0].Line[Lines[0].Current].Note[Count].Start = LineState.CurrentBeatC) then
    begin
      // click assist
      if Ini.ClickAssist = 1 then
        AudioPlayback.PlaySound(SoundLib.Click);

      {
      //LPT_2 := 0;
      if ParamStr(1) <> '-doublelights' then
        Light.LightOne(0, 150); //125
      }

      // drum machine
      (*
      TempBeat := LineState.CurrentBeat;// + 2;
      if (TempBeat mod 8 = 0) then Music.PlayDrum;
      if (TempBeat mod 8 = 4) then Music.PlayClap;
      //if (TempBeat mod 4 = 2) then Music.PlayHihat;
      if (TempBeat mod 4 <> 0) then Music.PlayHihat;
      *)
    end;
  end;

  {$IFDEF UseSerialPort}
    // PortWriteB($378, LPT_1 + LPT_2 * 2); // 0 light
  {$ENDIF}
end;

procedure NewBeatDetect(Screen: TScreenSing);
begin
  NewNote(Screen);
end;

procedure NewNote(Screen: TScreenSing);
var
  LineFragmentIndex: integer;
  CurrentLineFragment: PLineFragment;
  PlayerIndex: integer;
  CurrentSound: TCaptureBuffer;
  CurrentPlayer: PPlayer;
  LastPlayerNote: PPLayerNote;
  Line: PLine;
  SentenceIndex: integer;
  SentenceMin: integer;
  SentenceMax: integer;
  SentenceDetected: integer; // sentence of detected note
  NoteAvailable: boolean;
  NewNote: boolean;
  Range: integer;
  NoteHit: boolean;
  MaxSongPoints: integer; // max. points for the song (without line bonus)
  MaxLinePoints: Real;    // max. points for the current line
begin
  //Log.LogStatus('Beat ' + IntToStr(LineState.CurrentBeat) + ' HalfBeat ' + IntToStr(LineState.AktHalf), 'NewBeat');

  // TODO: add duet mode support
  // use Lines[LineSetIndex] with LineSetIndex depending on the current player

  // count min and max sentence range for checking (detection is delayed to the notes we see on the screen)
  SentenceMin := Lines[0].Current-1;
  if (SentenceMin < 0) then
    SentenceMin := 0;
  SentenceMax := Lines[0].Current;

  // check for an active note at the current time defined in the lyrics
  NoteAvailable := false;
  SentenceDetected := SentenceMin;
  for SentenceIndex := SentenceMin to SentenceMax do
  begin
    Line := @Lines[0].Line[SentenceIndex];
    for LineFragmentIndex := 0 to Line.HighNote do
    begin
      CurrentLineFragment := @Line.Note[LineFragmentIndex];
      // check if line is active
      if ((CurrentLineFragment.Start <= LineState.CurrentBeatD) and
          (CurrentLineFragment.Start + CurrentLineFragment.Length-1 >= LineState.CurrentBeatD)) and
         (CurrentLineFragment.NoteType <> ntFreestyle) and // but ignore FreeStyle notes
         (CurrentLineFragment.Length > 0) then // and make sure the note lengths is at least 1
      begin
        SentenceDetected := SentenceIndex;
        NoteAvailable := true;
        Break;
      end;
    end;
    // TODO: break here, if NoteAvailable is true? We would then use the first instead
    // of the last note matching the current beat if notes overlap. But notes
    // should not overlap at all.
    //if (NoteAvailable) then
    //  Break;
  end;

  // analyze player signals
  for PlayerIndex := 0 to PlayersPlay-1 do
  begin
    CurrentPlayer := @Player[PlayerIndex];
    CurrentSound := AudioInputProcessor.Sound[PlayerIndex];
    LastPlayerNote := @CurrentPlayer.Note[CurrentPlayer.HighNote];

    // analyze buffer
    CurrentSound.AnalyzeBuffer;

    // add some noise
    // TODO: do we need this?
    //LineState.Tone := LineState.Tone + Round(Random(3)) - 1;

    // add note if possible
    if (CurrentSound.ToneValid and NoteAvailable) then
    begin
      Line := @Lines[0].Line[SentenceDetected];
      
      // process until last note
      for LineFragmentIndex := 0 to Line.HighNote do
      begin
        CurrentLineFragment := @Line.Note[LineFragmentIndex];
        if (CurrentLineFragment.Start <= LineState.OldBeatD+1) and
           (CurrentLineFragment.Start + CurrentLineFragment.Length > LineState.OldBeatD+1) then
        begin
          // compare notes (from song-file and from player)

          // move players tone to proper octave
          while (CurrentSound.Tone - CurrentLineFragment.Tone > 6) do
            CurrentSound.Tone := CurrentSound.Tone - 12;

          while (CurrentSound.Tone - CurrentLineFragment.Tone < -6) do
            CurrentSound.Tone := CurrentSound.Tone + 12;

          // half size notes patch
          NoteHit := false;

          //if Ini.Difficulty = 0 then Range := 2;
          //if Ini.Difficulty = 1 then Range := 1;
          //if Ini.Difficulty = 2 then Range := 0;
          Range := 2 - Ini.Difficulty;

          // check if the player hit the correct tone within the tolerated range
          if (Abs(CurrentLineFragment.Tone - CurrentSound.Tone) <= Range) then
          begin
            // adjust the players tone to the correct one
            // TODO: do we need to do this?
            CurrentSound.Tone := CurrentLineFragment.Tone;

            // half size notes patch
            NoteHit := true;

            if (Ini.LineBonus > 0) then
              MaxSongPoints := MAX_SONG_SCORE - MAX_SONG_LINE_BONUS
            else
              MaxSongPoints := MAX_SONG_SCORE;

            // Note: ScoreValue is the sum of all note values of the song
            MaxLinePoints := MaxSongPoints / Lines[0].ScoreValue;

            // FIXME: is this correct? Why do we add the points for a whole line
            // if just one note is correct?
            case CurrentLineFragment.NoteType of
              ntNormal:  CurrentPlayer.Score := CurrentPlayer.Score + MaxLinePoints;
              ntGolden:  CurrentPlayer.ScoreGolden := CurrentPlayer.ScoreGolden + MaxLinePoints;
            end;

            CurrentPlayer.ScoreInt := Floor(CurrentPlayer.Score / 10) * 10;
            CurrentPlayer.ScoreGoldenInt := Floor(CurrentPlayer.ScoreGolden / 10) * 10;

            CurrentPlayer.ScoreTotalInt := CurrentPlayer.ScoreInt +
                                           CurrentPlayer.ScoreGoldenInt +
                                           CurrentPlayer.ScoreLineInt;
          end;

        end; // operation
      end; // for

      // check if we have to add a new note or extend the note's length
      if (SentenceDetected = SentenceMax) then
      begin
        // we will add a new note
        NewNote := true;
        // if last has the same tone
        if ((CurrentPlayer.LengthNote > 0) and
            (LastPlayerNote.Tone = CurrentSound.Tone) and
            ((LastPlayerNote.Start + LastPlayerNote.Length) = LineState.CurrentBeatD)) then
        begin
          NewNote := false;
        end;

        // if is not as new note to control
        for LineFragmentIndex := 0 to Line.HighNote do
        begin
          if (Line.Note[LineFragmentIndex].Start = LineState.CurrentBeatD) then
            NewNote := true;
        end;

        // add new note
        if NewNote then
        begin
          // new note
          Inc(CurrentPlayer.LengthNote);
          Inc(CurrentPlayer.HighNote);
          SetLength(CurrentPlayer.Note, CurrentPlayer.LengthNote);

          // update player's last note
          LastPlayerNote := @CurrentPlayer.Note[CurrentPlayer.HighNote];
          with LastPlayerNote^ do
          begin
            Start  := LineState.CurrentBeatD;
            Length := 1;
            Tone   := CurrentSound.Tone; // Tone || ToneAbs
            Detect := LineState.MidBeat;
            Hit    := NoteHit; // half note patch
          end;
        end
        else
        begin
          // extend note length
          Inc(LastPlayerNote.Length);
        end;

        // check for perfect note and then lit the star (on Draw)
        for LineFragmentIndex := 0 to Line.HighNote do
        begin
          CurrentLineFragment := @Line.Note[LineFragmentIndex];
          if (CurrentLineFragment.Start = LastPlayerNote.Start) and
             (CurrentLineFragment.Length = LastPlayerNote.Length) and
             (CurrentLineFragment.Tone = LastPlayerNote.Tone) then
          begin
            LastPlayerNote.Perfect := true;
          end;
        end;
      end; // if SentenceDetected = SentenceMax

    end; // if Detected
  end; // for PlayerIndex

  //Log.LogStatus('EndBeat', 'NewBeat');

  // on sentence end -> for LineBonus and display of SingBar (rating pop-up)
  if (SentenceDetected >= Low(Lines[0].Line)) and
     (SentenceDetected <= High(Lines[0].Line)) then
  begin
    Line := @Lines[0].Line[SentenceDetected];
    CurrentLineFragment := @Line.Note[Line.HighNote];
    if ((CurrentLineFragment.Start + CurrentLineFragment.Length - 1) = LineState.CurrentBeatD) then
    begin
      if assigned(Screen) then
        Screen.OnSentenceEnd(SentenceDetected);
    end;
  end;

end;

procedure ClearScores(PlayerNum: integer);
begin
  with Player[PlayerNum] do
  begin
    Score := 0;
    ScoreInt := 0;
    ScoreLine := 0;
    ScoreLineInt := 0;
    ScoreGolden := 0;
    ScoreGoldenInt := 0;
    ScoreTotalInt := 0;
  end;
end;

//--------------------
// Function sets all absolute paths e.g. song path and makes sure the directorys exist
//--------------------
procedure InitializePaths;

  // Initialize a path variable
  // After setting paths, make sure that paths exist
  function initialize_path( out aPathVar : string; const aLocation : string ): boolean;
  var
    lWriteable: Boolean;
    lAttrib   : integer;
  begin
    lWriteable := false;
    aPathVar   := aLocation;

    // Make sure the directory is needex
    ForceDirectories(aPathVar);

    if DirectoryExists(aPathVar) then
    begin
      lAttrib := fileGetAttr(aPathVar);

      lWriteable := (lAttrib and faDirectory <> 0) and
                not (lAttrib and faReadOnly  <> 0)
    end;
    
    if not lWriteable then
      Log.LogError('Dir ('+ aLocation +') is Readonly', 'initialize_path');

    result := lWriteable;
  end;

begin
  initialize_path( LogPath         , Platform.GetLogPath                             );
  initialize_path( SoundPath       , Platform.GetGameSharedPath + 'Sounds'      + PathDelim );
  initialize_path( ThemePath       , Platform.GetGameSharedPath + 'Themes'      + PathDelim );
  initialize_path( SkinsPath       , Platform.GetGameSharedPath + 'Themes'       + PathDelim );
  initialize_path( LanguagesPath   , Platform.GetGameSharedPath + 'Languages'   + PathDelim );
  initialize_path( PluginPath      , Platform.GetGameSharedPath + 'Plugins'     + PathDelim );
  initialize_path( VisualsPath     , Platform.GetGameSharedPath + 'Visuals'     + PathDelim );
  initialize_path( ResourcesPath   , Platform.GetGameSharedPath + 'Resources'   + PathDelim );
  initialize_path( ScreenshotsPath , Platform.GetGameUserPath + 'Screenshots' + PathDelim );

  // Users Song Path ....
  initialize_path( UserSongPath        , Platform.GetGameUserPath + 'Songs'       + PathDelim );
  initialize_path( UserCoversPath      , Platform.GetGameUserPath + 'Covers'      + PathDelim );
  initialize_path( UserPlaylistPath    , Platform.GetGameUserPath + 'Playlists'   + PathDelim );

  // Shared Song Path ....
  initialize_path( SongPath        , Platform.GetGameSharedPath + 'Songs'       + PathDelim );
  initialize_path( CoversPath      , Platform.GetGameSharedPath + 'Covers'      + PathDelim );
  initialize_path( PlaylistPath    , Platform.GetGameSharedPath + 'Playlists'   + PathDelim );

  DecimalSeparator := '.';
end;

end.
