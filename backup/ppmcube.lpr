program ppmcube;

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

  TArr3f = array[0..2] of single;

  { TConsoleApplication }

  TConsoleApplication = class(TCustomApplication)
  private
    function Clamp(X: integer; Min: integer; Max: integer): integer;
    function LinearInterpolate(X: single; X0: single; X1: single;
      Y0: single; Y1: single): single;
    function GetNonOptionValue(Index: integer; Opts: TStringArray): string;
    procedure LoadCube(FileName: string; var Data: TByteDynArray;
      var Level: integer; var DomainMin: TArr3f; var DomainMax: TArr3f);
    procedure LoadPPM(FileName: string; var Data: TByteDynArray;
      var x: integer; var y: integer);
    procedure SavePPM(FileName: string; Data: TByteDynArray; x: integer; y: integer);
    procedure CorrectPixel(Input: TByteDynArray; Output: TByteDynArray;
      Lut: TByteDynArray; Level: integer; Index: int64; DomainMin: TArr3f; DomainMax: TArr3f);
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

  procedure TConsoleApplication.LoadCube(FileName: string; var Data: TByteDynArray;
  var Level: integer; var DomainMin: TArr3f; var DomainMax: TArr3f);
  var
    Handle: TextFile;
    FileOpened: boolean;
    RAWData: boolean;
    Line: string;
    CubeSize: integer;
    N: integer;
    i: integer;
    Parts: TStringArray;
    RGB: TRGBSingle;
  begin
    RAWData := False;
    i := 0;
    FileOpened := False;

    AssignFile(Handle, FileName);
    try
      try
        Reset(Handle);
        FileOpened := True;
        while not EOF(Handle) do
        begin
          Readln(Handle, Line);
          Line := Trim(Line);

          if Pos('DOMAIN_MIN', Line) = 1 then
          begin
            Line := StringReplace(Line, '.', ',', [rfReplaceAll]);
            Parts := Line.Split(' ');
            DomainMin[0] := StrToFloat(Parts[1]);
            DomainMin[1] := StrToFloat(Parts[2]);
            DomainMin[2] := StrToFloat(Parts[3]);
          end;
          if Pos('DOMAIN_MAX', Line) = 1 then
          begin
            Line := StringReplace(Line, '.', ',', [rfReplaceAll]);
            Parts := Line.Split(' ');
            DomainMax[0] := StrToFloat(Parts[1]);
            DomainMax[1] := StrToFloat(Parts[2]);
            DomainMax[2] := StrToFloat(Parts[3]);
          end;
          if Pos('LUT_1D_SIZE', Line) = 1 then
          begin
            Writeln('LUT 1D format is not supported');
            Terminate;
            Exit;
          end;
          if Pos('LUT_3D_SIZE', Line) = 1 then
          begin
            Parts := Line.Split(' ');
            CubeSize := StrToInt(Parts[High(Parts)]);
            Level := CubeSize;
          end;
          if (not RAWData) and (Line <> '') and
            (Line[1] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) then
          begin
            RAWData := True;
            N := CubeSize * CubeSize * CubeSize;
            SetLength(Data, N * 3);
          end;

          if RAWData and (Line <> '') and
            (Line[1] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) then
          begin
            Line := StringReplace(Line, '.', ',', [rfReplaceAll]);
            Parts := Line.Split(#9#32);
            RGB.R := StrToFloat(Parts[Low(Parts) + 0]);
            RGB.G := StrToFloat(Parts[Low(Parts) + 1]);
            RGB.B := StrToFloat(Parts[Low(Parts) + 2]);
            Data[i + 0] := Clamp(Round(255 * RGB.R), 0, 255);
            Data[i + 1] := Clamp(Round(255 * RGB.G), 0, 255);
            Data[i + 2] := Clamp(Round(255 * RGB.B), 0, 255);
            i := i + 3;
          end;
        end;

        if not RAWData then
        begin
          Writeln('Unsupported CUBE format');
          Terminate;
          Exit;
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

  procedure TConsoleApplication.LoadPPM(FileName: string; var Data: TByteDynArray;
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
    SetLength(Data, 0);
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

        SetLength(Data, XSize * YSize * 3);
        r := 0;
        while r < Int64(XSize) * Int64(YSize) * 3 do
        begin
          Read(Handle, C);
          Val := byte(c);
          Data[r] := Val;
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
    Output: TByteDynArray; Lut: TByteDynArray; Level: integer; Index: int64; DomainMin: TArr3f; DomainMax: TArr3f);
  var
    Red, Green, Blue, i, j: integer;
    X, Y, X0, X1, Y0, Y1: single;
    Color, NextColor: integer;
    r, g, b: single;
  begin
    r := Input[Index + 0] * (Level - 1) / 255;
    g := Input[Index + 1] * (Level - 1) / 255;
    b := Input[Index + 2] * (Level - 1) / 255;

    Red := Clamp(Floor(r), 0, Level - 2);
    Green := Clamp(Floor(g), 0, Level - 2);
    Blue := Clamp(Floor(b), 0, Level - 2);

    Color := Red + Green * Level + Blue * Level * Level;
    NextColor := (Red + 1) + (Green + 1) * Level + (Blue + 1) * Level * Level;
    i := Color * 3;
    j := NextColor * 3;

    X := Input[Index + 0] / 255;
    X := (X - DomainMin[0]) / (DomainMax[0] - DomainMin[0]);
    X0 := Red / (Level - 1);
    X1 := (Red + 1) / (Level - 1);
    Y0 := Lut[i + 0] / 255;
    Y1 := Lut[j + 0] / 255;
    Y := LinearInterpolate(X, X0, X1, Y0, Y1);
    Output[Index + 0] := Clamp(Round(255 * Y), 0, 255);

    X := Input[Index + 1] / 255;
    X := (X - DomainMin[1]) / (DomainMax[1] - DomainMin[1]);
    X0 := Green / (Level - 1);
    X1 := (Green + 1) / (Level - 1);
    Y0 := Lut[i + 1] / 255;
    Y1 := Lut[j + 1] / 255;
    Y := LinearInterpolate(X, X0, X1, Y0, Y1);
    Output[Index + 1] := Clamp(Round(255 * Y), 0, 255);

    X := Input[Index + 2] / 255;
    X := (X - DomainMin[2]) / (DomainMax[2] - DomainMin[2]);
    X0 := Blue / (Level - 1);
    X1 := (Blue + 1) / (Level - 1);
    Y0 := Lut[i + 2] / 255;
    Y1 := Lut[j + 2] / 255;
    Y := LinearInterpolate(X, X0, X1, Y0, Y1);
    Output[Index + 2] := Clamp(Round(255 * Y), 0, 255);
  end;

  procedure TConsoleApplication.DoRun;
  var
    ErrorMsg: string;
    NonOpts: TStringArray;
    InputFileName: string;
    CubeFileName: string;
    OutputFileName: string;
    Input, Output, Lut: TByteDynArray;
    x, y, level: integer;
    i: int64;
    DomainMin: TArr3f = (0.0, 0.0, 0.0);
    DomainMax: TArr3f = (1.0, 1.0, 1.0);
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
    CubeFileName := GetNonOptionValue(1, NonOpts);
    OutputFileName := GetNonOptionValue(2, NonOpts);

    level := 0;
    x := 0;
    y := 0;
    SetLength(Lut, 0);
    SetLength(Input, 0);
    LoadCube(CubeFileName, Lut, level);

    LoadPPM(InputFileName, Input, x, y);
    SetLength(Output, x * y * 3);

    i := 0;
    while i < (Int64(x) * Int64(y) * 3) do
    begin
      CorrectPixel(Input, Output, Lut, level, i);
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
    writeln('Usage: ppmcube <infile> <cubefile> <outfile>');
  end;

var
  Application: TConsoleApplication;
begin
  Application := TConsoleApplication.Create(nil);
  Application.Title := 'Console Application';
  Application.Run;
  Application.Free;
end.

