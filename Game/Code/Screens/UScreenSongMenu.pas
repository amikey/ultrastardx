unit UScreenSongMenu;

interface

uses
  UMenu, SDL, UDisplay, UMusic, UPliki, SysUtils, UThemes;

type
  TScreenSongMenu = class(TMenu)
    private
      CurMenu: Byte; //Num of the cur. Shown Menu
    public
      Visible: Boolean; //Whether the Menu should be Drawn

      constructor Create; override;
      function ParseInput(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean; override;
      procedure onShow; override;
      function Draw: boolean; override;
      procedure MenuShow(sMenu: Byte);
      procedure HandleReturn;
  end;

const
  SM_Main = 1;
  
  SM_PlayList = 64 or 1;
  SM_Playlist_Add = 64 or 2;
  SM_Playlist_New = 64 or 3;

  SM_Playlist_Del = 64 or 5;

  SM_Playlist_Load = 64 or 8 or 1;


  SM_Party_Main = 128 or 1;
  SM_Party_Joker = 128 or 2;

var
  ISelections: Array of String;
  SelectValue: Integer;


implementation

uses UGraphic, UMain, UIni, UTexture, ULanguage, UParty, UPlaylist;

function TScreenSongMenu.ParseInput(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean;
  function IsVisible: Boolean;
  begin
    Result := True;
    if (Interactions[Interaction].Typ = 0) then
    begin
      Result := Button[Interactions[Interaction].Num].Visible;
    end
    else if (Interactions[Interaction].Typ = 1) then
    begin
      //Result := Selects[Interactions[Interaction].Num].Visible;
    end
    else if (Interactions[Interaction].Typ = 3) then
    begin
      Result := SelectsS[Interactions[Interaction].Num].Visible;
    end;
  end;

  Procedure SelectNext;
  begin
    repeat
      InteractNext;
    until IsVisible;
  end;

  Procedure SelectPrev;
  begin
    repeat
      InteractPrev;
    until IsVisible;
  end;
begin
  Result := true;
  If (PressedDown) Then
  begin // Key Down
    if (CurMenu = SM_Playlist_New) AND (Interaction=0) then
    begin
      case PressedKey of
        SDLK_0..SDLK_9, SDLK_A..SDLK_Z, SDLK_SPACE, SDLK_MINUS, SDLK_EXCLAIM, SDLK_COMMA, SDLK_SLASH, SDLK_ASTERISK, SDLK_QUESTION, SDLK_QUOTE, SDLK_QUOTEDBL:
          begin
            Button[Interaction].Text[0].Text := Button[Interaction].Text[0].Text + chr(ScanCode);
            exit;
          end;

        SDLK_BACKSPACE:
          begin
            Button[Interaction].Text[0].DeleteLastL;
            exit;
          end;
      end;
    end;

    case PressedKey of
      SDLK_Q:
        begin
          Result := false;
        end;

      SDLK_ESCAPE :
        begin
          Music.PlayBack;
          Visible := False;
        end;

      SDLK_RETURN:
        begin
          HandleReturn;
        end;

      SDLK_DOWN:    SelectNext;
      SDLK_UP:      SelectPrev;

      SDLK_RIGHT:
        begin
          if (Interaction=3) then
            InteractInc;
        end;
      SDLK_LEFT:
        begin
          if (Interaction=3) then
            InteractDec;
        end;
    end;
  end
  else // Key Up
    case PressedKey of
      SDLK_RETURN :
        begin
        end;
    end;
end;

constructor TScreenSongMenu.Create;
var
  I:    integer;
begin
  inherited Create;
  SetLength(ISelections, 1);
  ISelections[0] := 'Dummy';

  AddBackground(Theme.SongMenu.Background.Tex);

  AddButton(Theme.SongMenu.Button1);
  if (Length(Button[0].Text) = 0) then
    AddButtonText(14, 20, 'Button 1');

  AddButton(Theme.SongMenu.Button2);
  if (Length(Button[1].Text) = 0) then
    AddButtonText(14, 20, 'Button 2');

  AddButton(Theme.SongMenu.Button3);
  if (Length(Button[2].Text) = 0) then
    AddButtonText(14, 20, 'Button 3');

  AddSelectSlide(Theme.SongMenu.SelectSlide3, SelectValue, ISelections);

  AddButton(Theme.SongMenu.Button4);
  if (Length(Button[3].Text) = 0) then
    AddButtonText(14, 20, 'Button 4');

  AddText(Theme.SongMenu.TextMenu);

  for I := 0 to High(Theme.SongMenu.Static) do
    AddStatic(Theme.SongMenu.Static[I]);

  for I := 0 to High(Theme.SongMenu.Text) do
    AddText(Theme.SongMenu.Text[I]);

  Interaction := 0;
end;

function TScreenSongMenu.Draw: boolean;
begin
  inherited Draw;
end;

procedure TScreenSongMenu.onShow;
begin

end;

procedure TScreenSongMenu.MenuShow(sMenu: Byte);
begin
  Interaction := 0; //Reset Interaction
  Visible := True;  //Set Visible
  Case sMenu of
    SM_Main:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_MAIN');

        Button[0].Visible := True;
        Button[1].Visible := True;
        Button[2].Visible := True;
        Button[3].Visible := True;
        SelectsS[0].Visible := False;

        Button[0].Text[0].Text := Language.Translate('SONG_MENU_PLAY');
        Button[1].Text[0].Text := Language.Translate('SONG_MENU_CHANGEPLAYERS');
        Button[2].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_ADD');
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_EDIT');
      end;

    SM_PlayList:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PLAYLIST');

        Button[0].Visible := True;
        Button[1].Visible := True;
        Button[2].Visible := True;
        Button[3].Visible := True;
        SelectsS[0].Visible := False;

        Button[0].Text[0].Text := Language.Translate('SONG_MENU_PLAY');
        Button[1].Text[0].Text := Language.Translate('SONG_MENU_CHANGEPLAYERS');
        Button[2].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_DEL');
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_EDIT');
      end;

    SM_Playlist_Add:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PLAYLIST_ADD');

        Button[0].Visible := True;
        Button[1].Visible := False;
        Button[2].Visible := False;
        Button[3].Visible := True;
        SelectsS[0].Visible := True;

        Button[0].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_ADD_NEW');
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_ADD_EXISTING');

        SetLength(ISelections, Length(PlaylistMan.Playlists));
        PlaylistMan.GetNames(ISelections);

        if (Length(ISelections)>=1) then
        begin
          UpdateSelectSlideOptions(Theme.SongMenu.SelectSlide3, 0, ISelections, SelectValue);
        end
        else
        begin
          Button[3].Visible := False;
          SelectsS[0].Visible := False;
          Button[2].Visible := True;
          Button[2].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_NOEXISTING');
        end;
      end;

    SM_Playlist_New:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PLAYLIST_NEW');

        Button[0].Visible := True;
        Button[1].Visible := False;
        Button[2].Visible := True;
        Button[3].Visible := True;
        SelectsS[0].Visible := False;

        Button[0].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_NEW_UNNAMED');
        Button[2].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_NEW_CREATE');
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_CANCEL');
      end;

    SM_PlayList_Del:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PLAYLIST_DEL');

        Button[0].Visible := True;
        Button[1].Visible := False;
        Button[2].Visible := False;
        Button[3].Visible := True;
        SelectsS[0].Visible := False;

        Button[0].Text[0].Text := Language.Translate('SONG_MENU_YES');
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_CANCEL');
      end;

    SM_Playlist_Load:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PLAYLIST_LOAD');

        Button[0].Visible := False;
        Button[1].Visible := False;
        Button[2].Visible := False;
        Button[3].Visible := True;
        SelectsS[0].Visible := True;

        Button[3].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_LOAD');

        SetLength(ISelections, Length(PlaylistMan.Playlists));
        PlaylistMan.GetNames(ISelections);

        if (Length(ISelections)>=1) then
        begin
          UpdateSelectSlideOptions(Theme.SongMenu.SelectSlide3, 0, ISelections, SelectValue);
          Interaction := 3;
        end
        else
        begin
          Button[3].Visible := False;
          SelectsS[0].Visible := False;
          Button[2].Visible := True;
          Button[2].Text[0].Text := Language.Translate('SONG_MENU_PLAYLIST_NOEXISTING');
          Interaction := 2;
        end;
      end;


    SM_Party_Main:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PARTY_MAIN');

        Button[0].Visible := True;
        Button[1].Visible := False;
        Button[2].Visible := False;
        Button[3].Visible := True;
        SelectsS[0].Visible := False;

        Button[0].Text[0].Text := Language.Translate('SONG_MENU_PLAY');
        //Button[1].Text[0].Text := Language.Translate('SONG_MENU_JOKER');
        //Button[2].Text[0].Text := Language.Translate('SONG_MENU_PLAYMODI');
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_JOKER');
      end;

    SM_Party_Joker:
      begin
        CurMenu := sMenu;
        Text[0].Text := Language.Translate('SONG_MENU_NAME_PARTY_JOKER');

        Button[0].Visible := (PartySession.Teams.NumTeams >= 1) AND (PartySession.Teams.Teaminfo[0].Joker > 0);
        Button[1].Visible := (PartySession.Teams.NumTeams >= 2) AND (PartySession.Teams.Teaminfo[1].Joker > 0);
        Button[2].Visible := (PartySession.Teams.NumTeams >= 3) AND (PartySession.Teams.Teaminfo[2].Joker > 0);
        Button[3].Visible := True;
        SelectsS[0].Visible := False;

        Button[0].Text[0].Text := String(PartySession.Teams.Teaminfo[0].Name);
        Button[1].Text[0].Text := String(PartySession.Teams.Teaminfo[1].Name);
        Button[2].Text[0].Text := String(PartySession.Teams.Teaminfo[2].Name);
        Button[3].Text[0].Text := Language.Translate('SONG_MENU_CANCEL');

        //Set right Interaction
        if (not Button[0].Visible) then
        begin
          if (not Button[1].Visible) then
          begin
            if (not Button[2].Visible) then
            begin
              Interaction := 4;
            end
            else Interaction := 2;
          end
          else Interaction := 1;
        end;
        
      end;
  end;
end;

procedure TScreenSongMenu.HandleReturn;
begin
  Case CurMenu of
    SM_Main:
      begin
        Case Interaction of
          0: //Button 1
            begin
              ScreenSong.StartSong;
              Visible := False;
            end;

          1: //Button 2
            begin
              //Select New Players then Sing:
              ScreenSong.SelectPlayers;
              Visible := False;
            end;

          2: //Button 3
            begin
              //Show add to Playlist Menu
              MenuShow(SM_Playlist_Add);
            end;

          3: //SelectSlide 3
            begin
              //Dummy
            end;

          4: //Button 4
            begin
              ScreenSong.OpenEditor;
              Visible := False;
            end;
        end;
      end;

    SM_PlayList:
      begin
        Visible := False;
        Case Interaction of
          0: //Button 1
            begin
              ScreenSong.StartSong;
              Visible := False;
            end;

          1: //Button 2
            begin
              //Select New Players then Sing:

              Visible := False;
            end;

          2: //Button 3
            begin
              //Show add to Playlist Menu
              MenuShow(SM_Playlist_Del);
            end;

          3: //SelectSlide 3
            begin
              //Dummy
            end;

          4: //Button 4
            begin
              ScreenSong.OpenEditor;
              Visible := False;
            end;
        end;
      end;

    SM_Playlist_Add:
      begin
        Case Interaction of
          0: //Button 1
            begin
              MenuShow(SM_Playlist_New);
            end;

          3: //SelectSlide 3
            begin
              //Dummy
            end;

          4: //Button 4
            begin
              PlaylistMan.AddItem(ScreenSong.Interaction, SelectValue);
              Visible := False;
            end;
        end;
      end;

      SM_Playlist_New:
      begin
        Case Interaction of
          0: //Button 1
            begin
              //Nothing, Button for Entering Name
            end;

          2: //Button 3
            begin
              //Create Playlist and Add Song
              PlaylistMan.AddItem(
              ScreenSong.Interaction,
              PlaylistMan.AddPlaylist(Button[0].Text[0].Text));
              Visible := False;
            end;

          3: //SelectSlide 3
            begin
              //Cancel -> Go back to Add screen
              MenuShow(SM_Playlist_Add);
            end;

          4: //Button 4
            begin
              Visible := False;
            end;
        end;
      end;

    SM_PlayList_Del:
      begin
        Visible := False;
        Case Interaction of
          0: //Button 1
            begin
              //Delete
              PlayListMan.DelItem(PlayListMan.GetIndexbySongID(ScreenSong.Interaction));
              Visible := False;
            end;

          4: //Button 4
            begin
              MenuShow(SM_Playlist);
            end;
        end;
      end;

    SM_Playlist_Load:
      begin
        Case Interaction of
          4: //Button 4
            begin
              //Load Playlist
              PlaylistMan.SetPlayList(SelectValue);
              Visible := False;
            end;
        end;
      end;

    SM_Party_Main:
      begin
        Case Interaction of
          0: //Button 1
            begin
              //Start Singing
              ScreenSong.StartSong;
              Visible := False;
            end;

          4: //Button 4
            begin
              //Joker
              MenuShow(SM_Party_Joker);
            end;
        end;
      end;

    SM_Party_Joker:
      begin
        Visible := False;
        Case Interaction of
          0: //Button 1
            begin
              //Joker Team 1
              ScreenSong.DoJoker(0);
            end;

          1: //Button 2
            begin
              //Joker Team 2
              ScreenSong.DoJoker(1);
            end;

          2: //Button 3
            begin
              //Joker Team 3
              ScreenSong.DoJoker(2);
            end;

          4: //Button 4
            begin
              //Cancel... (Fo back to old Menu)
              MenuShow(SM_Party_Main);
            end;
        end;
      end;
  end;
end;

end.
 