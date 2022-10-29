program cube2mga;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp
  { you can add units after this };

type

  TRGB = record
    R: integer;
    G: integer;
    B: integer;
  end;

  TArr1D = array of TRGB;

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

function TConsoleApplication.GetNonOptionValue(Index: integer; Opts: TStringArray): string;
var
  i: integer;
begin
  result := '';
  for i := Low(Opts) to High(Opts) do
  begin
    if i = Index then
    begin
      result := Opts[i];
      break;
    end;
  end;
end;

procedure TConsoleApplication.DoRun;
var
  ErrorMsg: String;
  NonOpts: TStringArray;
  InputFileName: string;
  OutputFileName: string;
  InFile, OutFile: TextFile;
  InFileOpened, OutFileOpened: boolean;
  CubeSize: integer;
  Max: integer;
  RAWData: boolean;
  LUTTitle: string;
  Line: string;
  Fn: string;
  P: integer;
  N: integer;
  i, j, k, idx, r, g, b: integer;
  Parts: TStringArray;
  RGB: TRGB;
  Data: TArr1D;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
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
  Max := 65535;
  NonOpts := GetNonOptions('h', ['help']);
  InputFileName := GetNonOptionValue(0, NonOpts);
  OutputFileName := GetNonOptionValue(1, NonOpts);

  if OutputFileName = '' then
  begin
    Fn := ExtractFileName(InputFileName);
    P := Pos('.', Fn);
    OutputFileName := Copy(Fn, 1, P - 1) + '.mga';
  end;
  RAWData := false;
  i := 0;
  InFileOpened := false;
  OutFileOpened := false;

  AssignFile(InFile, InputFileName);
  AssignFile(OutFile, OutputFileName);
  try
    Reset(InFile);
    InFileOpened := true;
    while not EOF(InFile) do
    begin
      Readln(InFile, Line);
      Line := Trim(Line);

      if RAWData and (Line <> '') and (Pos('#', Line) = 0) then
      begin
        Line := StringReplace(Line, '.', ',', [rfReplaceAll]);
        Parts := Line.Split(#9#32);
        RGB.R := Round(Max * StrToFloat(Parts[Low(Parts) + 0]));
        RGB.G := Round(Max * StrToFloat(Parts[Low(Parts) + 1]));
        RGB.B := Round(Max * StrToFloat(Parts[Low(Parts) + 2]));
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
        Writeln('CUBE 1D format is not supported');
        Terminate;
        Exit;
      end;
      if Pos('LUT_3D_SIZE', Line) = 1 then
      begin
        Parts := Line.Split(' ');
        CubeSize := StrToInt(Parts[High(Parts)]);
        RAWData := true;
        N := CubeSize * CubeSize * CubeSize;
        SetLength(Data, N);
      end;
    end;

    if not RAWData then
    begin
      Writeln('Unsupported CUBE format');
      Terminate;
      Exit;
    end;

    Rewrite(OutFile);
    OutFileOpened := true;
    Writeln(OutFile, '#HEADER');
    Writeln(OutFile, '#filename: ' + ExtractFileName(OutputFileName));
    Writeln(OutFile, '#type: 3D cube file');
    Writeln(OutFile, '#format: 1.00');
    Writeln(OutFile, '#created:');
    Writeln(OutFile, '#owner: technicolor');
    Writeln(OutFile, '#title: ' + LUTTitle);
    Writeln(OutFile, '#END');
    Writeln(OutFile);
    Writeln(OutFile, 'channel 3d');
    Writeln(OutFile, 'in ' + IntToStr(N));
    Writeln(OutFile, 'out ' + IntToStr(Max+1));
    Writeln(OutFile);
    Writeln(OutFile, 'format lut');
    Writeln(OutFile);
    Writeln(OutFile, 'values'+#9+'red'+#9+'green'+#9+'blue');

    i := 0; j := 0; k := 0; idx := 0;

    for r := 0 to CubeSize - 1 do
    begin
      for g := 0 to CubeSize - 1 do
      begin
        for b := 0 to CubeSize - 1 do
        begin
          Writeln(OutFile, Format('%d%s%d%s%d%s%d',
          [idx, #9, Data[i].R, #9, Data[i].G, #9, Data[i].B]));
          i := i + CubeSize * CubeSize;
          idx := idx + 1;
        end;
        i := j + CubeSize;
        j := j + CubeSize;
      end;
      k := k + 1;
      j := k;
      i := k;
    end;
  finally
    if InFileOpened then
      CloseFile(InFile);
    if OutFileOpened then
      CloseFile(OutFile);
  end;

  // stop program loop
  Terminate;
end;

constructor TConsoleApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TConsoleApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TConsoleApplication.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: cube2mga <cubefile> <mgafile>');
end;

var
  Application: TConsoleApplication;
begin
  Application:=TConsoleApplication.Create(nil);
  Application.Title:='Console Application';
  Application.Run;
  Application.Free;
end.

