program cube2ppm;

{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  Math { you can add units after this };

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
    function GetNonOptionValue(Index: integer; Opts: TStringArray): string;
    function ClampToByteInt(X: single): integer;
    function FlattenCube(Level: integer; B: integer; G: integer; R: integer): integer;
    procedure WriteHaldClut(FileName: string; Data: TRGBSingleDynArray; CubeLevel: integer;
      HaldLevel: integer; TextMode: boolean);
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

  function TConsoleApplication.ClampToByteInt(X: single): integer;
  var
    N: integer;
  begin
    N := Round(X);
    if N > 255 then
      Result := 255
    else if N < 0 then
      Result := 0
    else
      Result := N;
  end;

  function TConsoleApplication.FlattenCube(Level: integer; B: integer;
    G: integer; R: integer): integer;
  begin
    Result := B * Level * Level + G * Level + R;
  end;

  procedure TConsoleApplication.WriteHaldClut(FileName: string;
    Data: TRGBSingleDynArray; CubeLevel: integer; HaldLevel: integer; TextMode: boolean);
  var
    r, g, b: integer;
    PR, PG, PB, PN: integer;
    IndexR, IndexG, IndexB: integer;
    NextR, NextG, NextB: integer;
    OffsetR, OffsetG, OffsetB: single;
    ScaleR, ScaleG, ScaleB: single;
    Handle: TextFile;
  begin
    AssignFile(Handle, FileName);
    try
      Rewrite(Handle);
      if TextMode then
        Write(Handle, 'P3' + #10)
      else
        Write(Handle, 'P6' + #10);
      Write(Handle, '# Created by cube2ppm' + #10);
      Write(Handle, Format('%d %d', [HaldLevel * HaldLevel * HaldLevel,
        HaldLevel * HaldLevel * HaldLevel]) + #10);
      Write(Handle, '255' + #10);

      PN := 0;
      for b := 0 to HaldLevel * HaldLevel - 1 do
      begin
        for g := 0 to HaldLevel * HaldLevel - 1 do
        begin
          for r := 0 to HaldLevel * HaldLevel - 1 do
          begin
            OffsetR := (1.0 / (single(HaldLevel * HaldLevel) - 1.0)) *
              r * (single(CubeLevel) - 1.0);
            OffsetG := (1.0 / (single(HaldLevel * HaldLevel) - 1.0)) *
              g * (single(CubeLevel) - 1.0);
            OffsetB := (1.0 / (single(HaldLevel * HaldLevel) - 1.0)) *
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

            PR := ClampToByteInt(255.0 *
              (Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].R +
              ScaleR * (Data[FlattenCube(CubeLevel, IndexB, IndexG, NextR)].R -
              Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].R)));
            PG := ClampToByteInt(255.0 *
              (Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].G +
              ScaleG * (Data[FlattenCube(CubeLevel, IndexB, NextG, IndexR)].G -
              Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].G)));
            PB := ClampToByteInt(255.0 *
              (Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].B +
              ScaleB * (Data[FlattenCube(CubeLevel, NextB, IndexG, IndexR)].B -
              Data[FlattenCube(CubeLevel, IndexB, IndexG, IndexR)].B)));

            if TextMode then
            begin
              Write(Handle, Format('%d %d %d ', [PR, PG, PB]));
              PN := PN + 1;
              if PN = 15 then
              begin
                Write(Handle, #10);
                PN := 0;
              end;
            end
            else
            begin
              Write(Handle, char(PR));
              Write(Handle, char(PG));
              Write(Handle, char(PB));
            end;
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
    CubeSize: integer;
    HaldLevel: integer;
    RAWData: boolean;
    LUTTitle: string;
    Line: string;
    Fn: string;
    Ext: string;
    Opt: string;
    P: integer;
    N: integer;
    i: integer;
    Parts: TStringArray;
    RGB: TRGBSingle;
    Data: TRGBSingleDynArray;
    PPMTextMode: boolean;
  begin

    // quick check parameters
    ErrorMsg := CheckOptions('hlt', ['help', 'level', 'text']);
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

    PPMTextMode := HasOption('t', 'text');

    { add your program here }
    CubeSize := 27;
    HaldLevel := 8;
    NonOpts := GetNonOptions('hl:t', ['help', 'level', 'text']);
    Opt := Trim(GetOptionValue('l', 'level'));
    if (Opt <> '') then
      HaldLevel := StrToInt(Opt);
    if (HaldLevel < 2) or (HaldLevel > 16) then
    begin
      Writeln('Hald CLUT level must be between 2 and 16');
      Terminate;
      Exit;
    end;

    InputFileName := GetNonOptionValue(0, NonOpts);
    OutputFileName := GetNonOptionValue(1, NonOpts);

    if OutputFileName = '' then
    begin
      Fn := ExtractFileName(InputFileName);
      P := Pos('.', Fn);
      OutputFileName := Copy(Fn, 1, P - 1) + '.ppm';
    end;

    Ext := UpCase(ExtractFileExt(OutputFileName));
    if Ext <> '.PPM' then
    begin
      Writeln('Only PPM format is supported');
      Terminate;
      Exit;
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
            CubeSize := StrToInt(Parts[High(Parts)]);
          end;
          if (not RAWData) and (Line <> '') and
            (Line[1] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) then
          begin
            RAWData := True;
            N := CubeSize * CubeSize * CubeSize;
            SetLength(Data, N);
          end;

          if RAWData and (Line <> '') and
            (Line[1] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) then
          begin
            Line := StringReplace(Line, '.', ',', [rfReplaceAll]);
            Parts := Line.Split(#9#32);
            RGB.R := StrToFloat(Parts[Low(Parts) + 0]);
            RGB.G := StrToFloat(Parts[Low(Parts) + 1]);
            RGB.B := StrToFloat(Parts[Low(Parts) + 2]);
            Data[i] := RGB;
            i := i + 1;
          end;
        end;

        if not RAWData then
        begin
          Writeln('Unsupported CUBE format');
          Terminate;
          Exit;
        end;

        WriteHaldClut(OutputFileName, Data, CubeSize, HaldLevel, PPMTextMode);
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
    writeln('Usage: cube2ppm [options] <cubefile> [<ppmfile>]');
    writeln;
    writeln('OPTIONS:');
    writeln;
    writeln('    -t        use PPM text mode');
    writeln('    -l level  set HALD CLUT level');
  end;

var
  Application: TConsoleApplication;
begin
  Application := TConsoleApplication.Create(nil);
  Application.Title := 'Console Application';
  Application.Run;
  Application.Free;
end.
