unit UScreenMain;

interface

uses
  UMenu, SDL, UDisplay, UMusic, UPliki, SysUtils, UThemes, ULCD, ULight;

type
  TScreenMain = class(TMenu)
    public
      TextDescription:        integer;
      TextDescriptionLong:    integer;

      //Credits Mod
      Credits_Visible: Boolean;
      Credits_Y: Real;
      Credits_Time: Cardinal;
      Credits_Alpha: Cardinal;
      procedure DrawCredits;
      //Credits Mod End

      constructor Create; override;
      function ParseInput(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean; override;
      procedure onShow; override;
      procedure InteractNext; override;
      procedure InteractPrev; override;
      procedure UpdateLCD;
      procedure SetAnimationProgress(Progress: real); override;
      function Draw: boolean; override;
  end;

const Credits_Text: Array[0..46] of PChar = (
  ':SPACE:',
  'Main Idea: Corvus 5',
  'Thank you very much for this great Game',
  ':SPACE:',
  'The Ultrastar Deluxe Team:',
  ':SPACE:',
  'commandi00:',
  'Beta Testing',
  ':SPACE:',
  'Crazy Joker:',
  'Graphics',
  ':SPACE:',
  'DennistheMenace:',
  'Beta Testing and great Support in "the Board"',
  ':SPACE:',
  'Moq/Moguhguh:',
  'Programming',
  ':SPACE:',
  'Mota:',
  'Programming, Idea of creating this Mod, Team Leading',
  ':SPACE:',
  'Sawyer:',
  'Web Master, Programming',
  ':SPACE:',
  'Whiteshark:',
  'Programming, Creating Release',
  ':SPACE:',
  ':SPACE:',
  'Thanks to',
  ':SPACE:',
  'Blind Guard',
  'for supporting us and administrate this great Board',
  ':SPACE:',
  'The whole Community from www.ultra-star.dl.am',
  'for supporting us, supporting the newbies',
  'and remembering us to continue work',
  ':SPACE:',
  'You',
  'for using Ultrastar Deluxe',
  ':SPACE:',
  ':SPACE:',
  'Visit us at:',
  'http://www.UltraStar-Deluxe.de.vu',
  'http://www.USD.de.vu',
  'http://www.Ultra-Star.dl.am ("The Board" by Blind Guard)',
  'Please write Bug Reports and Feature Requests',
  'to help making this a better Game');


implementation

uses Windows, UGraphic, UMain, UIni, UTexture, USongs, Textgl, opengl, ULanguage, UParty;


function TScreenMain.ParseInput(PressedKey: Cardinal; ScanCode: byte; PressedDown: Boolean): Boolean;
var
I: Integer;
SDL_ModState:  Word;
begin
  Result := true;

  SDL_ModState := SDL_GetModState and (KMOD_LSHIFT + KMOD_RSHIFT
    + KMOD_LCTRL + KMOD_RCTRL + KMOD_LALT  + KMOD_RALT);

  //Deactivate Credits when Key is pressed
  if Credits_Visible then
  begin
    Credits_Visible := False;
    exit;
  end;

  If (PressedDown) Then
  begin // Key Down
    case PressedKey of
      SDLK_Q:
        begin
          Result := false;
        end;

      SDLK_ESCAPE :
        begin
          Result := False;
        end;

      SDLK_C:
        begin
          if (SDL_ModState = KMOD_LALT) then
          begin
            Credits_Y := 600;
            Credits_Alpha := 0;
            Credits_Visible := True;
          end;
        end;
      SDLK_M:
        begin
          if (SDL_ModState = KMOD_LALT) then
          begin
            //Create Teams:
            PartySession.Teams.NumTeams := 3;
            //Team 1
            PartySession.Teams.Teaminfo[0].Name := 'Team 1';
            PartySession.Teams.Teaminfo[0].Score:= 0;
            PartySession.Teams.Teaminfo[0].Joker := 3;
            PartySession.Teams.Teaminfo[0].CurPlayer := 0;
            PartySession.Teams.Teaminfo[0].NumPlayers := 2;
            PartySession.Teams.Teaminfo[0].Playerinfo[0].Name := 'Player 1';
            PartySession.Teams.Teaminfo[0].Playerinfo[0].TimesPlayed := 0;
            PartySession.Teams.Teaminfo[0].Playerinfo[1].Name := 'Player 2';
            PartySession.Teams.Teaminfo[0].Playerinfo[1].TimesPlayed := 0;

            //Team 2
            PartySession.Teams.Teaminfo[1].Name := 'Team 2';
            PartySession.Teams.Teaminfo[1].Score:= 0;
            PartySession.Teams.Teaminfo[1].Joker := 3;
            PartySession.Teams.Teaminfo[1].CurPlayer := 0;
            PartySession.Teams.Teaminfo[1].NumPlayers := 2;
            PartySession.Teams.Teaminfo[1].Playerinfo[0].Name := 'Player 3';
            PartySession.Teams.Teaminfo[1].Playerinfo[0].TimesPlayed := 0;
            PartySession.Teams.Teaminfo[1].Playerinfo[1].Name := 'Player 4';
            PartySession.Teams.Teaminfo[1].Playerinfo[1].TimesPlayed := 0;

            //Team 3
            PartySession.Teams.Teaminfo[2].Name := 'Team 3';
            PartySession.Teams.Teaminfo[2].Score:= 0;
            PartySession.Teams.Teaminfo[2].Joker := 3;
            PartySession.Teams.Teaminfo[2].CurPlayer := 0;
            PartySession.Teams.Teaminfo[2].NumPlayers := 2;
            PartySession.Teams.Teaminfo[2].Playerinfo[0].Name := 'Player 5';
            PartySession.Teams.Teaminfo[2].Playerinfo[0].TimesPlayed := 0;
            PartySession.Teams.Teaminfo[2].Playerinfo[1].Name := 'Player 6';
            PartySession.Teams.Teaminfo[2].Playerinfo[1].TimesPlayed := 0;

            //Rounds:
            SetLength (PartySession.Rounds, 3);
            PartySession.Rounds[0].Plugin := 1;
            PartySession.Rounds[0].Winner := 0;
            PartySession.Rounds[1].Plugin := 0;
            PartySession.Rounds[1].Winner := 0;
            PartySession.Rounds[2].Plugin := 0;
            PartySession.Rounds[2].Winner := 0;

            //Start Party
            PartySession.StartNewParty;
            //Change Screen
            Music.PlayStart;
            FadeTo(@ScreenPartyNewRound);

          end
          else
          begin
            Music.PlayStart;
            FadeTo(@ScreenPartyOptions);
          end;

        end;

      SDLK_RETURN:
        begin
          if (Interaction = 0) and (Length(Songs.Song) >= 1) then begin
            Music.PlayStart;
            if (Ini.Players >= 0) and (Ini.Players <= 3) then PlayersPlay := Ini.Players + 1;
            if (Ini.Players = 4) then PlayersPlay := 6;
            FadeTo(@ScreenName);
          end;
          if Interaction = 1 then begin
            Music.PlayStart;
            FadeTo(@ScreenEdit);
          end;
          if Interaction = 2 then begin
            Music.PlayStart;
            FadeTo(@ScreenOptions);
//            SDL_SetVideoMode(800, 600, 32, SDL_OPENGL);// or SDL_FULLSCREEN);
//            LoadTextures;
          end;
          if Interaction = 3 then begin
            Result := false;
          end;
        end;
      // Up and Down could be done at the same time,
      // but I don't want to declare variables inside
      // functions like this one, called so many times
      SDLK_DOWN:    InteractNext;
      SDLK_UP:      InteractPrev;
      SDLK_RIGHT:   InteractNext;
      SDLK_LEFT:    InteractPrev;
    end;
  end
  else // Key Up
    case PressedKey of
      SDLK_RETURN :
        begin
        end;
    end;
end;

constructor TScreenMain.Create;
var
  I:    integer;
begin
  inherited Create;

//  AddButton(400-200, 320, 400, 60, Skin.GameStart);
//  AddButton(400-200, 390, 400, 60, Skin.Editor);
//  AddButton(400-200, 460, 400, 60, Skin.Options);
//  AddButton(400-200, 530, 400, 60, Skin.Exit);

  AddBackground(Theme.Main.Background.Tex);

  AddButton(Theme.Main.ButtonSolo);
  AddButton(Theme.Main.ButtonEditor);
  AddButton(Theme.Main.ButtonOptions);
  AddButton(Theme.Main.ButtonExit);

  for I := 0 to High(Theme.Main.Static) do
    AddStatic(Theme.Main.Static[I]);

  for I := 0 to High(Theme.Main.Text) do
    AddText(Theme.Main.Text[I]);

  TextDescription := AddText(Theme.Main.TextDescription);
  TextDescriptionLong := AddText(Theme.Main.TextDescriptionLong);

  Interaction := 0;
end;

procedure TScreenMain.onShow;
begin
  LCD.WriteText(1, '  Choose mode:  ');
  UpdateLCD;
end;

procedure TScreenMain.InteractNext;
begin
  inherited InteractNext;
  Text[TextDescription].Text := Theme.Main.Description[Interaction];
  Text[TextDescriptionLong].Text := Theme.Main.DescriptionLong[Interaction];
  UpdateLCD;
  Light.LightOne(1, 200);
end;

procedure TScreenMain.InteractPrev;
begin
  inherited InteractPrev;
  Text[TextDescription].Text := Theme.Main.Description[Interaction];
  Text[TextDescriptionLong].Text := Theme.Main.DescriptionLong[Interaction];
  UpdateLCD;
  Light.LightOne(0, 200);
end;

procedure TScreenMain.UpdateLCD;
begin
  case Interaction of
    0:  LCD.WriteText(2, '      sing      ');
    1:  LCD.WriteText(2, '     editor     ');
    2:  LCD.WriteText(2, '    options     ');
    3:  LCD.WriteText(2, '      exit      ');
  end
end;

procedure TScreenMain.SetAnimationProgress(Progress: real);
begin
  Static[0].Texture.ScaleW := Progress;
  Static[0].Texture.ScaleH := Progress;
end;

function TScreenMain.Draw: boolean;
begin
Result := True;
if Credits_Visible then
  DrawCredits
else
  Result := inherited Draw;
end;

procedure TScreenMain.DrawCredits;
var
  T, I: Cardinal;
  Y: Real;
  Ver: PChar;
begin
  T := GetTickCount div 33;
  if T <> Credits_Time then
  begin
    Credits_Time := T;
    //Change Position
    Credits_Y := Credits_Y - 1;
    //Change Alpha
    Inc (Credits_Alpha, 3);
  end;

  //Draw BackGround
  DrawBG;


  //Draw pulsing Credits Text
  //Set Font
  SetFontStyle (2);
  SetFontItalic(False);
  SetFontSize(9);
  SetFontPos (460, 570);
  glColor4f(1, 0, 0, 0.2 + Abs((Credits_Alpha mod 150)/100 - 0.75));
  glPrint ('Credits! Press any Key to Continue');

  //Set Font Size for Credits
  SetFontSize(12);
  //Draw Version
  if (Credits_Y>-35) then
  begin
    Ver := PChar(Language.Translate('US_VERSION'));
    glColor4f(1, 0.6, 0.08, 0.8);
    SetFontPos (400 - glTextWidth(Ver)/2, Credits_Y);
    glprint(Ver);
  end;

  //Set Color + Start Pos
  glColor4f(0.8, 0.8, 1, 0.8);
  Y := Credits_Y + 50;

  //Search upper Position
  For I := 0 to high(Credits_Text) do
  begin
    if (Credits_Text[I]=':SPACE:') then //Spacer
      Y := Y + 55
    else
      Y := Y + 30;

    if Y > -35 then
      break;
  end;

  //Draw Text
  For T := I+1 to high(Credits_Text) do
  begin
    if (Credits_Text[T]=':SPACE:') then //Spacer
      Y := Y + 55
    else
    begin
      SetFontPos (400 - glTextWidth(Credits_Text[T])/2, Y);
      glprint(Credits_Text[T]);
      Y := Y + 30;
    end;

    if Y > 600 then
      break;
  end;

  //If lower Position is outside the Screen-> Show MainMenu
  if (Y <= 0) then
    Credits_Visible := False;
end;

end.
