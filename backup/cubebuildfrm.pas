unit cubebuildfrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Menus,
  ExtCtrls, Buttons, Spin, ExtDlgs, SynEdit, SynHighlighterAny, Math;

type
  TRGBSingle = record
    R: single;
    G: single;
    B: single;
  end;

  TRGBSingleDynArray = array of TRGBSingle;

  TShapeDynArray = array of TShape;

  { TFormBuilder }

  TFormBuilder = class(TForm)
    BtnReset: TButton;
    ColorDialog: TColorDialog;
    CboEffect: TComboBox;
    GroupInputShapes: TGroupBox;
    GroupOutputShapes: TGroupBox;
    GroupCube: TGroupBox;
    GroupHaldClut: TGroupBox;
    ImgCLUT: TImage;
    Label1: TLabel;
    Label2: TLabel;
    LblPage: TLabel;
    MainMenu: TMainMenu;
    MenuItemSaveClut: TMenuItem;
    MenuItemExit: TMenuItem;
    MenuItemSaveCube: TMenuItem;
    MenuItemFile: TMenuItem;
    BtnPrior: TSpeedButton;
    BtnNext: TSpeedButton;
    SaveDialog: TSaveDialog;
    SavePictureDialog: TSavePictureDialog;
    SpLevel: TSpinEdit;
    MemoCUBE: TSynEdit;
    StaticText1: TStaticText;
    SynAnySyn: TSynAnySyn;
    procedure BtnNextClick(Sender: TObject);
    procedure BtnPriorClick(Sender: TObject);
    procedure BtnResetClick(Sender: TObject);
    procedure CboEffectSelect(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MenuItemExitClick(Sender: TObject);
    procedure MenuItemSaveClutClick(Sender: TObject);
    procedure MenuItemSaveCubeClick(Sender: TObject);
    procedure SpLevelChange(Sender: TObject);
  private
    FLevel: integer;
    FPage: integer;
    FInData: TRGBSingleDynArray;
    FOutData: TRGBSingleDynArray;
    FInputShapes: TShapeDynArray;
    FOutputShapes: TShapeDynArray;

    procedure InitData;
    procedure UpdateShapes(Page: integer; OldLevel: integer; Created: boolean);
    procedure UpdateMemo;
    procedure UpdateImage;

    function ClampToByteInt(X: single): integer;
    function FlattenCube(Level: integer; B: integer; G: integer; R: integer): integer;
    procedure WriteHaldClut(FileName: string; Data: TRGBSingleDynArray;
      CubeLevel: integer; HaldLevel: integer; TextMode: boolean);
    procedure ShapeMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: integer);
    procedure ChangeEffect;
  public

  end;

var
  FormBuilder: TFormBuilder;

implementation

{$R *.lfm}

{ TFormBuilder }

procedure TFormBuilder.MenuItemExitClick(Sender: TObject);
begin
  Close;
end;

procedure TFormBuilder.MenuItemSaveClutClick(Sender: TObject);
begin
  if SavePictureDialog.Execute then
  begin
    ImgCLUT.Picture.SaveToFile(SavePictureDialog.FileName);
  end;
end;

procedure TFormBuilder.MenuItemSaveCubeClick(Sender: TObject);
begin
  if SaveDialog.Execute then
  begin
    MemoCube.Lines.SaveToFile(SaveDialog.FileName);
  end;
end;

procedure TFormBuilder.SpLevelChange(Sender: TObject);
var
  OldLevel: integer;
begin
  OldLevel := FLevel;
  FLevel := SpLevel.Value;
  if FPage > (FLevel - 1) then
  begin
    FPage := FLevel - 1;
  end;
  LblPage.Caption := Format('Page: %d of %d', [FPage+1, FLevel]);

  SetLength(FInData, FLevel * FLevel * FLevel);
  SetLength(FOutData, FLevel * FLevel * FLevel);
  InitData;
  UpdateShapes(FPage, OldLevel, True);
  UpdateMemo;
  UpdateImage;
  CboEffect.ItemIndex := 0;
end;

procedure TFormBuilder.FormShow(Sender: TObject);
begin
  FLevel := 2;
  FPage := 0;
  SetLength(FInData, FLevel * FLevel * FLevel);
  SetLength(FOutData, FLevel * FLevel * FLevel);
  InitData;
  UpdateShapes(FPage, 0, False);
  UpdateMemo;
  UpdateImage;
  LblPage.Caption := Format('Page: %d of %d', [FPage+1, FLevel]);
end;

procedure TFormBuilder.BtnPriorClick(Sender: TObject);
var
  OldLevel: integer;
begin
  Dec(FPage);
  if FPage < 0 then
  begin
    FPage := 0;
  end;
  LblPage.Caption := Format('Page: %d of %d', [FPage+1, FLevel]);
  OldLevel := FLevel;
  UpdateShapes(FPage, OldLevel, True);
end;

procedure TFormBuilder.BtnResetClick(Sender: TObject);
var
  OldLevel: integer;
  i: integer;
begin
  for i := 0 to Length(FInData) - 1 do
  begin
    FOutData[i] := FInData[i];
  end;

  OldLevel := FLevel;
  UpdateShapes(FPage, OldLevel, True);
  UpdateMemo;
  UpdateImage;
  CboEffect.ItemIndex := 0;
end;

procedure TFormBuilder.CboEffectSelect(Sender: TObject);
begin
  ChangeEffect;
end;

procedure TFormBuilder.BtnNextClick(Sender: TObject);
var
  OldLevel: integer;
begin
  Inc(FPage);
  if FPage > (FLevel - 1) then
  begin
    FPage := FLevel - 1;
  end;
  LblPage.Caption := Format('Page: %d of %d', [FPage+1, FLevel]);
  OldLevel := FLevel;
  UpdateShapes(FPage, OldLevel, True);
end;

procedure TFormBuilder.InitData;
var
  r, g, b, i: integer;
  RGB: TRGBSingle;
begin
  i := 0;
  for b := 0 to FLevel - 1 do
  begin
    for g := 0 to FLevel - 1 do
    begin
      for r := 0 to FLevel - 1 do
      begin
        RGB.R := r / (FLevel - 1);
        RGB.G := g / (FLevel - 1);
        RGB.B := b / (FLevel - 1);
        FINData[i] := RGB;
        FOutData[i] := RGB;
        Inc(i);
      end;
    end;
  end;
end;

procedure TFormBuilder.UpdateShapes(Page: integer; OldLevel: integer; Created: boolean);
var
  r, g, i: integer;
  RGB: TRGBSingle;
  C: TColor;
begin
  if Created then
  begin
    for i := 0 to OldLevel * OldLevel - 1 do
    begin
      FInputShapes[i].Free;
      FOutputShapes[i].Free;
    end;
  end;

  SetLength(FInputShapes, FLevel * FLevel);
  SetLength(FOutputShapes, FLevel * FLevel);

  i := 0;
  for g := 0 to FLevel - 1 do
  begin
    for r := 0 to FLevel - 1 do
    begin
      RGB := FInData[Page * FLevel * FLevel + i];
      C := RGBToColor(Round(RGB.R * 255), Round(RGB.G * 255), Round(RGB.B * 255));
      FInputShapes[i] := TShape.Create(nil);
      FInputShapes[i].Width := Round(260 / (FLevel));
      FInputShapes[i].Height := Round(230 / (FLevel));
      FInputShapes[i].Left := 100 + r * FInputShapes[i].Width;
      FInputShapes[i].Top := 8 + g * FInputShapes[i].Height;
      FInputShapes[i].Brush.Color := C;
      FInputShapes[i].Parent := GroupInputShapes;
      FInputShapes[i].Tag := i;
      FInputShapes[i].ShowHint := True;
      FInputShapes[i].Hint := Format('R=%d, G=%d, B=%d', [Red(C), Green(C), Blue(C)]);
      FInputShapes[i].OnMouseDown := @ShapeMouseDown;
      FInputShapes[i].Show;

      RGB := FOutData[Page * FLevel * FLevel + i];
      C := RGBToColor(Round(RGB.R * 255), Round(RGB.G * 255), Round(RGB.B * 255));
      FOutputShapes[i] := TShape.Create(nil);
      FOutputShapes[i].Width := Round(260 / (FLevel));
      FOutputShapes[i].Height := Round(230 / (FLevel));
      FOutputShapes[i].Left := 100 + r * FOutputShapes[i].Width;
      FOutputShapes[i].Top := 8 + g * FOutputShapes[i].Height;
      FOutputShapes[i].Brush.Color := C;
      FOutputShapes[i].Parent := GroupOutputShapes;
      FOutputShapes[i].Tag := i;
      FOutputShapes[i].ShowHint := True;
      FOutputShapes[i].Hint := Format('R=%d, G=%d, B=%d', [Red(C), Green(C), Blue(C)]);
      FOutputShapes[i].Show;

      Inc(i);
    end;
  end;

end;

procedure TFormBuilder.UpdateMemo;
var
  i: integer;
  RGB: TRGBSingle;
  List: TStringList;
begin
  List := TStringList.Create;
  List.Add('TITLE "MYLUT"');
  List.Add('DOMAIN_MIN 0 0 0');
  List.Add('DOMAIN_MAX 1 1 1');
  List.Add('LUT_3D_SIZE ' + IntToStr(FLevel));
  for i := 0 to Length(FOutData) - 1 do
  begin
    RGB := FOutData[i];
    List.Add(StringReplace(Format('%.9f %.9f %.9f', [RGB.R, RGB.G, RGB.B]),
      ',', '.', [rfReplaceAll]));
  end;
  MemoCube.Text := List.Text;
  List.Free;
end;

procedure TFormBuilder.UpdateImage;
begin
  WriteHaldClut('tmp.ppm', FOutData, FLevel, FLevel, False);
  ImgCLUT.Picture.LoadFromFile('tmp.ppm');
  if FileExists('tmp.ppm') then
  begin
    DeleteFile('tmp.ppm');
  end;
end;

function TFormBuilder.ClampToByteInt(X: single): integer;
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

function TFormBuilder.FlattenCube(Level: integer; B: integer;
  G: integer; R: integer): integer;
begin
  Result := B * Level * Level + G * Level + R;
end;

procedure TFormBuilder.WriteHaldClut(FileName: string; Data: TRGBSingleDynArray;
  CubeLevel: integer; HaldLevel: integer; TextMode: boolean);
var
  r, g, b: integer;
  PR, PG, PB, PN: integer;
  IndexR, IndexG, IndexB: integer;
  NextR, NextG, NextB: integer;
  OffsetR, OffsetG, OffsetB: single;
  ScaleR, ScaleG, ScaleB: single;
  FileHandle: TextFile;
begin
  AssignFile(FileHandle, FileName);
  try
    Rewrite(FileHandle);
    if TextMode then
      Write(FileHandle, 'P3' + #10)
    else
      Write(FileHandle, 'P6' + #10);
    Write(FileHandle, '# Created by cube2ppm' + #10);
    Write(FileHandle, Format('%d %d', [HaldLevel * HaldLevel * HaldLevel,
      HaldLevel * HaldLevel * HaldLevel]) + #10);
    Write(FileHandle, '255' + #10);

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
            Write(FileHandle, Format('%d %d %d ', [PR, PG, PB]));
            PN := PN + 1;
            if PN = 15 then
            begin
              Write(FileHandle, #10);
              PN := 0;
            end;
          end
          else
          begin
            Write(FileHandle, char(PR));
            Write(FileHandle, char(PG));
            Write(FileHandle, char(PB));
          end;
        end;
      end;
    end;

  finally
    CloseFile(FileHandle);
  end;
end;

procedure TFormBuilder.ShapeMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: integer);
var
  i: integer;
  j: integer;
  C: TColor;
  R, G, B: byte;
  RGB: TRGBSingle;
begin
  i := TShape(Sender).Tag;
  j := FPage * FLevel * FLevel + i;
  ColorDialog.Color := FInputShapes[i].Brush.Color;
  if ColorDialog.Execute then
  begin
    C := ColorDialog.Color;
    FOutputShapes[i].Brush.Color := C;
    R := Red(C);
    G := Green(C);
    B := Blue(C);
    RGB.R := R / 255;
    RGB.G := G / 255;
    RGB.B := B / 255;
    FOutData[j] := RGB;

    UpdateMemo;
    UpdateImage;
    CboEffect.ItemIndex := 0;
  end;
end;

procedure TFormBuilder.ChangeEffect;
var
  i: integer;
  Y: single;
  RGB: TRGBSingle;
  OldLevel: integer;
  FUpdate: boolean;
begin
  FUpdate := False;
  OldLevel := FLevel;
  case CboEffect.ItemIndex of
    1: // negative
    begin
      for i := 0 to Length(FInData) - 1 do
      begin
        RGB := FInData[i];
        RGB.R := 1 - RGB.R;
        RGB.G := 1 - RGB.G;
        RGB.B := 1 - RGB.B;
        FOutData[i] := RGB;
        FUpdate := true;
      end;
    end;
    2: // grayscale
    begin
      for i := 0 to Length(FInData) - 1 do
      begin
        RGB := FInData[i];
        Y := 0.299 * RGB.R + 0.587 * RGB.G + 0.114 * RGB.B;
        RGB.R := Y;
        RGB.G := Y;
        RGB.B := Y;
        FOutData[i] := RGB;
        FUpdate := true;
      end;
    end;
  end;

  if FUpdate then
  begin
    UpdateShapes(FPage, OldLevel, True);
    UpdateMemo;
    UpdateImage;
  end;
end;

end.
