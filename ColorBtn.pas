unit ColorBtn;
(*
ColorBtn v1.0 (Pure WinAPI)
Date: 28.01.2010
Author: Error13Tracer
*) 
interface

uses
  Windows, Messages;

const
  WM_MOUSELEAVE = WM_USER+$0D;
(*
In other controls on message WM_MOUSEMOVE use
SendMessage(ColorBtn.Handle,WM_MOUSELEAVE,0,0);
or
ColorBtn.Deactivate;
*)
type
  TColor    = DWORD;
  TBtnState = (bsDefault, bsActive, bsPressed);
  TOnClick  = procedure;
  TColorBtn = class(TObject)
  protected
    _Active       : BOOL;
    _DefBrushColor: TColor;
    _ActBrushColor: TColor;
    _PrsBrushColor: TColor;
    _BrdPenColor  : TColor;
    _FontColor    : TColor;
    _Font         : tagLOGFONT;
    _BrdSize      : Integer;
    _DefBrush     : HBRUSH;
    _ActBrush     : HBRUSH;
    _PrsBrush     : HBRUSH;
    _BrdPen       : HPEN;
    _TextFont     : HFONT;
    _hInstance    : DWORD;
    _WndClass     : TWndClass;
    _Parent       : HWND;
    _Handle       : HWND;
    _DC           : HDC;
    _Rect         : TRect;
    _Caption      : string;
    _State        : TBtnState;
    _OnClick      : TOnClick;
    procedure SetParentWnd(Value: HWND);
    procedure SetLeft(Value: Integer);
    procedure SetTop(Value: Integer);
    procedure SetHeight(Value: Integer);
    procedure SetWidth(Value: Integer);
    function  GetHeight: Integer;
    function  GetWidth: Integer;
    procedure SetFont(Value: tagLOGFONT);
    procedure DrawBtn(State: TBtnState);
    procedure SetDefColor(Value: TColor);
    procedure SetActColor(Value: TColor);
    procedure SetPrsColor(Value: TColor);
    procedure SetBrdColor(Value: TColor);
    procedure SetFntColor(Value: TColor);
    procedure SetBrdSize(Value: Integer);
    procedure SetCaption(Value: String);
    procedure OnClickProc(Value: DWORD);
    function  GetOnClickProc: DWORD;
  public
    constructor Create(Parent: HWND);
    destructor  Destroy; override;
    procedure   Deactivate;
    procedure   Redraw;
  published
    property Handle      : HWND       read _Handle;
    property ButtonState : TBtnState  read _State;
    property OnClick     : DWORD      read GetOnClickProc write OnClickProc;
    property Caption     : String     read _Caption       write SetCaption;
    property Parent      : HWND       read _Parent        write SetParentWnd;
    property Left        : Integer    read _Rect.Left     write SetLeft;
    property Top         : Integer    read _Rect.Top      write SetTop;
    property Height      : Integer    read GetHeight      write SetHeight;
    property Width       : Integer    read GetWidth       write SetWidth;
    property Font        : tagLOGFONT read _Font          write SetFont;
    property DefaultColor: TColor     read _DefBrushColor write SetDefColor;
    property ActiveColor : TColor     read _ActBrushColor write SetActColor;
    property PressedColor: TColor     read _PrsBrushColor write SetPrsColor;
    property BorderColor : TColor     read _BrdPenColor   write SetBrdColor;
    property FontColor   : TColor     read _FontColor     write SetFntColor;
    property BorderSize  : Integer    read _BrdSize       write SetBrdSize;
  end;
implementation

const
  ColorBtnClassName = 'ColorBtn';
var
  ColorBtnsCount: Integer = 0;
  ColorBtns     : array of TColorBtn;

function ColorBtnProc(hWin, uMsg,	wParam,	lParam: DWORD): Integer; stdcall;
  function GetBtnID: Integer;
  var
    i: Integer;
  begin
    Result:=-1;
    for i:=0 to Pred(ColorBtnsCount) do
      if ColorBtns[i].Handle=hWin then
        Result:=i
      else
        ColorBtns[i].Deactivate;
  end;
var
  BtnID: Integer;
begin
  Result:=DefWindowProc(hWin, uMsg, wParam, lParam);
  case uMsg of
    WM_MOUSEMOVE,
    WM_LBUTTONDOWN,
    WM_LBUTTONUP,
    WM_MOUSELEAVE,
    WM_PAINT:
    begin
      BtnID:=GetBtnID;
      if BtnID=-1 then Exit;
    end else BtnID:=-1;
  end;
  if uMsg = WM_MOUSELEAVE then
    ColorBtns[BtnID].Deactivate;
  if uMsg = WM_MOUSEMOVE then
  begin
    ColorBtns[BtnID]._Active:=True;
    if ColorBtns[BtnID]._State<>bsPressed then
      ColorBtns[BtnID].DrawBtn(bsActive);
  end;
  if uMsg = WM_LBUTTONDOWN then
    ColorBtns[BtnID].DrawBtn(bsPressed);
  if uMsg = WM_LBUTTONUP then
  begin
    ColorBtns[BtnID].DrawBtn(bsActive);
    if (ColorBtns[BtnID]._State<>bsPressed)
     and(@ColorBtns[BtnID]._OnClick<>nil) then
      ColorBtns[BtnID]._OnClick;
  end;
  if uMsg = WM_PAINT then
    ColorBtns[BtnID].Redraw;
end;

procedure TColorBtn.Redraw;
var
  tmp: TBtnState;
begin
  tmp:=_State;
  case _State of
    bsActive, bsPressed: _State:=bsDefault;
    else
      _State:=bsActive;
  end;
  DrawBtn(tmp);
end;

procedure TColorBtn.Deactivate;
begin
  try
    if not _Active then Exit;
    _Active := False;
    _State  := bsDefault;
    Redraw;
  except end;
end;

procedure TColorBtn.DrawBtn(State: TBtnState);
var
  ABrushCl: TColor;
  APenCl  : TColor;
  ABrush  : HBRUSH;
  APen    : HPEN;
  ARect   : TRect;
begin
  if _State = State then Exit;
  GetClientRect(_Handle, ARect);
  _State := State;
  APen   := _BrdPen;
  APenCl := _FontColor;
  case _State of
    bsActive: begin
      ABrush   := _ActBrush;
      ABrushCl := _ActBrushColor;
    end;
    bsPressed: begin
      ABrush   := _PrsBrush;
      ABrushCl := _PrsBrushColor;
    end;
    else{bsDefault:} begin
      ABrush   := _DefBrush;
      ABrushCl := _DefBrushColor;
    end;
  end;
  SetBkColor(_DC, ABrushCl);
  SetTextColor(_DC, APenCl);
  FillRect(_DC,ARect, ABrush);
  SelectObject(_DC, _TextFont);
  SelectObject(_DC, APen);
  SetBkMode(_DC, TRANSPARENT);
  DrawText(_DC, PChar(_Caption), -1, ARect,
   DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  MoveToEx(_DC, ARect.Left, ARect.Top, nil);
  LineTo(_DC, ARect.Right, ARect.Top);
  LineTo(_DC, ARect.Right, ARect.Bottom);
  LineTo(_DC, ARect.Left, ARect.Bottom);
  LineTo(_DC, ARect.Left, ARect.Top);
end;

procedure TColorBtn.OnClickProc(Value: DWORD);
begin
  try
    if Value <> 0 then
    asm
      push eax
      mov eax,Value
      mov eax,[eax]
      pop eax
    end;
    _OnClick := Pointer(Value);
  except
    _OnClick := nil;
  end;
end;

function  TColorBtn.GetOnClickProc: DWORD;
begin
  Result:=DWORD(@_OnClick);
end;

{============Change button style============}

procedure TColorBtn.SetCaption(Value: String);
begin
  _Caption:=Value;
  Redraw;
end;

procedure TColorBtn.SetFont(Value: tagLOGFONT);
begin
  DeleteObject(_TextFont);
  _TextFont:=CreateFontIndirect(Value);
  if _TextFont=0 then
    _TextFont:=CreateFontIndirect(_Font)
  else
    _Font:=Value;
  Redraw;
end;

procedure TColorBtn.SetFntColor(Value: TColor);
begin
  _FontColor:=Value;
  Redraw;
end;

procedure TColorBtn.SetDefColor(Value: TColor);
begin
  DeleteObject(_DefBrush);
  _DefBrush:=CreateSolidBrush(Value);
  if _DefBrush=0 then
    _DefBrush:=CreateSolidBrush(_DefBrushColor)
  else
    _DefBrushColor:=Value;
  Redraw;
end;

procedure TColorBtn.SetActColor(Value: TColor);
begin
  DeleteObject(_ActBrush);
  _ActBrush:=CreateSolidBrush(Value);
  if _ActBrush=0 then
    _ActBrush:=CreateSolidBrush(_ActBrushColor)
  else
    _ActBrushColor:=Value;
  Redraw;
end;

procedure TColorBtn.SetPrsColor(Value: TColor);
begin
  DeleteObject(_PrsBrush);
  _PrsBrush:=CreateSolidBrush(Value);
  if _PrsBrush=0 then
    _PrsBrush:=CreateSolidBrush(_PrsBrushColor)
  else
    _PrsBrushColor:=Value;
  Redraw;
end;

procedure TColorBtn.SetBrdColor(Value: TColor);
begin
  DeleteObject(_BrdPen);
  _BrdPen:=CreatePen(PS_SOLID, _BrdSize, Value);
  if _BrdPen=0 then
    _BrdPen:=CreatePen(PS_SOLID, _BrdSize, _BrdPenColor)
  else
    _BrdPenColor:=Value;
  Redraw;
end;

procedure TColorBtn.SetBrdSize(Value: Integer);
begin
  if Value mod 2 = 1 then Inc(Value);
  DeleteObject(_BrdPen);
  _BrdPen:=CreatePen(PS_SOLID, Value, Value);
  if _BrdPen=0 then
    _BrdPen:=CreatePen(PS_SOLID, _BrdSize, _BrdPenColor)
  else
    _BrdSize:=Value;
  Redraw;
end;

{========Change button position and size========}

procedure TColorBtn.SetParentWnd(Value: HWND);
begin
  _Parent:=SetParent(_Handle,Value);
  Redraw;
end;

procedure TColorBtn.SetLeft(Value: Integer);
begin
  _Rect.Right:=Value+_Rect.Right-_Rect.Left;
  _Rect.Left:=Value;
  SetWindowPos(_Handle,0,_Rect.Left, _Rect.Top, GetWidth, GetHeight, 0);
  Redraw;
end;

procedure TColorBtn.SetTop(Value: Integer);
begin
  _Rect.Bottom:=Value+_Rect.Bottom-_Rect.Top;
  _Rect.Top:=Value;
  SetWindowPos(_Handle,0,_Rect.Left, _Rect.Top, GetWidth, GetHeight, 0);
  Redraw;
end;

procedure TColorBtn.SetWidth(Value: Integer);
begin
  _Rect.Right:=Value+_Rect.Left;
  SetWindowPos(_Handle,0,_Rect.Left, _Rect.Top, Value, GetHeight, 0);
  Redraw;
end;

procedure TColorBtn.SetHeight(Value: Integer);
begin
  _Rect.Bottom:=Value+_Rect.Top;
  SetWindowPos(_Handle,0,_Rect.Left, _Rect.Top, GetWidth, Value, 0);
  Redraw;
end;

function TColorBtn.GetWidth: Integer;
begin
  Result:=_Rect.Right-_Rect.Left;
end;

function TColorBtn.GetHeight: Integer;
begin
  Result:=_Rect.Bottom-_Rect.Top;
end;

{========Object creation and register class========}

constructor TColorBtn.Create(Parent: HWND);
var
  ClassRegistered: BOOL;
  TmpClass       : TWndClass;
begin
  _hInstance := GetModuleHandle(nil);
  _OnClick   := nil;
  _Active    := True;
  Inc(ColorBtnsCount);
  SetLength(ColorBtns,ColorBtnsCount);
  ColorBtns[Pred(ColorBtnsCount)]:=Self;
  if Parent = 0 then
    Parent := GetDesktopWindow;
  _Parent  := Parent;
  _State   := bsDefault;
  _Caption := ColorBtnClassName;
  with _Rect do
  begin
    Left   := 0;
    Top    := 0;
    Right  := 75;
    Bottom := 25;
  end;
  ClassRegistered := GetClassInfo(_hInstance,ColorBtnClassName,TmpClass);
  if (not ClassRegistered)or(TmpClass.lpfnWndProc<>@ColorBtnProc) then
  begin
    if ClassRegistered then
      UnRegisterClass(ColorBtnClassName,_hInstance);
    with _WndClass do
    begin
      hInstance     := _hInstance;
      lpfnWndProc   := @ColorBtnProc;
      hbrBackground := color_btnface+1;
      lpszClassName := ColorBtnClassName;
      hCursor       := LoadCursor(0, IDC_ARROW);
      hIcon         := LoadIcon(_hInstance, IDI_APPLICATION);
    end;
    RegisterClass(_WndClass);
  end;
  _Handle := CreateWindow(ColorBtnClassName, nil, WS_VISIBLE or WS_CHILD,
   _Rect.Left, _Rect.Top, GetWidth, GetHeight, _Parent, 0, _hInstance, nil);
  _DC     := GetDC(_Handle);
  ZeroMemory(@_Font,SizeOf(_Font));
  with _Font do
  begin
    lfFaceName       := 'MS Sans Serif';
    lfHeight         := -11;
    lfCharSet        := DEFAULT_CHARSET;
    lfQuality        := DEFAULT_QUALITY;
    lfClipPrecision  := CLIP_DEFAULT_PRECIS;
    lfOutPrecision   := OUT_DEFAULT_PRECIS;
    lfPitchAndFamily := DEFAULT_PITCH or FF_DONTCARE;
  end;
  _BrdSize       := 1;
  _DefBrushColor := $00F0F0F0;
  _ActBrushColor := $00D0D0D0;
  _PrsBrushColor := $00B0B0B0;
  _BrdPenColor   := $00000000;
  _FontColor     := $00000000;
  _DefBrush :=  CreateSolidBrush(_DefBrushColor);
  _ActBrush :=  CreateSolidBrush(_ActBrushColor);
  _PrsBrush :=  CreateSolidBrush(_PrsBrushColor);
  _BrdPen   :=  CreatePen(PS_SOLID, _BrdSize, _BrdPenColor);
  _TextFont :=  CreateFontIndirect(_Font);
  Redraw;
end;

destructor TColorBtn.Destroy;
var
  i: Integer;
  Found: BOOL;
begin
  Found := False;
  for i:=0 to Pred(ColorBtnsCount) do
    if Found then
      ColorBtns[i] := ColorBtns[i-1]
    else
      if ColorBtns[i] = Self then
        Found := True;
  if Found then
  begin
    Dec(ColorBtnsCount);
    SetLength(ColorBtns,ColorBtnsCount);
  end;
  DeleteObject(_TextFont);
  DeleteObject(_BrdPen);
  DeleteObject(_PrsBrush);
  DeleteObject(_ActBrush);
  DeleteObject(_DefBrush);
  DestroyWindow(_Handle);
  if FindWindow(ColorBtnClassName,nil)=0 then
    UnRegisterClass(ColorBtnClassName,_hInstance);
  inherited;
end;

end.

