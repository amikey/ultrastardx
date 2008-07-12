unit UDataBase;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses USongs,
     USong,
     SQLiteTable3;

//--------------------
//DataBaseSystem - Class including all DB Methods
//--------------------
type
  TStatResult = record
    Case Typ: Byte of
      0: (Singer:     ShortString;
          Score:      Word;
          Difficulty: Byte;
          SongArtist: ShortString;
          SongTitle:  ShortString);

      1: (Player:     ShortString;
          AverageScore: Word);

      2: (Artist: ShortString;
          Title:  ShortString;
          TimesSung:  Word);

      3: (ArtistName:   ShortString;
          TimesSungtot: Word);
  end;
  AStatResult = Array of TStatResult;
  
  TDataBaseSystem = class
    private
      ScoreDB: TSqliteDatabase;
      sFilename: string;
      
    public


    property Filename: String read sFilename;
    
    Destructor Destroy; override;

    Procedure Init(const Filename: string);
    procedure ReadScore(Song: TSong);
    procedure AddScore(Song: TSong; Level: integer; Name: string; Score: integer);
    procedure WriteScore(Song: TSong);

    Function  GetStats(var Stats: AStatResult; const Typ, Count: Byte; const Page: Cardinal; const Reversed: Boolean): Boolean;
    Function  GetTotalEntrys(const Typ: Byte): Cardinal;
    Function  GetStatReset: TDateTime;
  end;

var
  DataBase: TDataBaseSystem;

implementation

uses
  IniFiles,
  ULog,
  StrUtils,
  SysUtils;

const
  cUS_Scores = 'us_scores';
  cUS_Songs  = 'us_songs';
  cUS_Statistics_Info  = 'us_statistics_info';

//--------------------
//Create - Opens Database and Create Tables if not Exist
//--------------------

Procedure TDataBaseSystem.Init(const Filename: string);
begin
  Log.LogStatus('Initializing database: "'+Filename+'"', 'TDataBaseSystem.Init');
  
  //Open Database
  ScoreDB   := TSqliteDatabase.Create( Filename );
  sFilename := Filename;

  try
    //Look for Tables => When not exist Create them
    if not ScoreDB.TableExists( cUS_Scores ) then
    begin
      ScoreDB.execsql('CREATE TABLE `'+cUS_Scores+'` (`SongID` INT( 11 ) NOT NULL , `Difficulty` INT( 1 ) NOT NULL , `Player` VARCHAR( 150 ) NOT NULL , `Score` INT( 5 ) NOT NULL );');
      debugWriteln( 'TDataBaseSystem.Init - CREATED US_Scores' );
    end;

    if not ScoreDB.TableExists( cUS_Songs ) then
    begin
      ScoreDB.execsql('CREATE TABLE `'+cUS_Songs+'` (`ID` INTEGER PRIMARY KEY, `Artist` VARCHAR( 255 ) NOT NULL , `Title` VARCHAR( 255 ) NOT NULL , `TimesPlayed` int(5) NOT NULL );');
      debugWriteln( 'TDataBaseSystem.Init - CREATED US_Songs' );
    end;

    if not ScoreDB.TableExists( cUS_Statistics_Info ) then
    begin
      ScoreDB.execsql('CREATE TABLE `'+cUS_Statistics_Info+'` (`ResetTime` VARCHAR(17) );');
      ScoreDB.execsql('INSERT INTO `'+cUS_Statistics_Info+'` (`ResetTime`) VALUES ("'+datetimetostr(now)+'");');
      debugWriteln( 'TDataBaseSystem.Init - CREATED US_Statistics_Info' );
    end;

     //Not possible because of String Limitation to 255 Chars //Need to rewrite Wrapper
    {if not ScoreDB.TableExists('US_SongCache') then
      ScoreDB.ExecSQL('CREATE TABLE `US_SongCache` (`Path` VARCHAR( 255 ) NOT NULL , `Filename` VARCHAR( 255 ) NOT NULL , `Title` VARCHAR( 255 ) NOT NULL , `Artist` VARCHAR( 255 ) NOT NULL , `Folder` VARCHAR( 255 ) NOT NULL , `Genre` VARCHAR( 255 ) NOT NULL , `Edition` VARCHAR( 255 ) NOT NULL , `Language` VARCHAR( 255 ) NOT NULL , `Creator` VARCHAR( 255 ) NOT NULL , `Cover` VARCHAR( 255 ) NOT NULL , `Background` VARCHAR( 255 ) NOT NULL , `Video` VARCHAR( 255 ) NOT NULL , `VideoGap` FLOAT NOT NULL , `Gap` FLOAT NOT NULL , `Start` FLOAT NOT NULL , `Finish` INT( 11 ) NOT NULL , `BPM` INT( 5 ) NOT NULL , `Relative` BOOLEAN NOT NULL , `NotesGap` INT( 11 ) NOT NULL);');}


  finally
    Log.LogInfo( cUS_Songs +' exists: ' + IfThen(ScoreDB.TableExists(cUS_Songs), 'true', 'false'),
      'TDataBaseSystem.Init');
    Log.LogInfo( cUS_Scores +' exists: ' + IfThen(ScoreDB.TableExists(cUS_Scores), 'true', 'false'),
      'TDataBaseSystem.Init');
  //ScoreDB.Free;
  end;

end;

//--------------------
//Destroy - Frees Database
//--------------------
Destructor TDataBaseSystem.Destroy;
begin
  Log.LogInfo('TDataBaseSystem.Free', 'TDataBaseSystem.Destroy');
  freeandnil( ScoreDB );
  inherited;
end;

//--------------------
//ReadScore - Read Scores into SongArray
//--------------------
procedure TDataBaseSystem.ReadScore(Song: TSong);
var
  TableData: TSqliteTable;
  Difficulty: Integer;
begin
  if not assigned( ScoreDB ) then
    exit;


  //ScoreDB := TSqliteDatabase.Create(sFilename);
  try
    try
    //Search Song in DB
    TableData := ScoreDB.GetTable('SELECT `Difficulty`, `Player`, `Score` FROM `'+cUS_Scores+'` WHERE `SongID` = (SELECT `ID` FROM `us_songs` WHERE `Artist` = "' + Song.Artist + '" AND `Title` = "' + Song.Title + '" LIMIT 1) ORDER BY `Score` DESC  LIMIT 15');

    //Empty Old Scores
    SetLength (Song.Score[0], 0);
    SetLength (Song.Score[1], 0);
    SetLength (Song.Score[2], 0);

    while not TableData.Eof do //Go through all Entrys
    begin //Add one Entry to Array
          Difficulty := StrToIntDef(TableData.FieldAsString(TableData.FieldIndex['Difficulty']), -1);
      if (Difficulty >= 0) AND (Difficulty <= 2) then
      begin
        SetLength(Song.Score[Difficulty], Length(Song.Score[Difficulty]) + 1);

        Song.Score[Difficulty, high(Song.Score[Difficulty])].Name  :=
            TableData.FieldAsString(TableData.FieldIndex['Player']);
        Song.Score[Difficulty, high(Song.Score[Difficulty])].Score :=
            StrtoInt(TableData.FieldAsString(TableData.FieldIndex['Score']));
      end;
      TableData.Next;
      
    end; // While not TableData.EOF

    except
      for Difficulty := 0 to 2 do
      begin
        SetLength(Song.Score[Difficulty], 1);
        Song.Score[Difficulty, 1].Name := 'Error Reading ScoreDB';
      end;
    end;
    
  finally
  //ScoreDb.Free;
  end;
end;

//--------------------
//AddScore - Add one new Score to DB
//--------------------
procedure TDataBaseSystem.AddScore(Song: TSong; Level: integer; Name: string; Score: integer);
var
ID: Integer;
TableData: TSqliteTable;
begin
  if not assigned( ScoreDB ) then
    exit;

  //ScoreDB := TSqliteDatabase.Create(sFilename);
  try
  //Prevent 0 Scores from being added
  if (Score > 0) then
  begin

    ID := ScoreDB.GetTableValue('SELECT `ID` FROM `'+cUS_Songs+'` WHERE `Artist` = "' + Song.Artist + '" AND `Title` = "' + Song.Title + '"');
    if ID = 0 then //Song doesn't exist -> Create
    begin
      ScoreDB.ExecSQL ('INSERT INTO `'+cUS_Songs+'` ( `ID` , `Artist` , `Title` , `TimesPlayed` ) VALUES (NULL , "' + Song.Artist + '", "' + Song.Title + '", "0");');
      ID := ScoreDB.GetTableValue('SELECT `ID` FROM `US_Songs` WHERE `Artist` = "' + Song.Artist + '" AND `Title` = "' + Song.Title + '"');
      if ID = 0 then //Could not Create Table
        exit;
    end;
    //Create new Entry
    ScoreDB.ExecSQL('INSERT INTO `'+cUS_Scores+'` ( `SongID` , `Difficulty` , `Player` , `Score` ) VALUES ("' + InttoStr(ID) + '", "' + InttoStr(Level) + '", "' + Name + '", "' + InttoStr(Score) + '");');

    //Delete Last Position when there are more than 5 Entrys
    if ScoreDB.GetTableValue('SELECT COUNT(`SongID`) FROM `'+cUS_Scores+'` WHERE `SongID` = "' + InttoStr(ID) + '" AND `Difficulty` = "' + InttoStr(Level) +'"') > 5 then
    begin
      TableData := ScoreDB.GetTable('SELECT `Player`, `Score` FROM `'+cUS_Scores+'` WHERE SongID = "' + InttoStr(ID) + '" AND `Difficulty` = "' + InttoStr(Level) +'" ORDER BY `Score` ASC LIMIT 1');
      ScoreDB.ExecSQL('DELETE FROM `US_Scores` WHERE SongID = "' + InttoStr(ID) + '" AND `Difficulty` = "' + InttoStr(Level) +'" AND `Player` = "' + TableData.FieldAsString(TableData.FieldIndex['Player']) + '" AND `Score` = "' + TableData.FieldAsString(TableData.FieldIndex['Score']) + '"');
    end;

  end;
  finally
  //ScoreDB.Free;
  end;
end;

//--------------------
//WriteScore - Not needed with new System; But used for Increment Played Count
//--------------------
procedure TDataBaseSystem.WriteScore(Song: TSong);
begin
  if not assigned( ScoreDB ) then
    exit;
    
  try
    //Increase TimesPlayed
    ScoreDB.ExecSQL ('UPDATE `'+cUS_Songs+'` SET `TimesPlayed` = `TimesPlayed` + "1" WHERE `Title` = "' + Song.Title + '" AND `Artist` = "' + Song.Artist + '";');
  except

  end;
end;

//--------------------
//GetStats - Write some Stats to Array, Returns True if Chossen Page has Entrys
//Case Typ of
//0 - Best Scores
//1 - Best Singers
//2 - Most sung Songs
//3 - Most popular Band
//--------------------
Function TDataBaseSystem.GetStats(var Stats: AStatResult; const Typ, Count: Byte; const Page: Cardinal; const Reversed: Boolean): Boolean;
var
  Query: String;
  TableData: TSqliteTable;
begin
  Result := False;

  if not assigned( ScoreDB ) then
    exit;

  if (Length(Stats) < Count) then
    Exit;

  {Todo:  Add Prevention that only Players with more than 5 Scores are Selected at Typ 2}

  //Create Query
  Case Typ of
    0: Query := 'SELECT `Player` , `Difficulty` , `Score` , `Artist` , `Title` FROM `'+cUS_Scores+'` INNER JOIN `US_Songs` ON (`SongID` = `ID`) ORDER BY `Score`';
    1: Query := 'SELECT `Player` , ROUND (Sum(`Score`) / COUNT(`Score`)) FROM `'+cUS_Scores+'` GROUP BY `Player` ORDER BY (Sum(`Score`) / COUNT(`Score`))';
    2: Query := 'SELECT `Artist` , `Title` , `TimesPlayed` FROM `'+cUS_Songs+'` ORDER BY `TimesPlayed`';
    3: Query := 'SELECT `Artist` , Sum(`TimesPlayed`) FROM `'+cUS_Songs+'` GROUP BY `Artist` ORDER BY Sum(`TimesPlayed`)';
  end;

  //Add Order Direction
  If Reversed then
    Query := Query + ' ASC'
  else
    Query := Query + ' DESC';

  //Add Limit
  Query := Query + ' LIMIT ' + InttoStr(Count * Page) + ', ' + InttoStr(Count) + ';';

  //Execute Query
  try
    TableData := ScoreDB.GetTable(Query);
  except
    exit;  // this has a try except, because ( on linux at least ) it seems that doing a GetTable, that returns nothing
           // causes an exception.   and in the case of a new Database file, with no scores stored yet... this seems to except here.
  end;

  //if Result empty -> Exit
  if (TableData.RowCount < 1) then
    exit;

  //Copy Result to Stats Array
  while not TableData.Eof do
  begin
    Stats[TableData.Row].Typ := Typ;

    Case Typ of
      0:begin
          Stats[TableData.Row].Singer := TableData.Fields[0];

          Stats[TableData.Row].Difficulty := StrtoIntDef(TableData.Fields[1], 0);

          Stats[TableData.Row].Score := StrtoIntDef(TableData.Fields[2], 0){TableData.FieldAsInteger(2)};
          Stats[TableData.Row].SongArtist := TableData.Fields[3];
          Stats[TableData.Row].SongTitle := TableData.Fields[4];
        end;

        1:begin
          Stats[TableData.Row].Player := TableData.Fields[0];
          Stats[TableData.Row].AverageScore := StrtoIntDef(TableData.Fields[1], 0);
        end;

        2:begin
          Stats[TableData.Row].Artist := TableData.Fields[0];
          Stats[TableData.Row].Title  := TableData.Fields[1];
          Stats[TableData.Row].TimesSung  := StrtoIntDef(TableData.Fields[2], 0);
        end;

        3:begin
          Stats[TableData.Row].ArtistName := TableData.Fields[0];
          Stats[TableData.Row].TimesSungtot := StrtoIntDef(TableData.Fields[1], 0);
        end;

    end;

    TableData.Next;
  end;

  Result := True;
end;

//--------------------
//GetTotalEntrys - Get Total Num of entrys for a Stats Query
//--------------------
Function  TDataBaseSystem.GetTotalEntrys(const Typ: Byte): Cardinal;
var Query: String;
begin
  Result := 0;

  if not assigned( ScoreDB ) then
    exit;

  try
    //Create Query
    Case Typ of
      0: begin
           Query := 'SELECT COUNT(`SongID`) FROM `'+cUS_Scores+'`;';
           if not ScoreDB.TableExists( cUS_Scores ) then
             exit;
         end;
      1: begin
           Query := 'SELECT COUNT(DISTINCT `Player`) FROM `'+cUS_Scores+'`;';
           if not ScoreDB.TableExists( cUS_Scores ) then
             exit;
         end;
      2: begin
           Query := 'SELECT COUNT(`ID`) FROM `'+cUS_Songs+'`;';
           if not ScoreDB.TableExists( cUS_Songs ) then
             exit;
         end;
      3: begin
           Query := 'SELECT COUNT(DISTINCT `Artist`) FROM `'+cUS_Songs+'`;';
           if not ScoreDB.TableExists( cUS_Songs ) then
             exit;
         end;
    end;
  
    Result := ScoreDB.GetTableValue(Query);
  except
    // TODO : JB_Linux - Why do we get these exceptions on linux !! -> should be solved!
    on E:ESQLiteException DO
    begin
      exit;
    end;
  end;

end;

//--------------------
//GetStatReset - Get reset date of statistic data
//--------------------
Function  TDataBaseSystem.GetStatReset: TDateTime;
var
  Query: String;
  TableData: TSqliteTable;
begin
  if not assigned( ScoreDB ) then
    exit;

  Query := 'SELECT `ResetTime` FROM `'+cUS_Statistics_Info+'`;';
  TableData := ScoreDB.GetTable(Query);
  result:=StrToDateTime(TableData.Fields[0]);
end;

end.
