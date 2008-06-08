unit UScreenOptionsGraphics;

interface

{$I switches.inc}

uses
  UMenu, SDL, UDisplay, UMusic, UFiles, UIni, UThemes;

type
  TScreenOptionsGraphics = class(TMenu)
    public
      constructor Create; override;
      function ParseInput(PressedKey: Cardinal; CharCode: WideChar; PressedDown: Boolean): Boolean; override;
      procedure onShow; override;
  end;

implementation

uses UGraphic, UMain, SysUtils;

function TScreenOptionsGraphics.ParseInput(PressedKey: Cardinal; CharCode: WideChar; PressedDown: Boolean): Boolean;
begin
  Result := true;
  If (PressedDown) Then
  begin // Key Down
    // check normal keys
    case WideCharUpperCase(CharCode)[1] of
      'Q':
        begin
          Result := false;
          Exit;
        end;
    end;
    
    // check special keys
    case PressedKey of
      SDLK_ESCAPE,
      SDLK_BACKSPACE :
        begin
          Ini.Save;
          AudioPlayback.PlaySound(SoundLib.Back);
          FadeTo(@ScreenOptions);
        end;
      SDLK_RETURN:
        begin
{          if SelInteraction <= 1 then begin
            Restart := true;
          end;}
          if SelInteraction = 5 then begin
            Ini.Save;
            AudioPlayback.PlaySound(SoundLib.Back);
			Reinitialize3D();           
            FadeTo(@ScreenOptions);
          end;
        end;
      SDLK_DOWN:
        InteractNext;
      SDLK_UP :
        InteractPrev;
      SDLK_RIGHT:
        begin
          if (SelInteraction >= 0) and (SelInteraction <= 4) then begin
            AudioPlayback.PlaySound(SoundLib.Option);
            InteractInc;
          end;
        end;
      SDLK_LEFT:
        begin
          if (SelInteraction >= 0) and (SelInteraction <= 4) then begin
            AudioPlayback.PlaySound(SoundLib.Option);
            InteractDec;
          end;
        end;
    end;
  end;
end;

constructor TScreenOptionsGraphics.Create;
//var
// I:      integer; // Auto Removed, Unused Variable
begin
  inherited Create;

  LoadFromTheme(Theme.OptionsGraphics);

  AddSelectSlide(Theme.OptionsGraphics.SelectSlideResolution, Ini.Resolution, IResolution);
  AddSelect(Theme.OptionsGraphics.SelectFullscreen, Ini.Fullscreen, IFullscreen);
  AddSelect(Theme.OptionsGraphics.SelectDepth, Ini.Depth, IDepth);
  AddSelect(Theme.OptionsGraphics.SelectOscilloscope, Ini.Oscilloscope, IOscilloscope);
  AddSelect(Theme.OptionsGraphics.SelectMovieSize, Ini.MovieSize, IMovieSize);


  AddButton(Theme.OptionsGraphics.ButtonExit);
  if (Length(Button[0].Text)=0) then
    AddButtonText(14, 20, Theme.Options.Description[7]);

end;

procedure TScreenOptionsGraphics.onShow;
begin
  inherited;

  Interaction := 0;
end;

end.
