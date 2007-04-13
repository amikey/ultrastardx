unit UDisplay;

interface

uses Windows, SDL, UMenu, OpenGL12, SysUtils, dialogs;

type
  TDisplay = class
    ActualScreen:     PMenu;
    NextScreen:       PMenu;

    h_DC:     HDC;
    h_RC:     HGLRC;

    Fade: Real;
    // fade-mod
    myfade: integer;
    pTexData : Pointer;
    pTex : glUInt;
    // end

    function Draw: Boolean;
    procedure PrintScreen;
    constructor Create;
    // fade mod
    destructor Destroy;
    // end
    procedure ScreenShot;
  end;

var
  Display:          TDisplay;
//  ActualScreen:     PMenu;
//  NextScreen:       PMenu;

implementation

uses UGraphic, UTime, Graphics, Jpeg, UPliki, UTexture;

constructor TDisplay.Create;
begin
  inherited Create;
  // fade mod
  myfade:=0;
  // generate texture for fading between screens
  GetMem(pTexData, 1024*1024*4);
  glGenTextures(1, pTex);
  glBindTexture(GL_TEXTURE_2D, pTex);

  glTexImage2D(GL_TEXTURE_2D, 0, 3, 1024, 1024, 0, GL_RGBA, GL_UNSIGNED_BYTE, pTexData);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  FreeMem(pTexData);
  // end
end;

// fade mod
destructor TDisplay.Destroy;
begin
  glDeleteTextures(1,@pTex);
  inherited Destroy;
end;
// end

function TDisplay.Draw: Boolean;
var
  S:    integer;
  // fade mod
  myfade2:integer;
  // end
begin
  Result := True;

{  Col := 1;
  if (ParamStr(1) = '-black') or (ParamStr(1) = '-fsblack') then
    Col := 0;}

  glClearColor(0, 0, 0 , 0);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  for S := 1 to Screens do begin
    ScreenAct := S;

//    if Screens = 1 then ScreenX := 0;
//    if (Screens = 2) and (S = 1) then ScreenX := -1;
//    if (Screens = 2) and (S = 2) then ScreenX := 1;
    ScreenX := 0;


    if S = 2 then TimeSkip := 0 else; // it's easier than rewriting code
    glViewPort((S-1) * ScreenW div Screens, 0, ScreenW div Screens, ScreenH);

//    ActualScreen.SetAnimationProgress(1);
    if not assigned (NextScreen) then begin
      Result := ActualScreen.Draw;
      // fade mod
      myfade:=0;
      // end
    end
    else begin
      // fade mod
      //Create Fading texture if we're just starting
      if myfade = 0 then
      begin
        ActualScreen.Draw;
        glBindTexture(GL_TEXTURE_2D, pTex);
        glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 0, 0, 1024, 1024, 0);
        NextScreen.onShow;
      end;

//      LastFade := Fade;   // whatever
//      Fade := Fade -0.999; // start fading out
      myfade:=myfade+1;

//      ActualScreen.ShowFinish := false; // no purpose?

//      ActualScreen.SetAnimationProgress(Fade-1); // nop?

      NextScreen.Draw; // draw next screen

      // and draw old screen over it... slowly fading out
      myfade2:=myfade*myfade;
      glBindTexture(GL_TEXTURE_2D, pTex);
      glColor4f(1, 1, 1, (1000-myfade2)/1000); // strange calculation - alpha gets negative... but looks good this way
      glEnable(GL_TEXTURE_2D);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      glEnable(GL_BLEND);
      glBegin(GL_QUADS);
        glTexCoord2f(0,0);glVertex2f(0-myfade2,   600+myfade2);
        glTexCoord2f(0,ScreenH/1024);glVertex2f(0-myfade2,   0-myfade2);
        glTexCoord2f(ScreenW/1024,ScreenH/1024);glVertex2f(800+myfade2, 0-myfade2);
        glTexCoord2f(ScreenW/1024,0);glVertex2f(800+myfade2, 600+myfade2);
      glEnd;
      glDisable(GL_BLEND);
      glDisable(GL_TEXTURE_2D);
    end;

    if myfade > 50 then begin // fade out complete...
        myfade:=0;
        ActualScreen.onHide; // nop... whatever
        ActualScreen.ShowFinish:=False;
        ActualScreen:=NextScreen;
        NextScreen := nil;
        ActualScreen.onShowFinish; // one more nop...
        ActualScreen.ShowFinish := true; // who wrote this crap?
    // end of fade mod
    end; // if
  end; // for
//  SwapBuffers(h_DC);
end;

{function TDisplay.Fade(FadeIn : Boolean; Steps : UInt8): UInt8;
begin
  Self.FadeIn := FadeIn;
  FadeStep := (SizeOf(FadeStep) * $FF) div Steps;
  ActualStep := $FF;
  Result := $FF div FadeStep;
end;}

procedure TDisplay.PrintScreen;
var
  Bitmap:     TBitmap;
  Jpeg:       TJpegImage;
  X, Y:       integer;
  Num:        integer;
  FileName:   string;
begin
  for Num := 1 to 9999 do begin
    FileName := IntToStr(Num);
    while Length(FileName) < 4 do FileName := '0' + FileName;
    FileName := ScreenshotsPath + 'screenshot' + FileName + '.jpg';
    if not FileExists(FileName) then break
  end;

  glReadPixels(0, 0, ScreenW, ScreenH, GL_RGBA, GL_UNSIGNED_BYTE, @PrintScreenData[0]);
  Bitmap := TBitmap.Create;
  Bitmap.Width := ScreenW;
  Bitmap.Height := ScreenH;

  for Y := 0 to ScreenH-1 do
    for X := 0 to ScreenW-1 do
      Bitmap.Canvas.Pixels[X, Y] := PrintScreenData[(ScreenH-1-Y) * ScreenW + X] and $00FFFFFF;

  Jpeg := TJpegImage.Create;
  Jpeg.Assign(Bitmap);
  Bitmap.Free;
  Jpeg.CompressionQuality := 95;//90;
  ForceDirectories(ScreenshotsPath);
  Jpeg.SaveToFile(FileName);
  Jpeg.Free;
end;

procedure TDisplay.ScreenShot;
 var F : file;
     FileInfo: BITMAPINFOHEADER;
     FileHeader : BITMAPFILEHEADER;
     pPicData:Pointer;
     FileName: String;
     Num: Integer;
begin
  //bilddatei Suchen
  for Num := 1 to 9999 do begin
    FileName := IntToStr(Num);
    while Length(FileName) < 4 do FileName := '0' + FileName;
    FileName := {ScreenshotsPath + }'screenshot' + FileName + '.BMP';
    if not FileExists(FileName) then break
  end;

 //Speicher f�r die Speicherung der Header-Informationen vorbereiten
 ZeroMemory(@FileHeader, SizeOf(BITMAPFILEHEADER));
 ZeroMemory(@FileInfo, SizeOf(BITMAPINFOHEADER));
 
 //Initialisieren der Daten des Headers
 FileHeader.bfType := 19778; //$4D42 = 'BM'
 FileHeader.bfOffBits := SizeOf(BITMAPINFOHEADER)+SizeOf(BITMAPFILEHEADER);
 
 //Schreiben der Bitmap-Informationen
 FileInfo.biSize := SizeOf(BITMAPINFOHEADER);
 FileInfo.biWidth := ScreenH;
 FileInfo.biHeight := ScreenW;
 FileInfo.biPlanes := 1;
 FileInfo.biBitCount := 32;
 FileInfo.biSizeImage := FileInfo.biWidth*FileInfo.biHeight*(FileInfo.biBitCount div 8);
 
 //Gr��enangabe auch in den Header �bernehmen
 FileHeader.bfSize := FileHeader.bfOffBits + FileInfo.biSizeImage;
 
 //Speicher f�r die Bilddaten reservieren
 GetMem(pPicData, FileInfo.biSizeImage);
 try
  //Bilddaten von OpenGL anfordern (siehe oben)
  glReadPixels(0, 0, ScreenW, ScreenH, GL_BGRA, GL_UNSIGNED_BYTE, pPicData);
 
  //Und den ganzen M�ll in die Datei schieben ;-)
  //Moderne Leute nehmen daf�r auch Streams ...
  AssignFile(f, Filename);
  Rewrite( f,1 );
  try
   BlockWrite(F, FileHeader, SizeOf(BITMAPFILEHEADER));
   BlockWrite(F, FileInfo, SizeOf(BITMAPINFOHEADER));
   BlockWrite(F, pPicData^, FileInfo.biSizeImage );
  finally
   CloseFile(f);
  end;
 finally
  //Und den angeforderten Speicher wieder freigeben ...
  FreeMem(pPicData, FileInfo.biSizeImage);
 end;
end;


end.
