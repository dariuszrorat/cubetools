program ppmclut;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  Math,
  Types { you can add units after this };

type

  TRGBSingle = record
    R: single;
    G: single;
    B: single;
  end;

  TRGBSingleDynArray = array of TRGBSingle;

  { TConsoleApplication }

  TConsoleApplication = class(TCustomApplication)
  private
    function Clamp(X: integer; Min: integer; Max: integer): integer;
    function GetNonOptionValue(Index: integer; Opts: TStringArray): string;
    procedure LoadPPM(FileName: string; var Arr: TByteDynArray; var x: integer; var y: integer);
    procedure SavePPM(FileName: string; Data: TByteDynArray; x: integer; y: integer);
    procedure CorrectPixel(Input: TByteDynArray; Output: TByteDynArray;
      Clut: TByteDynArray; Level: integer; Index: int64);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

  { TConsoleApplication }
  function TConsoleApplication.Clamp(X: integer; Min: integer; Max: integer): integer;
  begin
    if X > Max then
      Result := Max
    else if X < Min then
      Result := Min
    else
      Result := X;
  end;


  function TConsoleApplication.GetNonOptionValue(Index: integer;
    Opts: TStringArray): string;
  var
    i: integer;
  begin
    Result := '';
    for i := Low(Opts) to High(Opts) do
    begin
      if i = Index then
      begin
        Result := Opts[i];
        break;
      end;
    end;
  end;

  procedure TConsoleApplication.LoadPPM(FileName: string; var Arr: TByteDynArray; var x: integer; var y: integer);
  var
    Handle: TextFile;
    FileOpened: boolean;
    Line: string;
    Header: string;
    Part: string;
    EndHeader: boolean;
    Parts: TStringArray;
    XSize, YSize: integer;
    Max: integer;
    C: char;
    Val: byte;
    r: int64;
  begin
    SetLength(Arr, 0);
    AssignFile(Handle, FileName);
    try
      try
        Reset(Handle);
        FileOpened := True;
        Header := '';
        EndHeader := False;
        Max := 255;

        repeat

          Readln(Handle, Line);
          Line := Trim(Line);
          if Line[1] <> '#' then
          begin
            Header := Header + Line + ' ';
          end;


          if Copy(Header, 1, 2) <> 'P6' then
          begin
            Writeln('Invalid PPM file');
            EndHeader := True;
            Terminate;
            Exit;
          end;

          Parts := Header.Split(' ');
          Part := Parts[High(Parts)-1];

          EndHeader := (Part[1] in ['0', '1', '2', '3', '4', '5', '6',
            '7', '8', '9']) and (Length(Parts) >= 5);
        until EndHeader;

        XSize := StrToInt(Parts[1]);
        YSize := StrToInt(Parts[2]);
        x := XSize;
        y := YSize;

        Max := StrToInt(Parts[3]);
        if Max > 255 then
        begin
          Writeln('Invalid PPM file');
          Terminate;
          Exit;
        end;

        SetLength(Arr, XSize * YSize * 3);
        r := 0;
        while r < XSize * YSize * 3 do
        begin
          Read(Handle, C);
          Val := byte(c);
          Arr[r] := Val;
          Inc(r);
        end;
      except
        on E: Exception do
        begin
          Writeln(E.Message);
        end;
      end;
    finally
      if FileOpened then
        CloseFile(Handle);
    end;

  end;

  procedure TConsoleApplication.SavePPM(FileName: string; Data: TByteDynArray;
    x: integer; y: integer);
  var
    Handle: TextFile;
    C: char;
    r: int64;
  begin
    AssignFile(Handle, FileName);
    try
      Rewrite(Handle);
      Write(Handle, Format('P6 %d %d 255' + #10, [x, y]));
      r := 0;

      r := 0;
      while r < x * y * 3 do
      begin
        C := char(Data[r]);
        Write(Handle, C);
        Inc(r);
      end;

    finally
      CloseFile(Handle);
    end;
  end;

  procedure TConsoleApplication.CorrectPixel(Input: TByteDynArray;
    Output: TByteDynArray; Clut: TByteDynArray; Level: integer; Index: int64);
  var
    Red, Green, Blue, i, j: integer;
    dR, dG, dB: single;
    Color: integer;
    r, g, b: single;
    tmp: array[0..5] of single;
    LevelSquare: integer;
  begin
    LevelSquare := Level * Level;

    r := Input[Index + 0] * (LevelSquare - 1) / 255;
    g := Input[Index + 1] * (LevelSquare - 1) / 255;
    b := Input[Index + 2] * (LevelSquare - 1) / 255;

    Red   := Clamp(Round(r), 0, LevelSquare - 2);
    Green := Clamp(Round(g), 0, LevelSquare - 2);
    Blue  := Clamp(Round(b), 0, LevelSquare - 2);

    // Temporary not needed
    //dR := (Input[Index + 0] / 255.0) * single((LevelSquare - 1)) - single(Red);
    //dG := (Input[Index + 1] / 255.0) * single((LevelSquare - 1)) - single(Green);
    //dB := (Input[Index + 2] / 255.0) * single((LevelSquare - 1)) - single(Blue);

    Color := Red + Green * LevelSquare + Blue * LevelSquare * LevelSquare;
    i := Color * 3;

    // Temporary not needed
    //j := (Color + 1) * 3;

    Output[Index + 0] := Clut[i + 0];
    Output[Index + 1] := Clut[i + 1];
    Output[Index + 2] := Clut[i + 2];

  end;

  procedure TConsoleApplication.DoRun;
  var
    ErrorMsg: string;
    NonOpts: TStringArray;
    InputFileName: string;
    ClutFileName: string;
    OutputFileName: string;
    Input, Output, Clut: TByteDynArray;
    x, y, level: integer;
    i: int64;
  begin
    // quick check parameters
    ErrorMsg := CheckOptions('h', 'help');
    if ErrorMsg <> '' then
    begin
      ShowException(Exception.Create(ErrorMsg));
      Terminate;
      Exit;
    end;

    // parse parameters
    if HasOption('h', 'help') then
    begin
      WriteHelp;
      Terminate;
      Exit;
    end;

    { add your program here }
    NonOpts := GetNonOptions('h', ['help']);
    InputFileName := GetNonOptionValue(0, NonOpts);
    ClutFileName := GetNonOptionValue(1, NonOpts);
    OutputFileName := GetNonOptionValue(2, NonOpts);

    level := 0;
    x :=0; y := 0;
    SetLength(Clut, 0);
    SetLength(Input, 0);
    LoadPPM(ClutFileName, Clut, x, y);
    while level * level * level < x do
    begin
      level := level + 1;
    end;

    LoadPPM(InputFileName, Input, x, y);
    SetLength(Output, x * y * 3);

    i := 0;
    while i < (x * y * 3) do
    begin
      CorrectPixel(Input, Output, Clut, level, i);
      i := i + 3;
    end;


    SavePPM(OutputFileName, Output, x, y);

    // stop program loop
    Terminate;
  end;

  constructor TConsoleApplication.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  destructor TConsoleApplication.Destroy;
  begin
    inherited Destroy;
  end;

  procedure TConsoleApplication.WriteHelp;
  begin
    { add your help code here }
    writeln('Usage: ppmclut [options] <infile> <clutfile> <outfile>');
  end;

var
  Application: TConsoleApplication;
begin
  Application := TConsoleApplication.Create(nil);
  Application.Title := 'Console Application';
  Application.Run;
  Application.Free;
end.
