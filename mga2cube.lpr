program mga2cube;

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

  procedure TConsoleApplication.DoRun;
  var
    ErrorMsg: string;
    NonOpts: TStringArray;
    InputFileName: string;
    OutputFileName: string;
    InFile, OutFile: TextFile;
    CubeSize: integer;
    Max: integer;
    RAWData: boolean;
    LUTTitle: string;
    Line: string;
    Fn: string;
    P: integer;
    N: integer;
    i, j, k, r, g, b: integer;
    Parts: TStringArray;
    RGB: TRGBSingle;
    Data: TRGBSingleDynArray;
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
    CubeSize := 27;
    Max := 65536;
    NonOpts := GetNonOptions('h', ['help']);
    InputFileName := GetNonOptionValue(0, NonOpts);
    OutputFileName := GetNonOptionValue(1, NonOpts);

    if OutputFileName = '' then
    begin
      Fn := ExtractFileName(InputFileName);
      P := Pos('.', Fn);
      OutputFileName := Copy(Fn, 1, P - 1) + '.cube';
    end;
    RAWData := False;
    i := 0;

    if not FileExists(InputFileName) then
    begin
      Writeln('File not found');
      Terminate;
      Exit;
    end;

    AssignFile(InFile, InputFileName);
    AssignFile(OutFile, OutputFileName);
    try
      try
        Reset(InFile);
        Rewrite(OutFile);
        while not EOF(InFile) do
        begin
          Readln(InFile, Line);

          if Pos('#title', Trim(Line)) = 1 then
          begin
            Parts := Line.Split(' ');
            LUTTitle := Parts[High(Parts)];
          end;
          if Pos('in', Trim(Line)) = 1 then
          begin
            Parts := Line.Split(' ');
            CubeSize := StrToInt(Parts[High(Parts)]);
            CubeSize := Round(Power(CubeSize, 1 / 3));
          end;
          if Pos('out', Trim(Line)) = 1 then
          begin
            Parts := Line.Split(' ');
            Max := StrToInt(Parts[High(Parts)]) - 1;
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
            Parts := Line.Split(#9#32);
            RGB.R := StrToInt(Parts[Low(Parts) + 1]) / Max;
            RGB.G := StrToInt(Parts[Low(Parts) + 2]) / Max;
            RGB.B := StrToInt(Parts[Low(Parts) + 3]) / Max;
            Data[i] := RGB;
            i := i + 1;
          end;
        end;

        Writeln(OutFile, 'TITLE "' + LUTTitle + '"');
        Writeln(OutFile, StringReplace(Format('DOMAIN_MIN %.1f %.1f %.1f', [0.0, 0.0, 0.0]), ',', '.', [rfReplaceAll]));
        Writeln(OutFile, StringReplace(Format('DOMAIN_MAX %.1f %.1f %.1f', [Max / 65536, Max / 65536, Max / 65536]), ',', '.', [rfReplaceAll]));
        Writeln(OutFile, 'LUT_3D_SIZE ' + IntToStr(CubeSize));

        i := 0;
        j := 0;
        k := 0;

        for r := 0 to CubeSize - 1 do
        begin
          for g := 0 to CubeSize - 1 do
          begin
            for b := 0 to CubeSize - 1 do
            begin
              Writeln(OutFile,
                StringReplace(Format('%11.9f %11.9f %11.9f',
                [Data[i].R, Data[i].G, Data[i].B]), ',', '.', [rfReplaceAll]));
              i := i + CubeSize * CubeSize;
            end;
            i := j + CubeSize;
            j := j + CubeSize;
          end;
          k := k + 1;
          j := k;
          i := k;
        end;
      except
        on E: Exception do
        begin
          Writeln(E.Message);
        end;
      end;
    finally
      CloseFile(InFile);
      CloseFile(OutFile);
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
    writeln('Usage: mga2cube <mgafile> [<cubefile>]');
  end;

var
  Application: TConsoleApplication;
begin
  Application := TConsoleApplication.Create(nil);
  Application.Title := 'Console Application';
  Application.Run;
  Application.Free;
end.
