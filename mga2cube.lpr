program mga2cube;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  Math
  { you can add units after this };

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
  if HasOption('h', 'help') or (ParamCount = 0) then begin
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
    OutputFileName := Copy(Fn, 1, P - 1) + '.cube';
  end;
  RAWData := false;
  i := 0;

  AssignFile(InFile, InputFileName);
  AssignFile(OutFile, OutputFileName);
  try
    Reset(InFile);
    Rewrite(OutFile);
    while not EOF(InFile) do
    begin
      Readln(InFile, Line);

      if RAWData and (Trim(Line) <> '') then
      begin
        Parts := Line.Split(#9#32);
        RGB.R := StrToInt(Parts[Low(Parts) + 1]) / Max;
        RGB.G := StrToInt(Parts[Low(Parts) + 2]) / Max;
        RGB.B := StrToInt(Parts[Low(Parts) + 3]) / Max;
        Data[i] := RGB;
        i := i + 1;
      end;

      if Pos('#title', Trim(Line)) = 1 then
      begin
        Parts := Line.Split(' ');
        LUTTitle := Parts[High(Parts)];
      end;
      if Pos('in', Trim(Line)) = 1 then
      begin
        Parts := Line.Split(' ');
        CubeSize := StrToInt(Parts[High(Parts)]);
        CubeSize := Round(Power(CubeSize, 1/3));
      end;
      if Pos('out', Trim(Line)) = 1 then
      begin
        Parts := Line.Split(' ');
        Max := StrToInt(Parts[High(Parts)]) - 1;
      end;
      if Pos('values', Trim(Line)) = 1 then
      begin
        RAWData := true;
        N := CubeSize * CubeSize * CubeSize;
        SetLength(Data, N);
      end;
    end;

    Writeln(OutFile, 'TITLE "' + LUTTitle + '"');
    Writeln(OutFile, 'DOMAIN_MIN 0 0 0');
    Writeln(OutFile, 'DOMAIN_MAX 1 1 1');
    Writeln(OutFile, 'LUT_3D_SIZE ' + IntToStr(CubeSize));

    i := 0; j := 0; k := 0;

    for r := 0 to CubeSize - 1 do
    begin
      for g := 0 to CubeSize - 1 do
      begin
        for b := 0 to CubeSize - 1 do
        begin
          Writeln(OutFile, StringReplace(Format('%8.6f %8.6f %8.6f',
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
  StopOnException:=True;
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
  Application:=TConsoleApplication.Create(nil);
  Application.Title:='Console Application';
  Application.Run;
  Application.Free;
end.

