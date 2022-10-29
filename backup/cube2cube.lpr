program cube2cube;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  Math { you can add units after this };

type

  TRGB = record
    R: single;
    G: single;
    B: single;
  end;

  TArr1D = array of TRGB;

  { TConsoleApplication }

  TConsoleApplication = class(TCustomApplication)
  private
    function GetNonOptionValue(Index: integer; Opts: TStringArray): string;
    function ClampFloat(X: single): single;
    function FlattenCube(Level: integer; B: integer; G: integer; R: integer): integer;
    procedure WriteCube(FileName: string; Data: TArr1D; CubeLevel: integer;
      DestSize: integer; Fmt: string; ATitle: string);
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

  { TConsoleApplication }

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

  function TConsoleApplication.ClampFloat(X: single): single;
  begin
    if X > 1.0 then
      Result := 1.0
    else if X < 0.0 then
      Result := 0.0
    else
      Result := X;
  end;

  function TConsoleApplication.FlattenCube(Level: integer; B: integer;
    G: integer; R: integer): integer;
  begin
    Result := B * Level * Level + G * Level + R;
  end;

  procedure TConsoleApplication.WriteCube(FileName: string;
    Data: TArr1D; CubeLevel: integer; DestSize: integer; Fmt: string; ATitle: string);
  var
    r, g, b: integer;
    PR, PG, PB: single;
    IndexR, IndexG, IndexB: integer;
    NextR, NextG, NextB: integer;
    OffsetR, OffsetG, OffsetB: single;
    ScaleR, ScaleG, ScaleB: single;
    Handle: TextFile;
  begin
    AssignFile(Handle, FileName);
    try
      Rewrite(Handle);
      case Fmt[1] of
        'A':
          begin
            Writeln(Handle, 'TITLE "' + ATitle + '"');
            Writeln(Handle, 'DOMAIN_MIN 0 0 0');
            Writeln(Handle, 'DOMAIN_MAX 1 1 1');
            Writeln(Handle, Format('LUT_3D_SIZE %d', [DestSize]));
          end;
        'D':
          begin
            Writeln(Handle, '# ' + ATitle);
            Writeln(Handle, Format('LUT_3D_SIZE %d', [DestSize]));
            Writeln(Handle, 'LUT_3D_INPUT_RANGE 0.0 1.0');
          end;
        'T':
          begin
            Writeln(Handle, '# Truelight Cube v2.0');
            Writeln(Handle, '# lutLength 2');
            Writeln(Handle, '# iDims     3');
            Writeln(Handle, '# oDims     3');
            Writeln(Handle, Format('# width     %d %d %d', [DestSize, DestSize, DestSize]));
            Writeln(Handle);
            Writeln(Handle, '# InputLUT');
            Writeln(Handle, '0.000000000 0.000000000 0.000000000');
            Writeln(Handle, StringReplace(Format('%.9f %.9f %.9f',[single(DestSize-1), single(DestSize-1), single(DestSize-1)]), ',', '.', [rfReplaceAll]));
            Writeln(Handle);
            Writeln(Handle, '# Cube');
          end;
      end;

      for b := 0 to DestSize - 1 do
      begin
        for g := 0 to DestSize - 1 do
        begin
          for r := 0 to DestSize - 1 do
          begin
            OffsetR := (1.0 / (single(DestSize) - 1.0)) *
              r * (single(CubeLevel) - 1.0);
            OffsetG := (1.0 / (single(DestSize) - 1.0)) *
              g * (single(CubeLevel) - 1.0);
            OffsetB := (1.0 / (single(DestSize) - 1.0)) *
              b * (single(CubeLevel) - 1.0);
            IndexR := Floor(OffsetR);
            IndexG := Floor(OffsetG);
            IndexB := Floor(OffsetB);
            ScaleR := OffsetR - single(IndexR);
            ScaleG := OffsetG - single(IndexG);
            ScaleB := OffsetB - single(IndexB);
            NextR := IndexR + 1;
            NextG := IndexG + 1;
            NextB := IndexB + 1;
            if IndexR = (CubeLevel - 1) then
              NextR := IndexR;
            if IndexG = (CubeLevel - 1) then
              NextG := IndexG;
            if IndexB = (CubeLevel - 1) then
              NextB := IndexB;

            PR := ClampFloat(1.0 *
              (Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].R +
              ScaleR * (Data[FlattenCube(CubeLevel, IndexB, IndexG, NextR)].R -
              Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].R)));
            PG := ClampFloat(1.0 *
              (Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].G +
              ScaleG * (Data[FlattenCube(CubeLevel, IndexB, NextG, IndexR)].G -
              Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].G)));
            PB := ClampFloat(1.0 *
              (Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].B +
              ScaleB * (Data[FlattenCube(CubeLevel, NextB, IndexG, IndexR)].B -
              Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].B)));

            Writeln(Handle, StringReplace(Format('%11.9f %11.9f %11.9f', [PR, PG, PB]), ',', '.', [rfReplaceAll]));
          end;
        end;
      end;

    finally
      CloseFile(Handle);
    end;
  end;

  procedure TConsoleApplication.DoRun;
  var
    ErrorMsg: string;
    NonOpts: TStringArray;
    InputFileName: string;
    OutputFileName: string;
    InFile: TextFile;
    InFileOpened: boolean;
    SrcSize: integer;
    DestSize: integer;
    RAWData: boolean;
    LUTTitle: string;
    Line: string;
    Fn: string;
    Ext: string;
    Opt: string;
    OutputFormat: string;
    P: integer;
    N: integer;
    i: integer;
    Parts: TStringArray;
    RGB: TRGB;
    Data: TArr1D;
  begin

    // quick check parameters
    ErrorMsg := CheckOptions('hlto', ['help', 'level', 'text', 'output']);
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
    SrcSize := 27;
    DestSize := 8;
    LUTTitle := '';
    OutputFormat := 'A';
    NonOpts := GetNonOptions('hl:to:', ['help', 'level', 'text', 'output']);
    Opt := Trim(GetOptionValue('l', 'level'));
    if (Opt <> '') then
      DestSize := StrToInt(Opt);
    if (DestSize < 2) or (DestSize > 64) then
    begin
      Writeln('Hald CLUT level must be between 2 and 64');
      Terminate;
      Exit;
    end;
    Opt := Trim(GetOptionValue('o', 'output'));
    if (Opt <> '') then
    begin
      OutputFormat := Upcase(Opt);
      if (OutputFormat <> 'A') and (OutputFormat <> 'D') and (OutputFormat <> 'T') then
      begin
        Writeln('Unsupported output format');
        Terminate;
        Exit;
      end;
    end;

    InputFileName := GetNonOptionValue(0, NonOpts);
    OutputFileName := GetNonOptionValue(1, NonOpts);

    if OutputFileName = '' then
    begin
      OutputFileName := 'converted.cube';
    end;

    RAWData := False;
    i := 0;
    InFileOpened := False;

    AssignFile(InFile, InputFileName);
    try
      try
        Reset(InFile);
        InFileOpened := True;
        while not EOF(InFile) do
        begin
          Readln(InFile, Line);
          Line := Trim(Line);

          if RAWData and (Line <> '') and (Pos('#', Line) = 0) then
          begin
            Line := StringReplace(Line, '.', ',', [rfReplaceAll]);
            Parts := Line.Split(#9#32);
            RGB.R := StrToFloat(Parts[Low(Parts) + 0]);
            RGB.G := StrToFloat(Parts[Low(Parts) + 1]);
            RGB.B := StrToFloat(Parts[Low(Parts) + 2]);
            Data[i] := RGB;
            i := i + 1;
          end;

          if Pos('TITLE', Line) = 1 then
          begin
            Parts := Line.Split(' ');
            LUTTitle := Parts[High(Parts)];
            LUTTitle := LUTTitle.Trim(['"']);
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
            SrcSize := StrToInt(Parts[High(Parts)]);
            RAWData := True;
            N := SrcSize * SrcSize * SrcSize;
            SetLength(Data, N);
          end;
        end;

        if not RAWData then
        begin
          Writeln('Unsupported CUBE format');
          Terminate;
          Exit;
        end;

        WriteCube(OutputFileName, Data, SrcSize, DestSize, OutputFormat, LUTTitle);
      except
        on E: Exception do
        begin
          Writeln(E.Message);
        end;
      end;
    finally
      if InFileOpened then
        CloseFile(InFile);
    end;

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
    writeln('Usage: cube2cube [options] <infile> <outfile>');
    writeln;
    writeln('OPTIONS:');
    writeln;
    writeln('    -l level  set cube level');
    writeln('    -o fmt    set output format');
    writeln('       formats: A = Adobe, D = Davinci, T = Truelight');
  end;

var
  Application: TConsoleApplication;
begin
  Application := TConsoleApplication.Create(nil);
  Application.Title:='Console Application';
  Application.Run;
  Application.Free;
end.

