unit UScreenSong;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}


uses
  UMenu,
  SDL,
  UMusic,
  UFiles,
  UTime,
  UDisplay,
  USongs,
  SysUtils,
  UCommon,
  ULog,
  UThemes,
  UTexture,
  ULanguage,
  //ULCD, //TODO: maybe LCD Support as Plugin?
  //ULight, //TODO: maybe Light Support as Plugin?
  USong,
  UIni;

type
  TScreenSong = class(TMenu)
    private
      EqualizerData: TFFTData; // moved here to avoid stack overflows
      EqualizerBands: array of Byte;
      EqualizerTime: Cardinal;

      procedure StartMusicPreview(Song: TSong);
    public
      TextArtist:   integer;
      TextTitle:    integer;
      TextNumber:   integer;

      //Video Icon Mod
      VideoIcon:         Cardinal;

      TextCat:   integer;
      StaticCat: integer;

      SongCurrent:  real;
      SongTarget:   real;

      HighSpeed:    boolean;
      CoverFull:    boolean;
      CoverTime:    real;
      MusicStartTime: cardinal;

      CoverX:       integer;
      CoverY:       integer;
      CoverW:       integer;
      is_jump:      boolean; // Jump to Song Mod
      is_jump_title:boolean; //Jump to SOng MOd-YTrue if search for Title

      //Party Mod
      Mode: TSingMode;

      //party Statics (Joker)
      StaticTeam1Joker1: Cardinal;
      StaticTeam1Joker2: Cardinal;
      StaticTeam1Joker3: Cardinal;
      StaticTeam1Joker4: Cardinal;
      StaticTeam1Joker5: Cardinal;

      StaticTeam2Joker1: Cardinal;
      StaticTeam2Joker2: Cardinal;
      StaticTeam2Joker3: Cardinal;
      StaticTeam2Joker4: Cardinal;
      StaticTeam2Joker5: Cardinal;

      StaticTeam3Joker1: Cardinal;
      StaticTeam3Joker2: Cardinal;
      StaticTeam3Joker3: Cardinal;
      StaticTeam3Joker4: Cardinal;
      StaticTeam3Joker5: Cardinal;

      StaticParty:    array of Cardinal;
      TextParty:      array of Cardinal;
      StaticNonParty: array of Cardinal;
      TextNonParty:   array of Cardinal;


      constructor Create; override;
      procedure SetScroll;
      procedure SetScroll1;
      procedure SetScroll2;
      procedure SetScroll3;
      procedure SetScroll4;
      procedure SetScroll5;
      procedure SetScroll6;
      function ParseInput(PressedKey: Cardinal; CharCode: WideChar; PressedDown: Boolean): Boolean; override;
      function Draw: boolean; override;
      procedure GenerateThumbnails();
      procedure onShow; override;
      procedure onHide; override;
      procedure SelectNext;
      procedure SelectPrev;
      //procedure UpdateLCD; //TODO: maybe LCD Support as Plugin?
      procedure SkipTo(Target: Cardinal);
      procedure FixSelected; //Show Wrong Song when Tabs on Fix
      procedure FixSelected2; //Show Wrong Song when Tabs on Fix
      procedure ShowCatTL(Cat: Integer);// Show Cat in Top left
      procedure ShowCatTLCustom(Caption: String);// Show Custom Text in Top left
      procedure HideCatTL;// Show Cat in Tob left
      procedure Refresh; //Refresh Song Sorting
      procedure DrawEqualizer;
      procedure ChangeMusic;
      //Party Mode
      procedure SelectRandomSong;
      procedure SetJoker;
      procedure SetStatics;
      //procedures for Menu
      procedure StartSong;
      procedure OpenEditor;
      procedure DoJoker(Team: Byte);
      procedure SelectPlayers;

      procedure UnLoadDetailedCover;

      //Extensions
      procedure DrawExtensions;
  end;

implementation

uses
  UGraphic,
  UMain,
  UCovers,
  math,
  gl,
  USkins,
  UDLLManager,
  UParty,
  UPlaylist,
  UScreenSongMenu;

// ***** Public methods ****** //

//Show Wrong Song when Tabs on Fix
procedure TScreenSong.FixSelected;
var I, I2: Integer;
begin
  if CatSongs.VisibleSongs > 0 then
  begin
    I2:= 0;
    for I := low(CatSongs.Song) to High(Catsongs.Song) do
    begin
      if CatSongs.Song[I].Visible then
        inc(I2);

      if I = Interaction - 1 then
        break;
    end;

    SongCurrent := I2;
    SongTarget  := I2;
  end;
end;

procedure TScreenSong.FixSelected2;
var I, I2: Integer;
begin
  if CatSongs.VisibleSongs > 0 then
  begin
    I2:= 0;
    for I := low(CatSongs.Song) to High(Catsongs.Song) do
    begin
      if CatSongs.Song[I].Visible then
        inc(I2);

      if I = Interaction - 1 then
        break;
    end;

    SongTarget  := I2;
  end;
end;
//Show Wrong Song when Tabs on Fix End

procedure TScreenSong.ShowCatTLCustom(Caption: String);// Show Custom Text in Top left
begin
  Text[TextCat].Text := Caption;
  Text[TextCat].Visible := true;
  Static[StaticCat].Visible := False;
end;

//Show Cat in Top Left Mod
procedure TScreenSong.ShowCatTL(Cat: Integer);
begin
  //Change
  Text[TextCat].Text := CatSongs.Song[Cat].Artist;
  //showmessage(CatSongs.Song[Cat].Path + CatSongs.Song[Cat].Cover);
  //Static[StaticCat].Texture := Texture.GetTexture(Button[Cat].Texture.Name, TEXTURE_TYPE_PLAIN, true);

  Static[StaticCat].Texture := Texture.GetTexture(Button[Cat].Texture.Name, TEXTURE_TYPE_PLAIN, true);
  //Texture.GetTexture(Button[Cat].Texture.Name, TEXTURE_TYPE_PLAIN, false);

  //Show
  Text[TextCat].Visible := true;
  Static[StaticCat].Visible := True;
end;

procedure TScreenSong.HideCatTL;
begin
  //Hide
  //Text[TextCat].Visible := false;
  Static[StaticCat].Visible := false;
  //New -> Show Text specified in Theme
  Text[TextCat].Visible := True;
  Text[TextCat].Text := Theme.Song.TextCat.Text;
end;
//Show Cat in Top Left Mod End


// Method for input parsing. If False is returned, GetNextWindow
// should be checked to know the next window to load;
function TScreenSong.ParseInput(PressedKey: Cardinal; CharCode: WideChar; PressedDown: Boolean): Boolean;
var
  I:      integer;
  I2:     integer;
  SDL_ModState:  Word;
  Letter: WideChar;
begin
  Result := true;

  //Song Screen Extensions (Jumpto + Menu)
  if (ScreenSongMenu.Visible) then
  begin
    Result := ScreenSongMenu.ParseInput(PressedKey, CharCode, PressedDown);
    Exit;
  end
  else if (ScreenSongJumpto.Visible) then
  begin
    Result := ScreenSongJumpto.ParseInput(PressedKey, CharCode, PressedDown);
    Exit;
  end;

  if (PressedDown) then
  begin // Key Down

    SDL_ModState := SDL_GetModState and (KMOD_LSHIFT + KMOD_RSHIFT
    + KMOD_LCTRL + KMOD_RCTRL + KMOD_LALT  + KMOD_RALT);

    //Jump to Artist/Titel
    if ((SDL_ModState and KMOD_LALT <> 0) and (Mode = smNormal)) then
    begin
      if (WideCharUpperCase(CharCode)[1] in ([WideChar('A')..WideChar('Z')]) ) then
      begin
        Letter := WideCharUpperCase(CharCode)[1];
        I2 := Length(CatSongs.Song);

        //Jump To Titel
        if (SDL_ModState = (KMOD_LALT or KMOD_LSHIFT)) then
        begin
          for I := 1 to high(CatSongs.Song) do
          begin
            if (CatSongs.Song[(I + Interaction) mod I2].Visible) and
               (Length(CatSongs.Song[(I + Interaction) mod I2].Title)>0) and
               (WideStringUpperCase(CatSongs.Song[(I + Interaction) mod I2].Title)[1] = Letter) then
            begin
              SkipTo(CatSongs.VisibleIndex((I + Interaction) mod I2));

              AudioPlayback.PlaySound(SoundLib.Change);

              ChangeMusic;
              SetScroll4;
              //UpdateLCD;   //TODO: maybe LCD Support as Plugin?
              //Break and Exit
              Exit;
            end;
          end;
        end
        //Jump to Artist
        else if (SDL_ModState = KMOD_LALT) then
        begin
          for I := 1 to high(CatSongs.Song) do
          begin
            if (CatSongs.Song[(I + Interaction) mod I2].Visible) and
               (Length(CatSongs.Song[(I + Interaction) mod I2].Artist)>0) and
               (WideStringUpperCase(CatSongs.Song[(I + Interaction) mod I2].Artist)[1] = Letter) then
            begin
              SkipTo(CatSongs.VisibleIndex((I + Interaction) mod I2));

              AudioPlayback.PlaySound(SoundLib.Change);

              ChangeMusic;
              SetScroll4;
              //UpdateLCD;   //TODO: maybe LCD Support as Plugin?

              //Break and Exit
              Exit;
            end;
          end;
        end;
      end;

      Exit;
    end;

    // check normal keys
    case WideCharUpperCase(CharCode)[1] of
      'Q':
        begin
          Result := false;
          Exit;
        end;

      'M': //Show SongMenu
        begin
          if (Songs.SongList.Count > 0) then
          begin
            if (Mode = smNormal) then
            begin
              if (not CatSongs.Song[Interaction].Main) then // clicked on Song
              begin 
                if CatSongs.CatNumShow = -3 then
                  ScreenSongMenu.MenuShow(SM_Playlist)
                else
                  ScreenSongMenu.MenuShow(SM_Main);
              end
              else
              begin
                ScreenSongMenu.MenuShow(SM_Playlist_Load);
              end;
            end //Party Mode -> Show Party Menu
            else
            begin
              ScreenSongMenu.MenuShow(SM_Party_Main);
            end;
          end;
          Exit;
        end;

      'P': //Show Playlist Menu
        begin
          if (Songs.SongList.Count > 0) and (Mode = smNormal) then
          begin
              ScreenSongMenu.MenuShow(SM_Playlist_Load);
          end;
          Exit;
        end;

      'J': //Show Jumpto Menu
        begin
          if (Songs.SongList.Count > 0) and (Mode = smNormal) then
          begin
            ScreenSongJumpto.Visible := True;
          end;
          Exit;
        end;

      'E':
        begin
          OpenEditor;
          Exit;
        end;

      'R':
        begin
          if (Songs.SongList.Count > 0) and (Mode = smNormal) then
          begin
            if (SDL_ModState = KMOD_LSHIFT) and (Ini.Tabs_at_startup = 1) then //Random Category
            begin
              I2 := 0; //Count Cats
              for I:= low(CatSongs.Song) to high (CatSongs.Song) do
              begin
                if CatSongs.Song[I].Main then
                  Inc(I2);
              end;

              I2 := Random (I2)+1; //Zufall

              //Find Cat:
              for I:= low(CatSongs.Song) to high (CatSongs.Song) do
                begin
                if CatSongs.Song[I].Main then
                  Dec(I2);
                if (I2<=0) then
                begin
                  //Show Cat in Top Left Mod
                  ShowCatTL (I);

                  Interaction := I;

                  CatSongs.ShowCategoryList;
                  CatSongs.ClickCategoryButton(I);
                  SelectNext;
                  FixSelected;
                  break;
                end;
              end;
            end
            else if (SDL_ModState = KMOD_LCTRL) and (Ini.Tabs_at_startup = 1) then //random in All Categorys
            begin
              repeat
                I2 := Random(high(CatSongs.Song)+1) - low(CatSongs.Song)+1;
              until CatSongs.Song[I2].Main = false;

              //Search Cat
              for I := I2 downto low(CatSongs.Song) do
              begin
              if CatSongs.Song[I].Main then
                break;
              end;
              
              //In I is now the categorie in I2 the song

              //Choose Cat
              CatSongs.ShowCategoryList;

              //Show Cat in Top Left Mod
              ShowCatTL (I);

              CatSongs.ClickCategoryButton(I);
              SelectNext;

              //Fix: Not Existing Song selected:
              //if (I+1=I2) then Inc(I2);

              //Choose Song
              SkipTo(I2-I);
            end
            else //Random in one Category
            begin
              SkipTo(Random(CatSongs.VisibleSongs));
            end;
            AudioPlayback.PlaySound(SoundLib.Change);

            ChangeMusic;
            SetScroll4;
            //UpdateLCD; //TODO: maybe LCD Support as Plugin?
          end;
          Exit;
        end;
    end; // normal keys

    // check special keys
    case PressedKey of
      SDLK_ESCAPE,
      SDLK_BACKSPACE :
        begin
          if (Mode = smNormal) then
          begin
            //On Escape goto Cat-List Hack
            if (Ini.Tabs_at_startup = 1) and (CatSongs.CatNumShow <> -1) then
              begin
              //Find Category
              I := Interaction;
              while not catsongs.Song[I].Main  do
                begin
                Dec (I);
                if (I < low(catsongs.Song)) then
                  break;
                end;
              if (I<= 1) then
              Interaction := high(catsongs.Song)
              else
              Interaction := I - 1;

              //Stop Music
              AudioPlayback.Stop;

              CatSongs.ShowCategoryList;

              //Show Cat in Top Left Mod
              HideCatTL;


              //Show Wrong Song when Tabs on Fix
              SelectNext;
              FixSelected;
              //SelectPrev;
              //CatSongs.Song[0].Visible := False;
              end
            else
            begin
            //On Escape goto Cat-List Hack End
              //Tabs off and in Search or Playlist -> Go back to Song view
              if (CatSongs.CatNumShow < -1) then
              begin
                //Atm: Set Empty Filter
                CatSongs.SetFilter('', 0);

                //Show Cat in Top Left Mod
                HideCatTL;
                Interaction := 0;

                //Show Wrong Song when Tabs on Fix
                SelectNext;
                FixSelected;

                ChangeMusic;
              end
              else
              begin
                AudioPlayback.Stop;
                AudioPlayback.PlaySound(SoundLib.Back);

                FadeTo(@ScreenMain);
              end;

            end;
          end
          //When in party Mode then Ask before Close
          else if (Mode = smPartyMode) then
          begin
            AudioPlayback.PlaySound(SoundLib.Back);
            CheckFadeTo(@ScreenMain,'MSG_END_PARTY');
          end;
        end;
      SDLK_RETURN:
        begin
          if Songs.SongList.Count > 0 then
          begin
            {$IFDEF UseSerialPort}
              // PortWriteB($378, 0);
            {$ENDIF}
            if CatSongs.Song[Interaction].Main then
            begin // clicked on Category Button
              //Show Cat in Top Left Mod
              ShowCatTL (Interaction);

              //I := CatSongs.VisibleIndex(Interaction);
              CatSongs.ClickCategoryButton(Interaction);
              {I2 := CatSongs.VisibleIndex(Interaction);
              SongCurrent := SongCurrent - I + I2;
              SongTarget := SongTarget - I + I2; }

              //  SetScroll4;

              //Show Wrong Song when Tabs on Fix
              SelectNext;
              FixSelected;

              //Play Music:
              ChangeMusic;
            end
            else
            begin // clicked on song
              if (Mode = smNormal) then //Normal Mode -> Start Song
              begin
                //Do the Action that is specified in Ini
                case Ini.OnSongClick of
                  0: StartSong;
                  1: SelectPlayers;
                  2:begin
                      if (CatSongs.CatNumShow = -3) then
                        ScreenSongMenu.MenuShow(SM_Playlist)
                      else
                        ScreenSongMenu.MenuShow(SM_Main);
                    end;
                end;
              end
              else if (Mode = smPartyMode) then //PartyMode -> Show Menu
              begin
                if (Ini.PartyPopup = 1) then
                  ScreenSongMenu.MenuShow(SM_Party_Main)
                else
                  ScreenSong.StartSong;
              end;
            end;
          end;
        end;

      SDLK_DOWN:
        begin
          if (Mode = smNormal) then
          begin
            //Only Change Cat when not in Playlist or Search Mode
            if (CatSongs.CatNumShow > -2) then
            begin
              //Cat Change Hack
              if Ini.Tabs_at_startup = 1 then
              begin
                I := Interaction;
                if I <= 0 then I := 1;

                while not catsongs.Song[I].Main do
                begin
                  Inc (I);
                  if (I > high(catsongs.Song)) then
                    I := low(catsongs.Song);
                end;

                Interaction := I;

                //Show Cat in Top Left Mod
                ShowCatTL (Interaction);

                CatSongs.ClickCategoryButton(Interaction);
                SelectNext;
                FixSelected;

                //Play Music:
                AudioPlayback.PlaySound(SoundLib.Change);
                ChangeMusic;

              end;

            //
            //Cat Change Hack End}
            end;
          end;
        end;
      SDLK_UP:
        begin
          if (Mode = smNormal) then
          begin
            //Only Change Cat when not in Playlist or Search Mode
            if (CatSongs.CatNumShow > -2) then
            begin
              //Cat Change Hack
              if Ini.Tabs_at_startup = 1 then
              begin
                I := Interaction;
                I2 := 0;
                if I <= 0 then I := 1;

                while not catsongs.Song[I].Main or (I2 = 0) do
                begin
                  if catsongs.Song[I].Main then
                    Inc(I2);
                  Dec (I);
                  if (I < low(catsongs.Song)) then
                    I := high(catsongs.Song);
                end;

                Interaction := I;

                //Show Cat in Top Left Mod
                ShowCatTL (I);

                CatSongs.ClickCategoryButton(I);
                SelectNext;
                FixSelected;

                //Play Music:
                AudioPlayback.PlaySound(SoundLib.Change);
                ChangeMusic;
              end;
            end;
            //Cat Change Hack End}
          end;
        end;

      SDLK_RIGHT:
        begin
          if (Songs.SongList.Count > 0) and (Mode = smNormal) then
          begin
            AudioPlayback.PlaySound(SoundLib.Change);
            SelectNext;
            //InteractNext;
            //SongTarget := Interaction;
            ChangeMusic;
            SetScroll4;
            //UpdateLCD;   //TODO: maybe LCD Support as Plugin?
            //Light.LightOne(1, 200); //TODO: maybe Light Support as Plugin?
          end;
        end;

      SDLK_LEFT:
        begin
          if (Songs.SongList.Count > 0)and (Mode = smNormal)  then
          begin
            AudioPlayback.PlaySound(SoundLib.Change);
            SelectPrev;
            ChangeMusic;
            SetScroll4;
            //UpdateLCD; //TODO: maybe LCD Support as Plugin?
            //Light.LightOne(0, 200); //TODO: maybe Light Support as Plugin?
          end;
        end;

      SDLK_1:
        begin //Joker // to-do : Party
          {if (Mode = smPartyMode) and (PartySession.Teams.NumTeams >= 1) and (PartySession.Teams.Teaminfo[0].Joker > 0) then
          begin
            //Use Joker
            Dec(PartySession.Teams.Teaminfo[0].Joker);
            SelectRandomSong;
            SetJoker;
          end;  }
        end;

      SDLK_2:
        begin //Joker
          {if (Mode = smPartyMode) and (PartySession.Teams.NumTeams >= 2) and (PartySession.Teams.Teaminfo[1].Joker > 0) then
          begin
            //Use Joker
            Dec(PartySession.Teams.Teaminfo[1].Joker);
            SelectRandomSong;
            SetJoker;
          end;  }
        end;

      SDLK_3:
        begin //Joker
          {if (Mode = smPartyMode) and (PartySession.Teams.NumTeams >= 3) and (PartySession.Teams.Teaminfo[2].Joker > 0) then
          begin
            //Use Joker
            Dec(PartySession.Teams.Teaminfo[2].Joker);
            SelectRandomSong;
            SetJoker;
          end; }
        end;
    end;
  end;
end;

constructor TScreenSong.Create;
var
  i: integer;
begin
  inherited Create;

  LoadFromTheme(Theme.Song);

  TextArtist := AddText(Theme.Song.TextArtist);
  TextTitle :=  AddText(Theme.Song.TextTitle);
  TextNumber := AddText(Theme.Song.TextNumber);

  //Show Cat in Top Left mod
  TextCat := AddText(Theme.Song.TextCat);
  StaticCat :=  AddStatic(Theme.Song.StaticCat);

  //Show Video Icon Mod
  VideoIcon := AddStatic(Theme.Song.VideoIcon);

  //Party Mode
  StaticTeam1Joker1 := AddStatic(Theme.Song.StaticTeam1Joker1);
  StaticTeam1Joker2 := AddStatic(Theme.Song.StaticTeam1Joker2);
  StaticTeam1Joker3 := AddStatic(Theme.Song.StaticTeam1Joker3);
  StaticTeam1Joker4 := AddStatic(Theme.Song.StaticTeam1Joker4);
  StaticTeam1Joker5 := AddStatic(Theme.Song.StaticTeam1Joker5);

  StaticTeam2Joker1 := AddStatic(Theme.Song.StaticTeam2Joker1);
  StaticTeam2Joker2 := AddStatic(Theme.Song.StaticTeam2Joker2);
  StaticTeam2Joker3 := AddStatic(Theme.Song.StaticTeam2Joker3);
  StaticTeam2Joker4 := AddStatic(Theme.Song.StaticTeam2Joker4);
  StaticTeam2Joker5 := AddStatic(Theme.Song.StaticTeam2Joker5);

  StaticTeam3Joker1 := AddStatic(Theme.Song.StaticTeam3Joker1);
  StaticTeam3Joker2 := AddStatic(Theme.Song.StaticTeam3Joker2);
  StaticTeam3Joker3 := AddStatic(Theme.Song.StaticTeam3Joker3);
  StaticTeam3Joker4 := AddStatic(Theme.Song.StaticTeam3Joker4);
  StaticTeam3Joker5 := AddStatic(Theme.Song.StaticTeam3Joker5);

  //Load Party or NonParty specific Statics and Texts
  SetLength(StaticParty, Length(Theme.Song.StaticParty));
  for i := 0 to High(Theme.Song.StaticParty) do
    StaticParty[i] := AddStatic(Theme.Song.StaticParty[i]);

  SetLength(TextParty, Length(Theme.Song.TextParty));
  for i := 0 to High(Theme.Song.TextParty) do
    TextParty[i] := AddText(Theme.Song.TextParty[i]);

  SetLength(StaticNonParty, Length(Theme.Song.StaticNonParty));
  for i := 0 to High(Theme.Song.StaticNonParty) do
    StaticNonParty[i] := AddStatic(Theme.Song.StaticNonParty[i]);

  SetLength(TextNonParty, Length(Theme.Song.TextNonParty));
  for i := 0 to High(Theme.Song.TextNonParty) do
    TextNonParty[i] := AddText(Theme.Song.TextNonParty[i]);

  // Song List
  //Songs.LoadSongList; // moved to the UltraStar unit
  CatSongs.Refresh;

  GenerateThumbnails();


  // Randomize Patch
  Randomize;
  //Equalizer
  SetLength(EqualizerBands, Theme.Song.Equalizer.Bands);
  //ClearArray
  For I := low(EqualizerBands) to high(EqualizerBands) do
    EqualizerBands[I] := 3;

  if (Length(CatSongs.Song) > 0) then
    Interaction := 0;
end;

procedure TScreenSong.GenerateThumbnails();
var
  I  : Integer;
  Pet: integer;  
Label CreateSongButtons;  
begin
  if (length(CatSongs.Song) > 0) then
  begin
    //Set Length of Button Array one Time Instead of one time for every Song
    SetButtonLength(Length(CatSongs.Song));

    I := 0;
    CreateSongButtons:

    try
      for Pet := I to High(CatSongs.Song) do begin // creating all buttons
        // new
        Texture.Limit := 512;// 256 0.4.2 value, 512 in 0.5.0

        if not FileExists(CatSongs.Song[Pet].Path + CatSongs.Song[Pet].Cover) then
          CatSongs.Song[Pet].Cover := ''; // 0.5.0: if cover not found then show 'no cover'

        if CatSongs.Song[Pet].Cover = '' then
          AddButton(300 + Pet*250, 140, 200, 200, Skin.GetTextureFileName('SongCover'), TEXTURE_TYPE_PLAIN, Theme.Song.Cover.Reflections)
        else begin
          // cache texture if there is a need to this
          if not Covers.CoverExists(CatSongs.Song[Pet].Path + CatSongs.Song[Pet].Cover) then
          begin
            Texture.CreateCacheMipmap := true;
            Texture.GetTexture(CatSongs.Song[Pet].Path + CatSongs.Song[Pet].Cover, TEXTURE_TYPE_PLAIN, true); // preloads textures and creates cache mipmap
            Texture.CreateCacheMipmap := false;

            // puts this texture to the cache file
            Covers.AddCover(CatSongs.Song[Pet].Path + CatSongs.Song[Pet].Cover);

            // unload full size texture
            Texture.UnloadTexture(CatSongs.Song[Pet].Path + CatSongs.Song[Pet].Cover, TEXTURE_TYPE_PLAIN, false);

            // we should also add mipmap texture by calling createtexture and use mipmap cache as data source
          end;

          // and now load it from cache file (small place for the optimization by eliminating reading it from file, but not here)
          AddButton(300 + Pet*250, 140, 200, 200, CatSongs.Song[Pet].Path + CatSongs.Song[Pet].Cover, TEXTURE_TYPE_PLAIN, Theme.Song.Cover.Reflections);
        end;
        Texture.Limit := 1024*1024;
        I := -1;
      end;
    except
      //When Error is reported the First time for this Song
      if (I <> Pet) then
      begin
        //Some Error reporting:
        Log.LogError('Could not load Cover: ' + CatSongs.Song[Pet].Cover);

        //Change Cover to NoCover and Continue Loading
        CatSongs.Song[Pet].Cover := '';
        I := Pet;
      end
      else //when Error occurs Multiple Times(NoSong Cover is damaged), then start loading next Song
      begin
        Log.LogError('NoCover Cover is damaged!');
        try
          AddButton(300 + Pet*250, 140, 200, 200, '', TEXTURE_TYPE_PLAIN, Theme.Song.Cover.Reflections);
        except
          ShowMessage('"No Cover" image is damaged. Ultrastar will exit now.');

          Halt;
        end;
        I := Pet + 1;
      end;
    end;

    if (I <> -1) then
      GoTo CreateSongButtons;

  end;
end;

procedure TScreenSong.SetScroll;
var
  VS, B: Integer;
begin
  VS := CatSongs.VisibleSongs;
  if VS > 0 then
  begin
    //Set Positions
    Case Theme.Song.Cover.Style of
      3: SetScroll3;
      5:begin
          if VS > 5 then
            SetScroll5
          else
            SetScroll4;
        end;
      6: SetScroll6;
      else SetScroll4;
    end;
    //Set Visibility of Video Icon
    Static[VideoIcon].Visible := (CatSongs.Song[Interaction].Video <> '');

    //Set Texts:
    Text[TextArtist].Text := CatSongs.Song[Interaction].Artist;
    Text[TextTitle].Text  :=  CatSongs.Song[Interaction].Title;
    if (Ini.Tabs_at_startup = 1) And (CatSongs.CatNumShow = -1) then
    begin
      Text[TextNumber].Text := IntToStr(CatSongs.Song[Interaction].OrderNum) + '/' + IntToStr(CatSongs.CatCount);
      Text[TextTitle].Text  := '(' + IntToStr(CatSongs.Song[Interaction].CatNumber) + ' ' + Language.Translate('SING_SONGS_IN_CAT') + ')';
    end
    else if (CatSongs.CatNumShow = -2) then
      Text[TextNumber].Text := IntToStr(CatSongs.VisibleIndex(Interaction)+1) + '/' + IntToStr(VS)
    else if (CatSongs.CatNumShow = -3) then
      Text[TextNumber].Text := IntToStr(CatSongs.VisibleIndex(Interaction)+1) + '/' + IntToStr(VS)
    else if (Ini.Tabs_at_startup = 1) then
      Text[TextNumber].Text := IntToStr(CatSongs.Song[Interaction].CatNumber) + '/' + IntToStr(CatSongs.Song[Interaction - CatSongs.Song[Interaction].CatNumber].CatNumber)
    else
      Text[TextNumber].Text := IntToStr(Interaction+1) + '/' + IntToStr(Length(CatSongs.Song));
  end
  else
  begin
    Text[TextNumber].Text := '0/0';
    Text[TextArtist].Text := '';
    Text[TextTitle].Text  := '';
    for B := 0 to High(Button) do
      Button[B].Visible := False;

  end;
end;

procedure TScreenSong.SetScroll1;
var
  B:      integer;    // button
  //BMin:   integer;    // button min // Auto Removed, Unused Variable
  //BMax:   integer;    // button max // Auto Removed, Unused Variable
  Src:    integer;
  //Dst:    integer;
  Count:  integer;    // Dst is not used. Count is used.
  Ready:  boolean;

  VisCount: integer;  // count of visible (or selectable) buttons
  VisInt:   integer;  // visible position of interacted button
  Typ:      integer;  // 0 when all songs fits the screen
  Placed:   integer;  // number of placed visible buttons
begin
  //Src := 0;
  //Dst := -1;
  Count := 1;
  Typ := 0;
  Ready := false;
  Placed := 0;

  VisCount := 0;
  for B := 0 to High(Button) do
    if CatSongs.Song[B].Visible then Inc(VisCount);

  VisInt := 0;
  for B := 0 to Interaction-1 do
    if CatSongs.Song[B].Visible then Inc(VisInt);


  if VisCount <= 6 then begin
    Typ := 0;
  end else begin
    if VisInt <= 3 then begin
      Typ := 1;
      Count := 7;
      Ready := true;
    end;

    if (VisCount - VisInt) <= 3 then begin
      Typ := 2;
      Count := 7;
      Ready := true;
    end;

    if not Ready then begin
      Typ := 3;
      Src := Interaction;
    end;
  end;



  // hide all buttons
  for B := 0 to High(Button) do begin
    Button[B].Visible := false;
    Button[B].Selectable := CatSongs.Song[B].Visible;
  end;

  {
  for B := Src to Dst do begin
    //Button[B].Visible := true;
    Button[B].Visible := CatSongs.Song[B].Visible;
    Button[B].Selectable := Button[B].Visible;
    Button[B].Y := 140 + (B-Src) * 60;
  end;
  }


  if Typ = 0 then begin
    for B := 0 to High(Button) do begin
      if CatSongs.Song[B].Visible then begin
        Button[B].Visible := true;
        Button[B].Y := 140 + (Placed) * 60;
        Inc(Placed);
      end;
    end;
  end;

  if Typ = 1 then begin
    B := 0;
    while (Count > 0) do begin
      if CatSongs.Song[B].Visible then begin
        Button[B].Visible := true;
        Button[B].Y := 140 + (Placed) * 60;
        Inc(Placed);
        Dec(Count);
      end;
      Inc(B);
    end;
  end;

  if Typ = 2 then begin
    B := High(Button);
    while (Count > 0) do begin
      if CatSongs.Song[B].Visible then begin
        Button[B].Visible := true;
        Button[B].Y := 140 + (6-Placed) * 60;
        Inc(Placed);
        Dec(Count);
      end;
      Dec(B);
    end;
  end;

  if Typ = 3 then begin
    B := Src;
    Count := 4;
    while (Count > 0) do begin
      if CatSongs.Song[B].Visible then begin
        Button[B].Visible := true;
        Button[B].Y := 140 + (3+Placed) * 60;
        Inc(Placed);
        Dec(Count);
      end;
      Inc(B);
    end;

    B := Src-1;
    Placed := 0;
    Count := 3;
    while (Count > 0) do begin
      if CatSongs.Song[B].Visible then begin
        Button[B].Visible := true;
        Button[B].Y := 140 + (2-Placed) * 60;
        Inc(Placed);
        Dec(Count);
      end;
      Dec(B);
    end;

  end;

  if Length(Button) > 0 then
    Static[1].Texture.Y := Button[Interaction].Y - 5; // selection texture
end;

procedure TScreenSong.SetScroll2;
var
  B:      integer;
  //Wsp:    integer; // wspolczynnik przesuniecia wzgledem srodka ekranu 
  //Wsp2:   real;
begin
  // liniowe
  for B := 0 to High(Button) do
    Button[B].X := 300 + (B - Interaction) * 260;

  if Length(Button) >= 3 then begin
    if Interaction = 0 then
      Button[High(Button)].X := 300 - 260;

    if Interaction = High(Button) then
      Button[0].X := 300 + 260;
  end;

  // kolowe
  {
  for B := 0 to High(Button) do begin
    Wsp := (B - Interaction); // 0 dla srodka, -1 dla lewego, +1 dla prawego itd.
    Wsp2 := Wsp / Length(Button);
    Button[B].X := 300 + 10000 * sin(2*pi*Wsp2);
    //Button[B].Y := 140 + 50 * ;
  end;
  }
end;

procedure TScreenSong.SetScroll3; // with slide
var
  B:      integer;
  //Wsp:    integer; // wspolczynnik przesuniecia wzgledem srodka ekranu
  //Wsp2:   real;
begin
  SongTarget := Interaction;

  // liniowe
  for B := 0 to High(Button) do
  begin
    Button[B].X := 300 + (B - SongCurrent) * 260;
    if (Button[B].X < -Button[B].W) OR (Button[B].X > 800) then
      Button[B].Visible := False
    else
      Button[B].Visible := True;
  end;

  {
  if Length(Button) >= 3 then begin
    if Interaction = 0 then
      Button[High(Button)].X := 300 - 260;

    if Interaction = High(Button) then
      Button[0].X := 300 + 260;
  end;
  }

  // kolowe
  {
  for B := 0 to High(Button) do begin
    Wsp := (B - Interaction); // 0 dla srodka, -1 dla lewego, +1 dla prawego itd.
    Wsp2 := Wsp / Length(Button);
    Button[B].X := 300 + 10000 * sin(2*pi*Wsp2);
    //Button[B].Y := 140 + 50 * ;
  end;
  }
end;

procedure TScreenSong.SetScroll4; // rotate
var
  B:      integer;
  Wsp:    real;
  Z, Z2:      real;
  VS:     integer;
begin
  VS := CatSongs.VisibleSongs; // 0.5.0 (I): cached, very important

  // kolowe
  for B := 0 to High(Button) do begin
    Button[B].Visible := CatSongs.Song[B].Visible; // nowe
    if Button[B].Visible then begin // 0.5.0 optimization for 1000 songs - updates only visible songs, hiding in tabs becomes useful for maintaing good speed

    Wsp := 2 * pi * (CatSongs.VisibleIndex(B) - SongCurrent) /  VS {CatSongs.VisibleSongs};// 0.5.0 (II): takes another 16ms

    Z := (1 + cos(Wsp)) / 2;
    Z2 := (1 + 2*Z) / 3;


    Button[B].X := Theme.Song.Cover.X + (0.185 * Theme.Song.Cover.H * VS * sin(Wsp)) * Z2 - ((Button[B].H - Theme.Song.Cover.H)/2); // 0.5.0 (I): 2 times faster by not calling CatSongs.VisibleSongs
    Button[B].Z := Z / 2 + 0.3;

    Button[B].W := Theme.Song.Cover.H * Z2;

    //Button[B].Y := {50 +} 140 + 50 - 50 * Z2;
    Button[B].Y := Theme.Song.Cover.Y  + (Theme.Song.Cover.H - Abs(Button[B].H)) * 0.7 ;
    Button[B].H := Button[B].W;
    end;
  end;
end;

(*
procedure TScreenSong.SetScroll4; // rotate
var
  B:      integer;
  Wsp:    real;
  Z:      real;
  Z2, Z3:     real;
  VS:     integer;
  function modreal (const X, Y: real):real;
  begin
    Result := Frac(x / y) * y;
    if Result < -3 then
      Result := Result + Y
    else if Result > 3 then
      Result := Result - Y;
  end;
begin
  VS := CatSongs.VisibleSongs; // 0.5.0 (I): cached, very important
  Z3 := 1;
  if VS < 12 then
    Z2 := VS
  else
    Z2 := 12;

  // kolowe
  for B := 0 to High(Button) do begin
    Button[B].Visible := CatSongs.Song[B].Visible; // nowe
    if Button[B].Visible then begin // 0.5.0 optimization for 1000 songs - updates only visible songs, hiding in tabs becomes useful for maintaing good speed
      if ((ModReal(CatSongs.VisibleIndex(B) - SongCurrent, VS)>-3) and (ModReal(CatSongs.VisibleIndex(B) - SongCurrent, VS)<3)) then
      begin
        if CatSongs.VisibleIndex(B)> SongCurrent then
          Wsp := 2 * pi * (CatSongs.VisibleIndex(B) - SongCurrent) /  Z2
        else
          Wsp := 2 * pi * (CatSongs.VisibleIndex(B) - SongCurrent) /  Z2;

        Z3 := 2;
        Z := (1 + cos(Wsp)) / 2;
        //Z2 := (1 + 2*Z) / 3;
        //Z2 := (0.5 + Z/2);
        //Z2 := sin(Wsp);

        //Z2 := Power (Z2,Z3);

        Button[B].W := Theme.Song.CoverW * Power(cos(Wsp), Z3);//Power(Z2, 3);

        //Button[B].X := Theme.Song.CoverX + ({Theme.Song.CoverX + Theme.Song.CoverW/2 + Theme.Song.CoverW*0.18 * VS {CatSongs.VisibleSongs {Length(Button) * sin(Wsp) {- Theme.Song.CoverX - Theme.Song.CoverW) * Z2; // 0.5.0 (I): 2 times faster by not calling CatSongs.VisibleSongs
        if (sin(Wsp)<0) then
          Button[B].X := sin(Wsp)*Theme.Song.CoverX*Theme.Song.CoverW*0.007 + Theme.Song.CoverX + Theme.Song.CoverW - Button[B].W
        else //*Theme.Song.CoverW*0.004*Z3
          Button[B].X := sin(Wsp)*Theme.Song.CoverX*Theme.Song.CoverW*0.007 + Theme.Song.CoverX;
        Button[B].Z := Z-0.00001;

        //Button[B].Y := {50 + 140 + 50 - 50 * Z2;
        //Button[B].Y := (Theme.Song.CoverY  + 40 + 50 - 50 * Z2);
        Button[B].Y := (Theme.Song.CoverY  + Theme.Song.CoverW - Button[B].W);
        Button[B].H := Button[B].W;
        Button[B].Visible := True;
      end
      {else if (((CatSongs.VisibleIndex(B) - SongCurrent)>-3) and ((CatSongs.VisibleIndex(B) - SongCurrent)<3)) OR ((round (CatSongs.VisibleIndex(B) - SongCurrent) mod VS > -3) and ((CatSongs.VisibleIndex(B) - SongCurrent)<3)) then
      begin
        Wsp := 2 * pi * (CatSongs.VisibleIndex(B) - SongCurrent) /  12 ;// 0.5.0 (II): takes another 16ms

        Z := (1 + cos(Wsp)) / 2 -0.00001; //z < 0.49999 is behind the cover 1 is in front of the covers

        Button[B].W := Theme.Song.CoverW * Power(cos(Wsp), Z3);//Power(Z2, 3);

        if (sin(Wsp)<0) then
          Button[B].X := sin(Wsp)*Theme.Song.CoverX*Theme.Song.CoverW*0.007 + Theme.Song.CoverX + Theme.Song.CoverW - Button[B].W
        else
          Button[B].X := sin(Wsp)*Theme.Song.CoverX*Theme.Song.CoverW*0.007 + Theme.Song.CoverX;

        Button[B].Z := Z;

        Button[B].Y := (Theme.Song.CoverY  + Theme.Song.CoverW - Button[B].W);

        Button[B].H := Button[B].W;
        Button[B].Visible := True;
      end
      else Button[B].Visible := False;
    end;
  end;
end;      *)

procedure TScreenSong.SetScroll5; // rotate
var
  B:      integer;
  Angle:    real;
  Pos:    Real;
  VS:     integer;
  diff:     real;
  X:        Real;
  helper: real;
begin
  VS := CatSongs.VisibleSongs; // cache Visible Songs
  {
  //Vars
  Theme.Song.CoverW: Radius des Kreises
  Theme.Song.CoverX: X Pos Linke Kante des gew�hlten Covers
  Theme.Song.CoverX: Y Pos Obere Kante des gew�hlten Covers
  Theme.Song.CoverH: H�he der Cover

  (CatSongs.VisibleIndex(B) - SongCurrent)/VS = Distance to middle Cover in %
  }

  //Change Pos of all Buttons
  for B := low(Button) to high(Button) do
  begin
    Button[B].Visible := CatSongs.Song[B].Visible; //Adjust Visibility
    if Button[B].Visible then //Only Change Pos for Visible Buttons
    begin
      Pos := (CatSongs.VisibleIndex(B) - SongCurrent);
      if (Pos < -VS/2) then
        Pos := Pos + VS
      else if (Pos > VS/2) then
        Pos := Pos - VS;

      if (Abs(Pos) < 2.5) then {fixed Positions}
      begin
      Angle := Pi * (Pos / 5);
      //Button[B].Visible := False;

      Button[B].H := Abs(Theme.Song.Cover.H * cos(Angle*0.8));//Power(Z2, 3);

      //Button[B].Reflectionspacing := 15 * Button[B].H/Theme.Song.Cover.H;
      Button[B].DeSelectReflectionspacing := 15 * Button[B].H/Theme.Song.Cover.H;

      Button[B].Z := 0.95 - Abs(Pos) * 0.01;

      Button[B].Y := (Theme.Song.Cover.Y  + (Theme.Song.Cover.H - Abs(Theme.Song.Cover.H * cos(Angle))) * 0.5);

      Button[B].W := Button[B].H;

      Diff := (Button[B].H - Theme.Song.Cover.H)/2;


      X := Sin(Angle*1.3)*0.9;

      Button[B].X := Theme.Song.Cover.X + Theme.Song.Cover.W * X - Diff;

      end
      else
      begin {Behind the Front Covers}

        // limit-bg-covers hack
        if (abs(abs(Pos)-VS/2)>10) then Button[B].Visible:=False;
        // end of limit-bg-covers hack

        if Pos < 0 then
          Pos := (Pos - VS/2)/VS
        else
          Pos := (Pos + VS/2)/VS;

        Angle := pi * Pos*2;
        if VS > 24 then
        begin
          if Angle < 0 then helper:=-1 else helper:=1;
          Angle:=2*pi-abs(Angle);
          Angle:=Angle*(VS/24);
          Angle:=(2*pi-Angle)*helper;
        end;

        Button[B].Z := (0.4 - Abs(Pos/4)) -0.00001; //z < 0.49999 is behind the cover 1 is in front of the covers

        Button[B].H :=0.6*(Theme.Song.Cover.H-Abs(Theme.Song.Cover.H * cos(Angle/2)*0.8));//Power(Z2, 3);

        Button[B].W := Button[B].H;

        Button[B].Y := Theme.Song.Cover.Y  - (Button[B].H - Theme.Song.Cover.H)*0.75;

        //Button[B].Reflectionspacing := 15 * Button[B].H/Theme.Song.Cover.H;
        Button[B].DeSelectReflectionspacing := 15 * Button[B].H/Theme.Song.Cover.H;

        Diff := (Button[B].H - Theme.Song.Cover.H)/2;

        Button[B].X :=  Theme.Song.Cover.X+Theme.Song.Cover.H/2-Button[b].H/2+Theme.Song.Cover.W/320*((Theme.Song.Cover.H)*sin(Angle/2)*1.52);

      end;

      //Button[B].Y := (Theme.Song.Cover.Y  + (Theme.Song.Cover.H - Button[B].H)/1.5); //Cover at down border of the change field
      //Button[B].Y := (Theme.Song.Cover.Y  + (Theme.Song.Cover.H - Button[B].H) * 0.7);

    end;
  end;
end;

procedure TScreenSong.SetScroll6; // rotate (slotmachine style)
var
  B:      integer;
  Angle:    real;
  Pos:    Real;
  VS:     integer;
  diff:     real;
  X:        Real;
  Wsp:    real;
  Z, Z2:      real;
begin
  VS := CatSongs.VisibleSongs; // cache Visible Songs
  if VS <=5 then begin
    // kolowe
    for B := 0 to High(Button) do
    begin
      Button[B].Visible := CatSongs.Song[B].Visible; // nowe
      if Button[B].Visible then begin // 0.5.0 optimization for 1000 songs - updates only visible songs, hiding in tabs becomes useful for maintaing good speed

      Wsp := 2 * pi * (CatSongs.VisibleIndex(B) - SongCurrent) /  VS {CatSongs.VisibleSongs};// 0.5.0 (II): takes another 16ms

      Z := (1 + cos(Wsp)) / 2;
      Z2 := (1 + 2*Z) / 3;


      Button[B].Y := Theme.Song.Cover.Y + (0.185 * Theme.Song.Cover.H * VS * sin(Wsp)) * Z2 - ((Button[B].H - Theme.Song.Cover.H)/2); // 0.5.0 (I): 2 times faster by not calling CatSongs.VisibleSongs
      Button[B].Z := Z / 2 + 0.3;

      Button[B].W := Theme.Song.Cover.H * Z2;

      //Button[B].Y := {50 +} 140 + 50 - 50 * Z2;
      Button[B].X := Theme.Song.Cover.X  + (Theme.Song.Cover.H - Abs(Button[B].H)) * 0.7 ;
      Button[B].H := Button[B].W;
      end;
    end;
  end
  else begin

    //Change Pos of all Buttons
    for B := low(Button) to high(Button) do
      begin
          Button[B].Visible := CatSongs.Song[B].Visible; //Adjust Visibility
      if Button[B].Visible then //Only Change Pos for Visible Buttons
        begin
        Pos := (CatSongs.VisibleIndex(B) - SongCurrent);
        if (Pos < -VS/2) then
          Pos := Pos + VS
        else if (Pos > VS/2) then
          Pos := Pos - VS;

        if (Abs(Pos) < 2.5) then {fixed Positions}
        begin
          Angle := Pi * (Pos / 5);
          //Button[B].Visible := False;

          Button[B].H := Abs(Theme.Song.Cover.H * cos(Angle*0.8));//Power(Z2, 3);

          Button[B].DeSelectReflectionspacing := 15 * Button[B].H/Theme.Song.Cover.H;

          Button[B].Z := 0.95 - Abs(Pos) * 0.01;

          Button[B].X := (Theme.Song.Cover.X  + (Theme.Song.Cover.H - Abs(Theme.Song.Cover.H * cos(Angle))) * 0.5);

          Button[B].W := Button[B].H;

          Diff := (Button[B].H - Theme.Song.Cover.H)/2;


          X := Sin(Angle*1.3)*0.9;

          Button[B].Y := Theme.Song.Cover.Y + Theme.Song.Cover.W * X - Diff;
        end
        else
        begin {Behind the Front Covers}

          // limit-bg-covers hack
          if (abs(VS/2-abs(Pos))>10) then Button[B].Visible:=False;
          if VS > 25 then VS:=25;
          // end of limit-bg-covers hack

          if Pos < 0 then
            Pos := (Pos - VS/2)/VS
          else
            Pos := (Pos + VS/2)/VS;

          Angle := Pi * Pos*2;

          Button[B].Z := (0.4 - Abs(Pos/4)) -0.00001; //z < 0.49999 is behind the cover 1 is in front of the covers

          Button[B].H :=0.6*(Theme.Song.Cover.H-Abs(Theme.Song.Cover.H * cos(Angle/2)*0.8));//Power(Z2, 3);

          Button[B].W := Button[B].H;

          Button[B].X := Theme.Song.Cover.X  - (Button[B].H - Theme.Song.Cover.H)*0.5;


          Button[B].DeSelectReflectionspacing := 15 * Button[B].H/Theme.Song.Cover.H;

          Button[B].Y := Theme.Song.Cover.Y+Theme.Song.Cover.H/2-Button[b].H/2+Theme.Song.Cover.W/320*(Theme.Song.Cover.H*sin(Angle/2)*1.52);
        end;
      end;
    end;
  end;
end;


procedure TScreenSong.onShow;
begin
  inherited;

  AudioPlayback.Stop;

  if Ini.Players <= 3 then PlayersPlay := Ini.Players + 1;
  if Ini.Players  = 4 then PlayersPlay := 6;

  //Cat Mod etc
  if (Ini.Tabs_at_startup = 1) and (CatSongs.CatNumShow = -1) then
  begin
    CatSongs.ShowCategoryList;
    FixSelected;
    //Show Cat in Top Left Mod
    HideCatTL;
  end;

  if Length(CatSongs.Song) > 0 then
  begin
    //Load Music only when Song Preview is activated
    if ( Ini.PreviewVolume   <> 0 ) then
    begin                                            // to - do : new Song management
      StartMusicPreview(CatSongs.Song[Interaction]);
    end;

    SetScroll;
    //UpdateLCD;  //TODO: maybe LCD Support as Plugin?
  end;

  //Playlist Mode
  if (Mode = smNormal) then
  begin
    //If Playlist Shown -> Select Next automatically
    if (CatSongs.CatNumShow = -3) then
    begin
      SelectNext;
      ChangeMusic;
    end;
  end
  //Party Mode
  else if (Mode = smPartyMode) then
  begin
    SelectRandomSong;
    //Show Menu directly in PartyMode
    //But only if selected in Options
    if (Ini.PartyPopup = 1) then
    begin
      ScreenSongMenu.MenuShow(SM_Party_Main);
    end;
  end;

  SetJoker;
  SetStatics;
end;

procedure TScreenSong.onHide;
begin
  // if music fading is activated, turn music to 100%
  If (IPreviewVolumeVals[Ini.PreviewVolume] <> 1.0) or (Ini.PreviewFading <> 0) then
    AudioPlayback.SetVolume(1.0);

  // if preview is deactivated: load musicfile now
  If (IPreviewVolumeVals[Ini.PreviewVolume] = 0) then
    AudioPlayback.Open(CatSongs.Song[Interaction].Path + CatSongs.Song[Interaction].Mp3);

  // if hide then stop music (for party mode popup on exit)
  if (Display.NextScreen <> @ScreenSing) and
     (Display.NextScreen <> @ScreenSingModi) then
  begin
    if (AudioPlayback <> nil) then
      AudioPlayback.Stop;
  end;
end;

procedure TScreenSong.DrawExtensions;
begin
  //Draw Song Menu
  if (ScreenSongMenu.Visible) then
  begin
    ScreenSongMenu.Draw;
  end
  else if (ScreenSongJumpto.Visible) then
  begin
    ScreenSongJumpto.Draw;
  end
end;

function TScreenSong.Draw: boolean;
var
  dx:   real;
  dt:   real;
  I:    Integer;
begin
  dx := SongTarget-SongCurrent;
  dt := TimeSkip * 7;

  if dt > 1 then
    dt := 1;
    
  SongCurrent := SongCurrent + dx*dt;

  {
  if SongCurrent > Catsongs.VisibleSongs then begin
    SongCurrent := SongCurrent - Catsongs.VisibleSongs;
    SongTarget := SongTarget - Catsongs.VisibleSongs;
  end;
  }

  //Log.BenchmarkStart(5);

  SetScroll;

  //Log.BenchmarkEnd(5);
  //Log.LogBenchmark('SetScroll4', 5);

  //Fading Functions, Only if Covertime is under 5 Seconds
  if (CoverTime < 5) then
  begin
    // cover fade
    if (CoverTime < 1) and (CoverTime + TimeSkip >= 1) then
    begin
      // load new texture
      Texture.GetTexture(Button[Interaction].Texture.Name, TEXTURE_TYPE_PLAIN, false);
      Button[Interaction].Texture.Alpha := 1;
      Button[Interaction].Texture2 := Texture.GetTexture(Button[Interaction].Texture.Name, TEXTURE_TYPE_PLAIN, false);
      Button[Interaction].Texture2.Alpha := 1;
    end;

    //Song Fade
    if (CatSongs.VisibleSongs > 0) and
       (not CatSongs.Song[Interaction].Main) and
       (Ini.PreviewVolume <> 0) and
       (Ini.PreviewFading <> 0) then
    begin
      //Start Song Fade after a little Time, to prevent Song to be Played on Scrolling
      if ((MusicStartTime > 0) and (SDL_GetTicks() >= MusicStartTime)) then
      begin
        MusicStartTime := 0;
        StartMusicPreview(CatSongs.Song[Interaction]);
      end;
    end;


    //Update Fading Time
    CoverTime := CoverTime + TimeSkip;

    //Update Fading Texture
    Button[Interaction].Texture2.Alpha := (CoverTime - 1) * 1.5;
    if Button[Interaction].Texture2.Alpha > 1 then
      Button[Interaction].Texture2.Alpha := 1;

  end;

  //inherited Draw;
  //heres a little Hack, that causes the Statics
  //are Drawn after the Buttons because of some Blending Problems.
  //This should cause no Problems because all Buttons on this screen
  //Has Z Position.
  //Draw BG
  DrawBG;

  //Instead of Draw FG Procedure:
  //We draw Buttons for our own
  for I := 0 to Length(Button) - 1 do
    Button[I].Draw;

  // Statics
  for I := 0 to Length(Static) - 1 do
    Static[I].Draw;

  // and texts
  for I := 0 to Length(Text) - 1 do
    Text[I].Draw;


  //Draw Equalizer
  if Theme.Song.Equalizer.Visible then
    DrawEqualizer;

  DrawExtensions;

  Result := true;
end;

procedure TScreenSong.SelectNext;
var
  Skip:   integer;
  VS:     Integer;
begin
  VS := CatSongs.VisibleSongs;

  if VS > 0 then
  begin
    UnLoadDetailedCover;

    Skip := 1;

    // this 1 could be changed by CatSongs.FindNextVisible
    while (not CatSongs.Song[(Interaction + Skip) mod Length(Interactions)].Visible) do
      Inc(Skip);

    SongTarget := SongTarget + 1;//Skip;

    Interaction := (Interaction + Skip) mod Length(Interactions);

    // try to keep all at the beginning
    if SongTarget > VS-1 then begin
      SongTarget := SongTarget - VS;
      SongCurrent := SongCurrent - VS;
    end;

  end;

  // Interaction -> Button, ktorego okladke przeczytamy
  //Button[Interaction].Texture := Texture.GetTexture(Button[Interaction].Texture.Name, TEXTURE_TYPE_PLAIN, false); // 0.5.0: show uncached texture
end;

procedure TScreenSong.SelectPrev;
var
  Skip:   integer;
  VS:     Integer;
begin
  VS := CatSongs.VisibleSongs;

  if VS > 0 then
  begin
    UnLoadDetailedCover;

    Skip := 1;

    while (not CatSongs.Song[(Interaction - Skip + Length(Interactions)) mod Length(Interactions)].Visible) do Inc(Skip);
    SongTarget := SongTarget - 1;//Skip;

    Interaction := (Interaction - Skip + Length(Interactions)) mod Length(Interactions);

    // try to keep all at the beginning
    if SongTarget < 0 then begin
      SongTarget := SongTarget + CatSongs.VisibleSongs;
      SongCurrent := SongCurrent + CatSongs.VisibleSongs;
    end;

  //  Button[Interaction].Texture := Texture.GetTexture(Button[Interaction].Texture.Name, TEXTURE_TYPE_PLAIN, false); // 0.5.0: show uncached texture
  end;
end;

(*
procedure TScreenSong.UpdateLCD; //TODO: maybe LCD Support as Plugin?
begin
  LCD.HideCursor;
  LCD.Clear;
  LCD.WriteText(1, Text[TextArtist].Text);
  LCD.WriteText(2, Text[TextTitle].Text);

end;
*)

procedure TScreenSong.StartMusicPreview(Song: TSong);
begin
  AudioPlayback.Close();

  if not assigned(Song) then
    Exit;

  if AudioPlayback.Open(Song.Path + Song.Mp3) then
  begin
    AudioPlayback.Position := AudioPlayback.Length / 4;
    // set preview volume
    if (Ini.PreviewFading = 0) then
    begin
      // music fade disabled: start with full volume
      AudioPlayback.SetVolume(IPreviewVolumeVals[Ini.PreviewVolume]);
      AudioPlayback.Play()
    end
    else
    begin
      // music fade enabled: start muted and fade-in
      AudioPlayback.SetVolume(0);
      AudioPlayback.FadeIn(Ini.PreviewFading, IPreviewVolumeVals[Ini.PreviewVolume]);
    end;
  end;
end;

//Procedure Change current played Preview
procedure TScreenSong.ChangeMusic;
begin
  //When Music Preview is avtivated -> then Change Music
  if (Ini.PreviewVolume <> 0) then
    begin
    // Stop previous song
    AudioPlayback.Stop;
    // Disable music start delay
    MusicStartTime := 0;

    if (CatSongs.VisibleSongs > 0) then
    begin
      // delay start of music for 200ms (see Draw())
      MusicStartTime := SDL_GetTicks() + 200;
    end;
  end;
end;

procedure TScreenSong.SkipTo(Target: Cardinal);
var
  i:      integer;
begin
  UnLoadDetailedCover;

  Interaction := High(CatSongs.Song);
  SongTarget  := 0;

  for i := 1 to Target+1 do
    SelectNext;

  FixSelected2;
end;

procedure TScreenSong.DrawEqualizer;
var
  I, J: Integer;
  ChansPerBand: byte; // channels per band
  MaxChannel: Integer;
  CurBand: Integer; // current band
  CurTime: Cardinal;
  PosX, PosY: Integer;
  Pos: Real;
begin
  // Nothing to do if no music is played or an equalizer bar consists of no block
  if (AudioPlayback.Finished or (Theme.Song.Equalizer.Length <= 0)) then
    Exit;

  CurTime := SDL_GetTicks();

  // Evaluate FFT-data every 44 ms
  if (CurTime >= EqualizerTime) then
  begin
    EqualizerTime := CurTime + 44;
    AudioPlayback.GetFFTData(EqualizerData);

    Pos := 0;
    // use only the first approx. 92 of 256 FFT-channels (approx. up to 8kHz
    ChansPerBand := ceil(92 / Theme.Song.Equalizer.Bands); // How much channels are used for one Band
    MaxChannel := ChansPerBand * Theme.Song.Equalizer.Bands - 1;

    // Change Lengths
    for i := 0 to MaxChannel do
    begin
      // Gain higher freq. data so that the bars are visible
      if i > 35 then
        EqualizerData[i] := EqualizerData[i] * 8
      else if i > 11 then
        EqualizerData[i] := EqualizerData[i] * 4.5
      else
        EqualizerData[i] := EqualizerData[i] * 1.1;

      // clamp data
      if (EqualizerData[i] > 1) then
        EqualizerData[i] := 1;

      // Get max. pos
      if (EqualizerData[i] * Theme.Song.Equalizer.Length > Pos) then
        Pos := EqualizerData[i] * Theme.Song.Equalizer.Length;

      // Check if this is the last channel in the band
      if ((i+1) mod ChansPerBand = 0) then
      begin
        CurBand := i div ChansPerBand;

        // Smooth delay if new equalizer is lower than the old one
        if ((EqualizerBands[CurBand] > Pos) and (EqualizerBands[CurBand] > 1)) then
          EqualizerBands[CurBand] := EqualizerBands[CurBand] - 1
        else
          EqualizerBands[CurBand] := Round(Pos);

        Pos := 0;
      end;
    end;

  end;

  // Draw equalizer bands

  // Setup OpenGL
  glColor4f(Theme.Song.Equalizer.ColR, Theme.Song.Equalizer.ColG, Theme.Song.Equalizer.ColB, Theme.Song.Equalizer.Alpha);
  glDisable(GL_TEXTURE_2D);
  glEnable(GL_BLEND);

  // Set position of the first equalizer bar
  PosY := Theme.Song.Equalizer.Y;
  PosX := Theme.Song.Equalizer.X;

  // Draw bars for each band
  for I := 0 to High(EqualizerBands) do
  begin
    // Reset to lower or left position depending on the drawing-direction
    if Theme.Song.Equalizer.Direction then // Vertical bars
      // FIXME: Is Theme.Song.Equalizer.Y the upper or lower coordinate?
      PosY := Theme.Song.Equalizer.Y //+ (Theme.Song.Equalizer.H + Theme.Song.Equalizer.Space) * Theme.Song.Equalizer.Length
    else                                   // Horizontal bars
      PosX := Theme.Song.Equalizer.X;

    // Draw the bar as a stack of blocks
    for J := 1 to EqualizerBands[I] do
    begin
      // Draw block
      glBegin(GL_QUADS);
        glVertex3f(PosX, PosY, Theme.Song.Equalizer.Z);
        glVertex3f(PosX, PosY+Theme.Song.Equalizer.H, Theme.Song.Equalizer.Z);
        glVertex3f(PosX+Theme.Song.Equalizer.W, PosY+Theme.Song.Equalizer.H, Theme.Song.Equalizer.Z);
        glVertex3f(PosX+Theme.Song.Equalizer.W, PosY, Theme.Song.Equalizer.Z);
      glEnd;

      // Calc position of the bar's next block
      if Theme.Song.Equalizer.Direction then // Vertical bars
        PosY := PosY - Theme.Song.Equalizer.H - Theme.Song.Equalizer.Space
      else                                   // Horizontal bars
        PosX := PosX + Theme.Song.Equalizer.W + Theme.Song.Equalizer.Space;
    end;

    // Calc position of the next bar
    if Theme.Song.Equalizer.Direction then // Vertical bars
      PosX := PosX + Theme.Song.Equalizer.W + Theme.Song.Equalizer.Space
    else                                   // Horizontal bars
      PosY := PosY + Theme.Song.Equalizer.H + Theme.Song.Equalizer.Space;
  end;
end;

procedure TScreenSong.SelectRandomSong;
var
  I, I2: Integer;
begin
  case PlaylistMan.Mode of
      smNormal:  //All Songs Just Select Random Song
        begin
          //When Tabs are activated then use Tab Method
          if (Ini.Tabs_at_startup = 1) then
          begin
            repeat
              I2 := Random(high(CatSongs.Song)+1) - low(CatSongs.Song)+1;
            until CatSongs.Song[I2].Main = false;

            //Search Cat
            for I := I2 downto low(CatSongs.Song) do
            begin
              if CatSongs.Song[I].Main then
                break;
            end;
            //In I ist jetzt die Kategorie in I2 der Song
            //I is the CatNum, I2 is the No of the Song within this Cat

            //Choose Cat
            CatSongs.ShowCategoryList;

            //Show Cat in Top Left Mod
            ShowCatTL (I);

            CatSongs.ClickCategoryButton(I);
            SelectNext;

            //Choose Song
            SkipTo(I2-I);
          end
          //When Tabs are deactivated use easy Method
          else
            SkipTo(Random(CatSongs.VisibleSongs));
        end;
      smPartyMode:  //One Category Select Category and Select Random Song
        begin
          CatSongs.ShowCategoryList;
          CatSongs.ClickCategoryButton(PlaylistMan.CurPlayList);
          ShowCatTL(PlaylistMan.CurPlayList);

          SelectNext;
          FixSelected2;

          SkipTo(Random(CatSongs.VisibleSongs));
        end;
      smPlaylistRandom:  //Playlist: Select Playlist and Select Random Song
        begin
          PlaylistMan.SetPlayList(PlaylistMan.CurPlayList);

          SkipTo(Random(CatSongs.VisibleSongs));
          FixSelected2;
        end;
  end;

  AudioPlayback.PlaySound(SoundLib.Change);
  ChangeMusic;
  SetScroll;
  //UpdateLCD;  //TODO: maybe LCD Support as Plugin?
end;

procedure TScreenSong.SetJoker;
begin
  // If Party Mode
  // to-do : Party
  if Mode = smPartyMode then //Show Joker that are available
  begin
  (*
    if (PartySession.Teams.NumTeams >= 1) then
    begin
      Static[StaticTeam1Joker1].Visible := (PartySession.Teams.Teaminfo[0].Joker >= 1);
      Static[StaticTeam1Joker2].Visible := (PartySession.Teams.Teaminfo[0].Joker >= 2);
      Static[StaticTeam1Joker3].Visible := (PartySession.Teams.Teaminfo[0].Joker >= 3);
      Static[StaticTeam1Joker4].Visible := (PartySession.Teams.Teaminfo[0].Joker >= 4);
      Static[StaticTeam1Joker5].Visible := (PartySession.Teams.Teaminfo[0].Joker >= 5);
    end
    else
    begin
      Static[StaticTeam1Joker1].Visible := False;
      Static[StaticTeam1Joker2].Visible := False;
      Static[StaticTeam1Joker3].Visible := False;
      Static[StaticTeam1Joker4].Visible := False;
      Static[StaticTeam1Joker5].Visible := False;
    end;

    if (PartySession.Teams.NumTeams >= 2) then
    begin
      Static[StaticTeam2Joker1].Visible := (PartySession.Teams.Teaminfo[1].Joker >= 1);
      Static[StaticTeam2Joker2].Visible := (PartySession.Teams.Teaminfo[1].Joker >= 2);
      Static[StaticTeam2Joker3].Visible := (PartySession.Teams.Teaminfo[1].Joker >= 3);
      Static[StaticTeam2Joker4].Visible := (PartySession.Teams.Teaminfo[1].Joker >= 4);
      Static[StaticTeam2Joker5].Visible := (PartySession.Teams.Teaminfo[1].Joker >= 5);
    end
    else
    begin
      Static[StaticTeam2Joker1].Visible := False;
      Static[StaticTeam2Joker2].Visible := False;
      Static[StaticTeam2Joker3].Visible := False;
      Static[StaticTeam2Joker4].Visible := False;
      Static[StaticTeam2Joker5].Visible := False;
    end;

    if (PartySession.Teams.NumTeams >= 3) then
    begin
      Static[StaticTeam3Joker1].Visible := (PartySession.Teams.Teaminfo[2].Joker >= 1);
      Static[StaticTeam3Joker2].Visible := (PartySession.Teams.Teaminfo[2].Joker >= 2);
      Static[StaticTeam3Joker3].Visible := (PartySession.Teams.Teaminfo[2].Joker >= 3);
      Static[StaticTeam3Joker4].Visible := (PartySession.Teams.Teaminfo[2].Joker >= 4);
      Static[StaticTeam3Joker5].Visible := (PartySession.Teams.Teaminfo[2].Joker >= 5);
    end
    else
    begin
      Static[StaticTeam3Joker1].Visible := False;
      Static[StaticTeam3Joker2].Visible := False;
      Static[StaticTeam3Joker3].Visible := False;
      Static[StaticTeam3Joker4].Visible := False;
      Static[StaticTeam3Joker5].Visible := False;
    end;
  *)
  end
  else
  begin //Hide all
    Static[StaticTeam1Joker1].Visible := False;
    Static[StaticTeam1Joker2].Visible := False;
    Static[StaticTeam1Joker3].Visible := False;
    Static[StaticTeam1Joker4].Visible := False;
    Static[StaticTeam1Joker5].Visible := False;

    Static[StaticTeam2Joker1].Visible := False;
    Static[StaticTeam2Joker2].Visible := False;
    Static[StaticTeam2Joker3].Visible := False;
    Static[StaticTeam2Joker4].Visible := False;
    Static[StaticTeam2Joker5].Visible := False;

    Static[StaticTeam3Joker1].Visible := False;
    Static[StaticTeam3Joker2].Visible := False;
    Static[StaticTeam3Joker3].Visible := False;
    Static[StaticTeam3Joker4].Visible := False;
    Static[StaticTeam3Joker5].Visible := False;
  end;
end;

procedure TScreenSong.SetStatics;
var
  I:       Integer;
  Visible: Boolean;
begin
  //Set Visibility of Party Statics and Text
  Visible := (Mode = smPartyMode);

  for I := 0 to high(StaticParty) do
    Static[StaticParty[I]].Visible := Visible;

  for I := 0 to high(TextParty) do
    Text[TextParty[I]].Visible := Visible;

  //Set Visibility of Non Party Statics and Text
  Visible := not Visible;

  for I := 0 to high(StaticNonParty) do
    Static[StaticNonParty[I]].Visible := Visible;

  for I := 0 to high(TextNonParty) do
    Text[TextNonParty[I]].Visible := Visible;
end;

//Procedures for Menu

procedure TScreenSong.StartSong;
begin
  CatSongs.Selected := Interaction;
  AudioPlayback.Stop;
  //Party Mode
  if (Mode = smPartyMode) then
  begin
    FadeTo(@ScreenSingModi);
  end
  else
  begin
    FadeTo(@ScreenSing);
  end;
end;

procedure TScreenSong.SelectPlayers;
begin
  CatSongs.Selected := Interaction;
  AudioPlayback.Stop;

  ScreenName.Goto_SingScreen := True;
  FadeTo(@ScreenName);
end;

procedure TScreenSong.OpenEditor;
begin
  if (Songs.SongList.Count > 0) and
     (not CatSongs.Song[Interaction].Main) and
     (Mode = smNormal) then
  begin
    AudioPlayback.Stop;
    AudioPlayback.PlaySound(SoundLib.Start);
    CurrentSong := CatSongs.Song[Interaction];
    FadeTo(@ScreenEditSub);
  end;
end;

//Team No of Team (0-5)
procedure TScreenSong.DoJoker (Team: Byte);
begin
  {
  if (Mode = smPartyMode) and
     (PartySession.Teams.NumTeams >= Team + 1) and
     (PartySession.Teams.Teaminfo[Team].Joker > 0) then
  begin
    //Use Joker
    Dec(PartySession.Teams.Teaminfo[Team].Joker);
    SelectRandomSong;
    SetJoker;
  end;
  }
end;

//Detailed Cover Unloading. Unloads the Detailed, uncached Cover of the cur. Song
procedure TScreenSong.UnLoadDetailedCover;
begin
  CoverTime := 0;

  // show cached texture
  Button[Interaction].Texture := Texture.GetTexture(Button[Interaction].Texture.Name, TEXTURE_TYPE_PLAIN, true);
  Button[Interaction].Texture2.Alpha := 0;

  if Button[Interaction].Texture.Name <> Skin.GetTextureFileName('SongCover') then
    Texture.UnloadTexture(Button[Interaction].Texture.Name, TEXTURE_TYPE_PLAIN, false);
end;

procedure TScreenSong.Refresh;
begin
  {
  CatSongs.Refresh;
  CatSongs.ShowCategoryList;
  Interaction := 0;
  SelectNext;
  FixSelected;
  }
end;

end.
