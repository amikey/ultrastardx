unit UTexture;
// added for easier debug disabling
{$undef blindydebug}

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses OpenGL12,
     {$IFDEF win32}
     windows,
     {$ENDIF}
     Math,
     Classes,
     SysUtils,
     Graphics,
     UCommon,
     SDL,
     sdlutils,
     SDL_Image;

type
  TTexture = record
    TexNum:   integer;
    X:        real;
    Y:        real;
    Z:        real; // new
    W:        real;
    H:        real;
    ScaleW:   real; // for dynamic scalling while leaving width constant
    ScaleH:   real; // for dynamic scalling while leaving height constant
    Rot:      real; // 0 - 2*pi
    Int:      real; // intensity
    ColR:     real;
    ColG:     real;
    ColB:     real;
    TexW:     real; // used?
    TexH:     real; // used?
    TexX1:    real;
    TexY1:    real;
    TexX2:    real;
    TexY2:    real;
    Alpha:    real;
    Name:     string; // 0.5.0: experimental for handling cache images. maybe it's useful for dynamic skins
  end;

type
  TTextureType = (
    TEXTURE_TYPE_PLAIN,        // Plain (alpha = 1)
    TEXTURE_TYPE_TRANSPARENT,  // Alpha is used
    TEXTURE_TYPE_COLORIZED     // Alpha is used; Hue of the HSV color-model will be replaced by a new value
  );
const
  TextureTypeStr: array[TTextureType] of string = (
    'Plain',
    'Transparent',
    'Colorized'
  );

function TextureTypeToStr(TexType: TTextureType): string;
function ParseTextureType(const TypeStr: string; Default: TTextureType): TTextureType;

type
  TTextureEntry = record
    Name:       string;
    Typ:        TTextureType;

    // we use normal TTexture, it's easier to implement and if needed - we copy ready data
    Texture:        TTexture;
    TextureCache:   TTexture;
  end;

  TTextureDatabase = record
    Texture:    array of TTextureEntry;
  end;

  TTextureUnit = class
    private
      function LoadImage(const Identifier: string): PSDL_Surface;
      function pixfmt_eq(fmt1,fmt2: PSDL_Pixelformat): boolean;
      procedure AdjustPixelFormat(var TexSurface: PSDL_Surface; Typ: TTextureType);
      function GetScaledTexture(TexSurface: PSDL_Surface; W,H: Cardinal): PSDL_Surface;
      procedure ScaleTexture(var TexSurface: PSDL_Surface; W,H: Cardinal);
      procedure FitTexture(var TexSurface: PSDL_Surface; W,H: Cardinal);
      procedure ColorizeTexture(TexSurface: PSDL_Surface; Col: Cardinal);

    public
    Limit:      integer;
    CreateCacheMipmap:  boolean;

//    function GetNumberFor
    function GetTexture(const Name: string; Typ: TTextureType): TTexture; overload;
    function GetTexture(const Name: string; Typ: TTextureType; FromCache: boolean): TTexture; overload;
    function FindTexture(const Name: string): integer;
    function LoadTexture(FromRegistry: boolean; const Identifier, Format: string; Typ: TTextureType; Col: LongWord): TTexture; overload;
    function LoadTexture(const Identifier, Format: string; Typ: TTextureType; Col: LongWord): TTexture; overload;
    function LoadTexture(const Identifier: string): TTexture; overload;
    function CreateTexture(var Data: array of byte; const Name: string; W, H: word; Bits: byte): TTexture;
    procedure UnloadTexture(const Name: string; FromCache: boolean);
    Constructor Create;
    Destructor Destroy; override;
  end;

var
  Texture:          TTextureUnit;
  TextureDatabase:  TTextureDatabase;

  ActTex:     GLuint;

  Mipmapping: Boolean;

  CacheMipmap:  array[0..256*256*3-1] of byte; // 3KB
  CacheMipmapSurface: PSDL_Surface;


implementation

uses ULog,
     DateUtils,
     UCovers,
     UThemes,
     {$ifdef LINUX}
       fileutil,
     {$endif}
     {$IFDEF LAZARUS}
     LResources,
     {$ENDIF}
     {$IFDEF DARWIN}
     MacResources,
     {$ENDIF}
     StrUtils,
     dialogs;

const
  fmt_rgba: TSDL_Pixelformat = (
    palette:      nil;
    BitsPerPixel:  32;
    BytesPerPixel:  4;
    Rloss:          0;
    Gloss:          0;
    Bloss:          0;
    Aloss:          0;
    Rshift:         0;
    Gshift:         8;
    Bshift:        16;
    Ashift:        24;
    Rmask:  $000000ff;
    Gmask:  $0000ff00;
    Bmask:  $00ff0000;
    Amask:  $ff000000;
    ColorKey:       0;
    Alpha:        255
  );
  fmt_rgb: TSDL_Pixelformat = (
    palette:      nil;
    BitsPerPixel:  24;
    BytesPerPixel:  3;
    Rloss:          0;
    Gloss:          0;
    Bloss:          0;
    Aloss:          0;
    Rshift:         0;
    Gshift:         8;
    Bshift:        16;
    Ashift:         0;
    Rmask:  $000000ff;
    Gmask:  $0000ff00;
    Bmask:  $00ff0000;
    Amask:  $00000000;
    ColorKey:       0;
    Alpha:        255
  );


Constructor TTextureUnit.Create;
begin
  inherited Create;
end;

Destructor TTextureUnit.Destroy;
begin
  inherited Destroy;
end;

function TTextureUnit.pixfmt_eq(fmt1,fmt2: PSDL_Pixelformat): boolean;
begin
  if (fmt1^.BitsPerPixel = fmt2^.BitsPerPixel) and
     (fmt1^.BytesPerPixel = fmt2^.BytesPerPixel) and
     (fmt1^.Rloss = fmt2^.Rloss) and (fmt1^.Gloss = fmt2^.Gloss) and
     (fmt1^.Bloss = fmt2^.Bloss) and (fmt1^.Rmask = fmt2^.Rmask) and
     (fmt1^.Gmask = fmt2^.Gmask) and (fmt1^.Bmask = fmt2^.Bmask) and
     (fmt1^.Rshift = fmt2^.Rshift) and (fmt1^.Gshift = fmt2^.Gshift) and
     (fmt1^.Bshift = fmt2^.Bshift)
   then
    Result:=True
  else
    Result:=False;
end;

// +++++++++++++++++++++ helpers for loadimage +++++++++++++++
  function SdlStreamSeek( context : PSDL_RWops; offset : Integer; whence : Integer ) : integer; cdecl;
  var
    stream : TStream;
    origin : Word;
  begin
    stream := TStream( context.unknown );
    if ( stream = nil ) then
      raise EInvalidContainer.Create( 'SDLStreamSeek on nil' );
    case whence of
      0 : origin := soFromBeginning; //	Offset is from the beginning of the resource. Seek moves to the position Offset. Offset must be >= 0.
      1 : origin := soFromCurrent; //	Offset is from the current position in the resource. Seek moves to Position + Offset.
      2 : origin := soFromEnd;
    else
      origin := soFromBeginning; // just in case
    end;
    Result := stream.Seek( offset, origin );
  end;
  function SdlStreamRead( context : PSDL_RWops; Ptr : Pointer; size : Integer; maxnum: Integer ) : Integer; cdecl;
  var
    stream : TStream;
  begin
    stream := TStream( context.unknown );
    if ( stream = nil ) then
      raise EInvalidContainer.Create( 'SDLStreamRead on nil' );
    try
      Result := stream.read( Ptr^, Size * maxnum ) div size;
    except
      Result := -1;
    end;
  end;
  function SDLStreamClose( context : PSDL_RWops ) : Integer; cdecl;
  var
    stream : TStream;
  begin
    stream := TStream( context.unknown );
    if ( stream = nil ) then
      raise EInvalidContainer.Create( 'SDLStreamClose on nil' );
    stream.Free;
    Result := 1;
  end;
// -----------------------------------------------

function TTextureUnit.LoadImage(const Identifier: string): PSDL_Surface;

  function FileExistsInsensative( var aFileName : PChar ): boolean;
  begin
{$IFDEF LINUX} // eddie: Changed FPC to LINUX: Windows and Mac OS X dont have case sensitive file systems
    result := true;

    if FileExists( aFileName ) then
      exit;

    aFileName := pchar( FindDiskFileCaseInsensitive( aFileName ) );
    result    := FileExists( aFileName );
{$ELSE}
    result := FileExists( aFileName );
{$ENDIF}
  end;

var

  TexRWops:  PSDL_RWops;
  dHandle: THandle;

  {$IFDEF LAZARUS}
  lLazRes  : TLResource;
  lResData : TStringStream;
  {$ELSE}
  TexStream: TStream;
  {$ENDIF}
  
  lFileName : pchar;

begin
  Result   := nil;
  TexRWops := nil;

  if Identifier = '' then
    exit;
    
  lFileName := PChar(Identifier);

//  Log.LogStatus( Identifier, 'LoadImage' );

//    Log.LogStatus( 'Looking for File ( Loading : '+Identifier+' - '+ FindDiskFileCaseInsensitive(Identifier) +')', '  LoadImage' );

  if ( FileExistsInsensative(lFileName) ) then
  begin
    // load from file
    Log.LogStatus( 'Is File ( Loading : '+lFileName+')', '  LoadImage' );
    try
      Result:=IMG_Load(lFileName);
      Log.LogStatus( '       '+inttostr( integer( Result ) ), '  LoadImage' );
    except
      Log.LogStatus( 'ERROR Could not load from file' , Identifier);
      Exit;
    end;
  end
  else
  begin
    Log.LogStatus( 'IS Resource, because file does not exist.('+Identifier+')', '  LoadImage' );

    // load from resource stream
    {$IFDEF LAZARUS}
      lLazRes := LazFindResource( Identifier, 'TEX' );
      if lLazRes <> nil then
      begin
        lResData := TStringStream.create( lLazRes.value );
        try
          lResData.position := 0;
          try
            TexRWops         := SDL_AllocRW;
            TexRWops.unknown := TUnknown( lResData );
            TexRWops.seek    := SDLStreamSeek;
            TexRWops.read    := SDLStreamRead;
            TexRWops.write   := nil;
            TexRWops.close   := SDLStreamClose;
            TexRWops.type_   := 2;
          except
            Log.LogStatus( 'ERROR Could not assign resource ('+Identifier+')' , Identifier);
            Exit;
          end;
        
          Result := IMG_Load_RW(TexRWops,0);
          SDL_FreeRW(TexRWops);
        finally
          freeandnil( lResData );
        end;
      end
      else
      begin
        Log.LogStatus( 'NOT found in Resource ('+Identifier+')', '  LoadImage' );
      end;
    {$ELSE}
      dHandle := FindResource(hInstance, PChar(Identifier), 'TEX');
      if dHandle=0 then
      begin
        Log.LogStatus( 'ERROR Could not find resource' , '  '+ Identifier);
        Exit;
      end;


      TexStream := nil;
      try
        TexStream        := TResourceStream.Create(HInstance, Identifier, 'TEX');
      except
        Log.LogStatus( 'ERROR Could not load from resource' , Identifier);
        Exit;
      end;

      try
        TexStream.position := 0;
        try
          TexRWops         := SDL_AllocRW;
          TexRWops.unknown := TUnknown(TexStream);
          TexRWops.seek    := SDLStreamSeek;
          TexRWops.read    := SDLStreamRead;
          TexRWops.write   := nil;
          TexRWops.close   := SDLStreamClose;
          TexRWops.type_   := 2;
        except
          Log.LogStatus( 'ERROR Could not assign resource' , Identifier);
          Exit;
        end;

        Log.LogStatus( 'resource Assigned....' , Identifier);        
        Result:=IMG_Load_RW(TexRWops,0);
        SDL_FreeRW(TexRWops);
        
      finally
        if assigned( TexStream ) then
          freeandnil( TexStream );
      end;
    {$ENDIF}
  end;
end;

procedure TTextureUnit.AdjustPixelFormat(var TexSurface: PSDL_Surface; Typ: TTextureType);
var
  TempSurface: PSDL_Surface;
  NeededPixFmt: PSDL_Pixelformat;
begin
  NeededPixFmt:=@fmt_rgba;
  if (Typ = TEXTURE_TYPE_PLAIN) then NeededPixFmt:=@fmt_rgb
  else
  if (Typ = TEXTURE_TYPE_TRANSPARENT) or
     (Typ = TEXTURE_TYPE_COLORIZED)
     then NeededPixFmt:=@fmt_rgba
  else
    NeededPixFmt:=@fmt_rgb;


  if not pixfmt_eq(TexSurface^.format, NeededPixFmt) then
  begin
    TempSurface:=TexSurface;
    TexSurface:=SDL_ConvertSurface(TempSurface,NeededPixFmt,SDL_SWSURFACE);
    SDL_FreeSurface(TempSurface);
  end;
end;

function TTextureUnit.GetScaledTexture(TexSurface: PSDL_Surface; W,H: Cardinal): PSDL_Surface;
var
  TempSurface: PSDL_Surface;
begin
  TempSurface:=TexSurface;
  Result:=SDL_ScaleSurfaceRect(TempSurface,
                  0,0,TempSurface^.W,TempSurface^.H,
                  W,H);
end;

procedure TTextureUnit.ScaleTexture(var TexSurface: PSDL_Surface; W,H: Cardinal);
var
  TempSurface: PSDL_Surface;
begin
  TempSurface:=TexSurface;
  TexSurface:=SDL_ScaleSurfaceRect(TempSurface,
                  0,0,TempSurface^.W,TempSurface^.H,
                  W,H);
  SDL_FreeSurface(TempSurface);
end;

procedure TTextureUnit.FitTexture(var TexSurface: PSDL_Surface; W,H: Cardinal);
var
  TempSurface: PSDL_Surface;
begin
  TempSurface:=TexSurface;
  with TempSurface^.format^ do
    TexSurface:=SDL_CreateRGBSurface(SDL_SWSURFACE,W,H,BitsPerPixel,RMask, GMask, BMask, AMask);
  SDL_SetAlpha(TexSurface, 0, 255);
  SDL_SetAlpha(TempSurface, 0, 255);
  SDL_BlitSurface(TempSurface,nil,TexSurface,nil);
  SDL_FreeSurface(TempSurface);
end;

procedure TTextureUnit.ColorizeTexture(TexSurface: PSDL_Surface; Col: Cardinal);
  //returns hue within range [0.0-6.0)
  function col2hue(Color:Cardinal): double;
  var
    clr: array[0..2] of double;
    hue, max, delta: double;
  begin
    clr[0] := ((Color and $ff0000) shr 16)/255; // R
    clr[1] := ((Color and   $ff00) shr  8)/255; // G
    clr[2] :=  (Color and     $ff)        /255; // B
    max := maxvalue(clr);
    delta := max - minvalue(clr);
    // calc hue
    if (delta = 0.0) then       hue := 0
    else if (clr[0] = max) then hue :=     (clr[1]-clr[2])/delta
    else if (clr[1] = max) then hue := 2.0+(clr[2]-clr[0])/delta
    else if (clr[2] = max) then hue := 4.0+(clr[0]-clr[1])/delta;
    if (hue < 0.0) then
      hue := hue + 6.0;
    Result := hue;
  end;
  procedure ColorizePixel(Pix: PByteArray;  hue: Double);
  var
    clr: array[0..2] of Double; // [0: R, 1: G, 2: B]
    hsv: array[0..2] of Double; // [0: H(ue), 1: S(aturation), 2: V(alue)]
    h_int: Cardinal;
    delta, f, p, q, t: Double;
    max: Double;
  begin
    clr[0] := Pix[0]/255;
    clr[1] := Pix[1]/255;
    clr[2] := Pix[2]/255;

    //calculate luminance and saturation from rgb
    max := maxvalue(clr);
    delta := max - minvalue(clr);

    hsv[0] := hue; // set H(ue)
    hsv[2] := max; // set V(alue)
    // calc S(aturation)
    if (max = 0.0) then hsv[1] := 0.0
    else                hsv[1] := delta/max;

    // HSV -> RGB (H from color, S ans V from pixel)
    // transformation according to Gonzalez and Woods
    { This part does not really improve speed, maybe even slows down
    if ((hsv[1] = 0.0) or (hsv[2] = 0.0)) then
    begin
      clr[0]:=hsv[2]; clr[1]:=hsv[2]; clr[2]:=hsv[2]; // (v,v,v)
    end
    else
    }
    begin
      h_int := trunc(hsv[0]);             // h_int = |_h_|
      f := hsv[0]-h_int;                  // f = h-h_int
      p := hsv[2]*(1.0-hsv[1]);           // p = v*(1-s)
      q := hsv[2]*(1.0-(hsv[1]*f));       // q = v*(1-s*f)
      t := hsv[2]*(1.0-(hsv[1]*(1.0-f))); // t = v*(1-s*(1-f))
      case h_int of
        0: begin clr[0]:=hsv[2]; clr[1]:=t;      clr[2]:=p;      end; // (v,t,p)
        1: begin clr[0]:=q;      clr[1]:=hsv[2]; clr[2]:=p;      end; // (q,v,p)
        2: begin clr[0]:=p;      clr[1]:=hsv[2]; clr[2]:=t;      end; // (p,v,t)
        3: begin clr[0]:=p;      clr[1]:=q;      clr[2]:=hsv[2]; end; // (p,q,v)
        4: begin clr[0]:=t;      clr[1]:=p;      clr[2]:=hsv[2]; end; // (t,p,v)
        5: begin clr[0]:=hsv[2]; clr[1]:=p;      clr[2]:=q;      end; // (v,p,q)
      end;
    end;

    // and store new rgb back into the image
    Pix[0] := trunc(255*clr[0]);
    Pix[1] := trunc(255*clr[1]);
    Pix[2] := trunc(255*clr[2]);
  end;

var
  DestinationHue: Double;
  PixelIndex: Cardinal;
  Pixel: PByte;
begin
  DestinationHue := col2hue(Col);
  Pixel := TexSurface^.Pixels;
  for PixelIndex := 0 to (TexSurface^.W * TexSurface^.H)-1 do
  begin
    ColorizePixel(PByteArray(Pixel), DestinationHue);
    Inc(Pixel, TexSurface^.format.BytesPerPixel);
  end;
end;

function TTextureUnit.LoadTexture(FromRegistry: boolean; const Identifier, Format: string; Typ: TTextureType; Col: LongWord): TTexture;
var
  TexSurface: PSDL_Surface;
  MipmapSurface: PSDL_Surface;
  newWidth, newHeight: Cardinal;
  oldWidth, oldHeight: Cardinal;
begin
  Log.BenchmarkStart(4);
  Mipmapping := true;
(*
  Log.LogStatus( '', '' );

  if Identifier = nil then
    Log.LogStatus(' ERROR unknown Identifier', 'Id:'''+Identifier+''' Fmt:'''+Format+''' Typ:'''+Typ+'''')
  else
    Log.LogStatus(' should be ok - trying to load', 'Id:'''+Identifier+''' Fmt:'''+Format+''' Typ:'''+Typ+'''');
*)

 // load texture data into memory
  {$ifdef blindydebug}
  Log.LogStatus('',' ----------------------------------------------------');
  Log.LogStatus('',' LoadImage('''+Identifier+''') (called by '+Format+')');
  {$endif}
  TexSurface := LoadImage(Identifier);
  {$ifdef blindydebug}
  Log.LogStatus('',' ok');
  {$endif}
  if not assigned(TexSurface) then
  begin
    Log.LogStatus( 'ERROR Could not load texture' , Identifier +' '+ Format +' '+ TextureTypeToStr(Typ) );
    Exit;
  end;
  
  // convert pixel format as needed
  {$ifdef blindydebug}
  Log.LogStatus('',' AdjustPixelFormat');
  {$endif}
  AdjustPixelFormat(TexSurface, Typ);
  {$ifdef blindydebug}
  Log.LogStatus('',' ok');
  {$endif}
  // adjust texture size (scale down, if necessary)
  newWidth   := TexSurface.W;
  newHeight  := TexSurface.H;
  
  if (newWidth > Limit) then
    newWidth := Limit;
    
  if (newHeight > Limit) then
    newHeight := Limit;

  if (TexSurface.W > newWidth) or (TexSurface.H > newHeight) then
  begin
    {$ifdef blindydebug}
    Log.LogStatus('',' ScaleTexture');
    {$endif}
    ScaleTexture(TexSurface,newWidth,newHeight);
    {$ifdef blindydebug}
    Log.LogStatus('',' ok');
    {$endif}
  end;

  {$ifdef blindydebug}
  Log.LogStatus('',' JB-1 : typ='+Typ);
  {$endif}



  // don't actually understand, if this is needed...
  // this should definately be changed... together with all this
  // cover cache stuff
  if (CreateCacheMipmap) and (Typ = TEXTURE_TYPE_PLAIN) then
  begin
    {$ifdef blindydebug}
    Log.LogStatus('',' JB-1 : Minimap');
    {$endif}

    if (Covers.W <= 256) and (Covers.H <= 256) then
    begin
      {$ifdef blindydebug}
      Log.LogStatus('',' GetScaledTexture('''+inttostr(Covers.W)+''','''+inttostr(Covers.H)+''') (for CacheMipmap)');
      {$endif}
      MipmapSurface:=GetScaledTexture(TexSurface, Covers.W, Covers.H);
      if assigned(MipmapSurface) then
      begin
        {$ifdef blindydebug}
        Log.LogStatus('',' ok');
        Log.LogStatus('',' BlitSurface Stuff');
        {$endif}
        // creating and freeing the surface could be done once, if Cover.W and Cover.H don't change
        CacheMipmapSurface:=SDL_CreateRGBSurfaceFrom(@CacheMipmap[0], Covers.W, Covers.H, 24, Covers.W*3, $000000ff, $0000ff00, $00ff0000, 0);
        SDL_BlitSurface(MipMapSurface, nil, CacheMipmapSurface, nil);
        SDL_FreeSurface(CacheMipmapSurface);
        {$ifdef blindydebug}
        Log.LogStatus('',' ok');
        Log.LogStatus('',' SDL_FreeSurface (CacheMipmap)');
        {$endif}
        SDL_FreeSurface(MipmapSurface);
        {$ifdef blindydebug}
        Log.LogStatus('',' ok');
        {$endif}
      end
      else
      begin
        Log.LogStatus(' Error creating CacheMipmap',' LoadTexture('''+Identifier+''')');
      end;
    end;
    // should i create a cache texture, if Covers.W/H are larger?
  end;

  {$ifdef blindydebug}
  Log.LogStatus('',' JB-2');
  {$endif}


 // now we might colorize the whole thing
  if (Typ = TEXTURE_TYPE_COLORIZED) then
    ColorizeTexture(TexSurface, Col);

 // save actual dimensions of our texture
  oldWidth  := newWidth;
  oldHeight := newHeight;
 // make texture dimensions be powers of 2
  newWidth  := Round(Power(2, Ceil(Log2(newWidth))));
  newHeight := Round(Power(2, Ceil(Log2(newHeight))));
  if (newHeight <> oldHeight) or (newWidth <> oldWidth) then
    FitTexture(TexSurface, newWidth, newHeight);

  // at this point we have the image in memory...
  // scaled to be at most 1024x1024 pixels large
  // scaled so that dimensions are powers of 2
  // and converted to either RGB or RGBA

  {$ifdef blindydebug}
  Log.LogStatus('',' JB-3');
  {$endif}


  // if we got a Texture of Type Plain, Transparent or Colorized,
  // then we're done manipulating it
  // and could now create our openGL texture from it

 // prepare OpenGL texture

  // JB_linux : this is causing AV's on linux... ActText seems to be nil !
//  {$IFnDEF win32}
//  if pointer(ActTex) = nil then
//    exit;
//  {$endif}

  glGenTextures(1, @ActTex);

  glBindTexture(GL_TEXTURE_2D, ActTex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  // load data into gl texture
  if (Typ = TEXTURE_TYPE_TRANSPARENT) or
     (Typ = TEXTURE_TYPE_COLORIZED) then
  begin
    glTexImage2D(GL_TEXTURE_2D, 0, 4, newWidth, newHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, TexSurface.pixels);
  end
  else //if Typ = TEXTURE_TYPE_PLAIN then
  begin
    glTexImage2D(GL_TEXTURE_2D, 0, 3, newWidth, newHeight, 0, GL_RGB, GL_UNSIGNED_BYTE, TexSurface.pixels);
  end;

  {$ifdef blindydebug}
  Log.LogStatus('',' JB-5');
  {$endif}


  Result.X := 0;
  Result.Y := 0;
  Result.Z := 0;
  Result.W := 0;
  Result.H := 0;
  Result.ScaleW := 1;
  Result.ScaleH := 1;
  Result.Rot := 0;
  Result.TexNum := ActTex;
  Result.TexW := oldWidth / newWidth;
  Result.TexH := oldHeight / newHeight;

  Result.Int   := 1;
  Result.ColR  := 1;
  Result.ColG  := 1;
  Result.ColB  := 1;
  Result.Alpha := 1;

  // new test - default use whole texure, taking TexW and TexH as const and changing these
  Result.TexX1 := 0;
  Result.TexY1 := 0;
  Result.TexX2 := 1;
  Result.TexY2 := 1;

  {$ifdef blindydebug}
  Log.LogStatus('',' JB-6');
  {$endif}

  Result.Name := Identifier;

  SDL_FreeSurface(TexSurface);

  {$ifdef blindydebug}
  Log.LogStatus('',' JB-7');
  {$endif}


  Log.BenchmarkEnd(4);
  if Log.BenchmarkTimeLength[4] >= 1 then
    Log.LogBenchmark('**********> Texture Load Time Warning - ' + Format + '/' + Identifier + '/' + TextureTypeToStr(Typ), 4);
    
  {$ifdef blindydebug}
  Log.LogStatus('',' JB-8');
  {$endif}

end;


function TTextureUnit.GetTexture(const Name: string; Typ: TTextureType): TTexture;
begin
  Result := GetTexture(Name, Typ, true);
end;

function TTextureUnit.GetTexture(const Name: string; Typ: TTextureType; FromCache: boolean): TTexture;
var
  T:    integer; // texture
  C:    integer; // cover
  Data: array of byte;
begin

  if Name = '' then
    exit;

  // find texture entry
  T := FindTexture(Name);

  if T = -1 then
  begin
    // create texture entry
    T := Length(TextureDatabase.Texture);
    SetLength(TextureDatabase.Texture, T+1);

    TextureDatabase.Texture[T].Name := Name;
    TextureDatabase.Texture[T].Typ  := Typ;

    // inform database that no textures have been loaded into memory
    TextureDatabase.Texture[T].Texture.TexNum      := -1;
    TextureDatabase.Texture[T].TextureCache.TexNum := -1;
  end;

  // use preloaded texture
  if (not FromCache) or (FromCache and not Covers.CoverExists(Name)) then
  begin
    // use full texture
    if TextureDatabase.Texture[T].Texture.TexNum = -1 then
    begin
      // load texture
      {$ifdef blindydebug}
      Log.LogStatus('...', 'GetTexture('''+Name+''','''+Typ+''')');
      {$endif}
      TextureDatabase.Texture[T].Texture := LoadTexture(false, pchar(Name), 'JPG', Typ, $0);
      {$ifdef blindydebug}
      Log.LogStatus('done',' ');
      {$endif}
    end;

    // use texture
    Result := TextureDatabase.Texture[T].Texture;
  end;

  if FromCache and Covers.CoverExists(Name) then
  begin
    // use cache texture
    C := Covers.CoverNumber(Name);

    if TextureDatabase.Texture[T].TextureCache.TexNum = -1 then
    begin
      // load texture
      Covers.PrepareData(Name);
      TextureDatabase.Texture[T].TextureCache := CreateTexture(Covers.Data, Name, Covers.Cover[C].W, Covers.Cover[C].H, 24);
    end;

    // use texture
    Result := TextureDatabase.Texture[T].TextureCache;
  end;
end;

function TTextureUnit.FindTexture(const Name: string): integer;
var
  T:    integer; // texture
begin
  Result := -1;
  for T := 0 to high(TextureDatabase.Texture) do
    if (TextureDatabase.Texture[T].Name = Name) then
      Result := T;
end;

function TTextureUnit.LoadTexture(const Identifier, Format: string; Typ: TTextureType; Col: LongWord): TTexture;
begin
  Result := LoadTexture(false, Identifier, Format, Typ, Col);
end;

function TTextureUnit.LoadTexture(const Identifier: string): TTexture;
begin
  Result := LoadTexture(false, pchar(Identifier), 'JPG', TEXTURE_TYPE_PLAIN, 0);
end;

function TTextureUnit.CreateTexture(var Data: array of byte; const Name: string; W, H: word; Bits: byte): TTexture;
var
  Position:        integer;
  Position2:       integer;
  Pix:        integer;
  ColInt:     real;
  PPix:       PByteArray;
  TempA:      integer;
  Error:      integer;
begin
  Mipmapping := false;

  glGenTextures(1, @ActTex); // ActText = new texture number
  glBindTexture(GL_TEXTURE_2D, ActTex);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

  glTexImage2D(GL_TEXTURE_2D, 0, 3, W, H, 0, GL_RGB, GL_UNSIGNED_BYTE, @Data[0]);
  if Mipmapping then begin
    Error := gluBuild2DMipmaps(GL_TEXTURE_2D, 3, W, H, GL_RGB, GL_UNSIGNED_BYTE, @Data[0]);
    if Error > 0 then
      Log.LogError('gluBuild2DMipmaps() failed', 'TTextureUnit.CreateTexture');
  end;

  Result.X := 0;
  Result.Y := 0;
  Result.W := 0;
  Result.H := 0;
  Result.ScaleW := 1;
  Result.ScaleH := 1;
  Result.Rot := 0;
  Result.TexNum := ActTex;
  Result.TexW := 1;
  Result.TexH := 1;

  Result.Int := 1;
  Result.ColR := 1;
  Result.ColG := 1;
  Result.ColB := 1;
  Result.Alpha := 1;

  // 0.4.2 new test - default use whole texure, taking TexW and TexH as const and changing these
  Result.TexX1 := 0;
  Result.TexY1 := 0;
  Result.TexX2 := 1;
  Result.TexY2 := 1;

  // 0.5.0
  Result.Name := Name;
end;

procedure TTextureUnit.UnloadTexture(const Name: string; FromCache: boolean);
var
  T:      integer;
  TexNum: integer;
begin
  T := FindTexture(Name);

  if not FromCache then begin
    TexNum := TextureDatabase.Texture[T].Texture.TexNum;
    if TexNum >= 0 then begin
      glDeleteTextures(1, PGLuint(@TexNum));
      TextureDatabase.Texture[T].Texture.TexNum := -1;
//      Log.LogError('Unload texture no '+IntToStr(TexNum));
    end;
  end else begin
    TexNum := TextureDatabase.Texture[T].TextureCache.TexNum;
    if TexNum >= 0 then begin
      glDeleteTextures(1, @TexNum);
      TextureDatabase.Texture[T].TextureCache.TexNum := -1;
//      Log.LogError('Unload texture cache no '+IntToStr(TexNum));
    end;
  end;
end;

function TextureTypeToStr(TexType: TTextureType): string;
begin
  Result := TextureTypeStr[TexType];
end;

function ParseTextureType(const TypeStr: string; Default: TTextureType): TTextureType;
var
  TexType: TTextureType;
  UpCaseStr: string;
begin
  UpCaseStr := UpperCase(TypeStr);
  for TexType := Low(TextureTypeStr) to High(TextureTypeStr) do
  begin
    if (UpCaseStr = UpperCase(TextureTypeStr[TexType])) then
    begin
      Result := TexType;
      Exit;
    end;
  end;
  Log.LogError('Unknown texture-type: ' + TypeStr, 'ParseTextureType');
  Result := TEXTURE_TYPE_PLAIN;
end;

{$IFDEF LAZARUS}
initialization
  {$I UltraStar.lrs}
{$ENDIF}


end.
