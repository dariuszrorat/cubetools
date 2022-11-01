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

  { TConsoleApplication }

  TConsoleApplication = class(TCustomApplication)
  private
    function Clamp(X: integer; Min: integer; Max: integer): integer;
    function LinearInterpolate(X: single; X0: single; X1: single;
      Y0: single; Y1: single): single;
    function GetNonOptionValue(Index: integer; Opts: TStringArray): string;
    procedure LoadPPM(FileName: string; var Arr: TByteDynArray;
      var x: integer; var y: integer);
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

  function TConsoleApplication.LinearInterpolate(X: single; X0: single;
    X1: single; Y0: single; Y1: single): single;
  begin
    Result := Y0 + (X - X0) * (Y1 - Y0) / (X1 - X0);
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

  procedure TConsoleApplication.LoadPPM(FileName: string; var Arr: TByteDynArray;
  var x: integer; var y: integer);
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
          Part := Parts[High(Parts) - 1];

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
        while r < Int64(XSize) * Int64(YSize) * 3 do
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
      while r < Int64(x) * Int64(y) * 3 do
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
    X, Y, X0, X1, Y0, Y1: single;
    Color, NextColor: integer;
    r, g, b: single;
    LevelSquare: integer;
  begin
    LevelSquare := Level * Level;

    r := Input[Index + 0] * (LevelSquare - 1) / 255;
    g := Input[Index + 1] * (LevelSquare - 1) / 255;
    b := Input[Index + 2] * (LevelSquare - 1) / 255;

    Red := Clamp(Floor(r), 0, LevelSquare - 2);
    Green := Clamp(Floor(g), 0, LevelSquare - 2);
    Blue := Clamp(Floor(b), 0, LevelSquare - 2);

    Color := Red + Green * LevelSquare + Blue * LevelSquare * LevelSquare;
    NextColor := (Red + 1) + (Green + 1) * LevelSquare + (Blue + 1) * LevelSquare * LevelSquare;
    i := Color * 3;
    j := NextColor * 3;

    X := Input[Index + 0] / 255;
    X0 := Red / (LevelSquare - 1);
    X1 := (Red + 1) / (LevelSquare - 1);
    Y0 := Clut[i + 0] / 255;
    Y1 := Clut[j + 0] / 255;
    Y := LinearInterpolate(X, X0, X1, Y0, Y1);
    Output[Index + 0] := Clamp(Round(255 * Y), 0, 255);

    X := Input[Index + 1] / 255;
    X0 := Green / (LevelSquare - 1);
    X1 := (Green + 1) / (LevelSquare - 1);
    Y0 := Clut[i + 1] / 255;
    Y1 := Clut[j + 1] / 255;
    Y := LinearInterpolate(X, X0, X1, Y0, Y1);
    Output[Index + 1] := Clamp(Round(255 * Y), 0, 255);

    X := Input[Index + 2] / 255;
    X0 := Blue / (LevelSquare - 1);
    X1 := (Blue + 1) / (LevelSquare - 1);
    Y0 := Clut[i + 2] / 255;
    Y1 := Clut[j + 2] / 255;
    Y := LinearInterpolate(X, X0, X1, Y0, Y1);
    Output[Index + 2] := Clamp(Round(255 * Y), 0, 255);
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
    if HasOption('h', 'help') or (ParamCount = 0) then
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
    x := 0;
    y := 0;
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
    while i < (Int64(x) * Int64(y) * 3) do
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
