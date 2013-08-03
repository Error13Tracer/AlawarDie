program AlawarDie;

uses
  Windows, Messages, Alawar, OpenFileDlg, Utils, ColorBtn, uFMOD;

{$R AlawarDie.RES}
{$I Sound.inc}

const
  SC_DRAGMOVE           = $F012;
  clBackground          = $3B40D0;
  clText                = $FFFFFF;
  WndClassName          = 'AlawarDie';
  ButtonClassName       = 'Button';
  StaticClassName       = 'Static';
  REGISTRATION_RADIOBTN = 0;
  RESET_TRIAL_RADIOBTN  = 1;
  CRACK_GAME_RADIOBTN   = 2;
  NOT_SUPPORTED_VERSION = 8;
  PROGRAM_NAME          = 'AlawarDie v2.1';
  COPYRIGHT_TEXT        = '['+PROGRAM_NAME+'] by Error13Tracer';
  UNKNOWN_ERROR         = 'Unknown error';
  SUCCESSFULLY          = 'Successfully!';
  ERRORS: array [1..8] of PChar =
  ('File not found!',
   'Can''t open file!',
   'Invalid PE file!',
   'Is not ''Alawar'' file!',
   'Can''t execute file!',
   'File is corrupted!',
   'Can''t replace original file!',
   'Version not supported!');
  SUCCESSFULLYS: array [0..2] of PChar =
  ('Game successfully registered!',
   'Trial successfully reset!',
   'Game successfully cracked!');
   
var
  Alw      : TAlawar;
  MX       : DWORD;
  Inst     : THandle;
  WndClass : TWndClass;
  Msg      : TMsg;
  Brush    : HBRUSH;
  Font     : HFONT;
  WndHandle: HWND;
  TtlLabel : HWND;
  CprLabel : HWND;
  RegGRBtn : HWND;
  ResTRBtn : HWND;
  CrkGRBtn : HWND;
  StartBtn : TColorBtn;
  CloseBtn : TColorBtn;
  AboutBtn : TColorBtn;

procedure AlphaBlend(hWin: HWND; Active: BOOL; Value: BYTE);
begin
  if Active then begin
    SetWindowLong(hWin, GWL_EXSTYLE, GetWindowLong(hWin, GWL_EXSTYLE) or WS_EX_LAYERED);
    SetLayeredWindowAttributes(hWin, 0, Value, LWA_ALPHA);
  end else
    SetWindowLong(hWin, GWL_EXSTYLE, GetWindowLong(hWin, GWL_EXSTYLE) xor WS_EX_LAYERED);
end;

procedure AboutBtnClick;
begin
  MessageBox(WndHandle,PChar(PROGRAM_NAME+
   #13#10'Coded by Error13Tracer'#13#10#13#10+
   'Site: AlawarDie.hut.ru'#13#10+
   'Email: AlawarDie@gmail.com'),
   'About...',MB_ICONINFORMATION);
end;  

function Checked(WndHndl: DWORD):BOOL;
begin
  Result:=(SendMessage(WndHndl,BM_GETCHECK,0,0)=1);
end;

procedure ShowSuccessfully(SuccessfullyID: DWORD);
const
  szFinish = 'Finish';
begin
  if SuccessfullyID in [0..3] then
    MessageBox(WndHandle,SUCCESSFULLYS[SuccessfullyID],szFinish,MB_ICONINFORMATION)
  else
    MessageBox(WndHandle,SUCCESSFULLY,szFinish,MB_ICONINFORMATION);
end;

procedure ShowError(ErrorID: DWORD);
const
  szError = 'Error';
begin
  if ErrorID in [1..NOT_SUPPORTED_VERSION] then
    MessageBox(WndHandle,ERRORS[ErrorID],szError,MB_ICONERROR)
  else
    MessageBox(WndHandle,UNKNOWN_ERROR,szError,MB_ICONERROR);
end;

function ReadAlawarDieData: BOOL;
const
  AlawarDieData = 'AlawarDie.dat';
var
  f: File of TAlawarVerStruct;
  AVS: TAlawarVerStruct;
begin
  Result:=False;
  try
    AssignFile(f,ExtractFilePath(ParamStr(0))+AlawarDieData);
    if not FileExists(ExtractFilePath(ParamStr(0))+AlawarDieData) then
      Rewrite(f)
    else
      Reset(f);
    while not Eof(f) do
    begin
      Read(f,AVS);
      if AVS.Version=Alw.GetWrapperVersion then
      begin
        Alw.ChangeAlawarData(AVS);
        Result:=True;
        break;
      end;
    end;
  finally
    CloseFile(f);
  end;
end;

procedure StartBtnClick;
var
  lpFileName: string;
begin
  lpFileName:=FileOpenDlg(WndHandle,COPYRIGHT_TEXT,'Alawar files (*.exe)'#0'*.EXE');
  if not FileExists(lpFileName) then
    Exit;
  Alw:=TAlawar.Create;
  try
    if Alw.GrabInfo(PChar(lpFileName)) then
    begin
      if ReadAlawarDieData then
      begin
        if Checked(RegGRBtn) then
          if Alw.RegisterGame then
            ShowSuccessfully(REGISTRATION_RADIOBTN)
          else
            ShowError(Alw.GetLastError)
        else if Checked(ResTRBtn) then
          if Alw.RestoreTrial then
            ShowSuccessfully(RESET_TRIAL_RADIOBTN)
          else
            ShowError(Alw.GetLastError)
        else if Checked(CrkGRBtn) then
          if Alw.CrackGame then
          begin
            if (MessageBox(WndHandle,
             'Replace loader? (recomended)', 'Confirmation',
             MB_ICONQUESTION or MB_YESNO)=idYes) then
              if not Alw.ReplaceOriginalFile then
                ShowError(Alw.GetLastError)
              else
                ShowSuccessfully(CRACK_GAME_RADIOBTN)
            else
              ShowSuccessfully(CRACK_GAME_RADIOBTN);
          end else
            ShowError(Alw.GetLastError);
      end else ShowError(NOT_SUPPORTED_VERSION);
    end else ShowError(Alw.GetLastError);
  finally
    Alw.Free;
  end;
end;

procedure ShutDown;
begin
  StartBtn.Free;
  AboutBtn.Free;
  CloseBtn.Free;
  DeleteObject(Font);
  UnRegisterClass(WndClassName, Inst);
  uFMOD_StopSong;
  ExitProcess(Inst);
end;

procedure CloseBtnClick;
begin
  ShutDown;
end;

procedure CreateBtns;
var
  BtnFont: tagLOGFONT;
begin
  ZeroMemory(@BtnFont,SizeOf(BtnFont));
  with BtnFont do
  begin
    lfFaceName       := 'Terminal';
    lfHeight         := 8;
    lfWidth          := 8;
    lfCharSet        := DEFAULT_CHARSET;
    lfQuality        := DEFAULT_QUALITY;
    lfClipPrecision  := CLIP_DEFAULT_PRECIS;
    lfOutPrecision   := OUT_DEFAULT_PRECIS;
    lfPitchAndFamily := DEFAULT_PITCH or FF_DONTCARE;
  end;
  StartBtn := TColorBtn.Create(WndHandle);
  with StartBtn do
  begin
    Left        := 194;
    Top         := 42;
    Height      := 20;
    Width       := 60;
    BorderSize  := 2;
    Caption     := 'START';
    Font        := BtnFont;
    FontColor   := clText;
    DefaultColor:= $3B40D0;
    ActiveColor := $3B40F0;
    PressedColor:= $3B40B0;
    OnClick     := DWORD(@StartBtnClick);
  end;
  AboutBtn := TColorBtn.Create(WndHandle);
  with AboutBtn do
  begin
    Left        := 194;
    Top         := 66;
    Height      := 20;
    Width       := 60;
    BorderSize  := 2;
    Caption     := 'ABOUT';
    Font        := BtnFont;
    FontColor   := clText;
    DefaultColor:= $3B40D0;
    ActiveColor := $3B40F0;
    PressedColor:= $3B40B0;
    OnClick     := DWORD(@AboutBtnClick);
  end;
  CloseBtn := TColorBtn.Create(WndHandle);
  with CloseBtn do
  begin
    Left        := 194;
    Top         := 90;
    Height      := 20;
    Width       := 60;
    BorderSize  := 2;
    Caption     := 'CLOSE';
    Font        := BtnFont;
    FontColor   := clText;
    DefaultColor:= $3B40D0;
    ActiveColor := $3B40F0;
    PressedColor:= $3B40B0;
    OnClick     := DWORD(@CloseBtnClick);
  end;
  Font := CreateFontIndirect(BtnFont);
  SendMessage(RegGRBtn, WM_SETFONT, Font, 0);
  SendMessage(ResTRBtn, WM_SETFONT, Font, 0);
  SendMessage(CrkGRBtn, WM_SETFONT, Font, 0);
  SendMessage(TtlLabel, WM_SETFONT, Font, 0);
  SendMessage(CprLabel, WM_SETFONT, Font, 0);
end;

procedure CentreWindow(hWin: HWND; ParentWnd: HWND; TopMost: BOOL);
var
  Params : HWND;
  ScrRect: TRect;
  WndRect: TRect;
begin
  GetWindowRect(ParentWnd, ScrRect);
  GetWindowRect(hWin, WndRect);
  with ScrRect do
  begin
    Left := Round((Right-WndRect.Right)/2);
    Top  := Round((Bottom-WndRect.Bottom)/2);
  end;
  if TopMost then
    Params := HWND_TOPMOST
  else
    Params := 0;
  SetWindowPos(hWin, Params, ScrRect.Left,
   ScrRect.Top, 0, 0, SWP_NOSIZE);
end;

function WindowProc(hWin, uMsg,	wParam,	lParam: DWORD): Integer; stdcall;
begin
  Result := DefWindowProc(hWin, uMsg, wParam, lParam);
  if uMsg = WM_CTLCOLORSTATIC then
  begin
    SetTextColor(wParam,clText);
    SetBkMode(wParam,TRANSPARENT);
    Result:=Brush;
  end;
  if uMsg=WM_LBUTTONDOWN then
  begin
    ReleaseCapture;
    SendMessage(hWin, WM_SYSCOMMAND, SC_DRAGMOVE, 0);
  end;
  if (uMsg = WM_MOUSEMOVE) then
  begin
    StartBtn.Deactivate;
    CloseBtn.Deactivate;
    AboutBtn.Deactivate;
  end;
  if (uMsg = WM_DESTROY)or(uMsg = WM_CLOSE) then
    CloseBtnClick;
end;

function Check: BOOL;
begin
	MX     := OpenMutex(MUTEX_ALL_ACCESS, False, PROGRAM_NAME);
	Result := (MX<>0);
	if MX = 0 then
		MX :=CreateMutex(nil, False, PROGRAM_NAME);
end;

begin
  if Check then Exit;
  Inst := hInstance;
  uFMOD_PlaySong(@xm, Length(xm), XM_MEMORY);
  Brush:=CreateSolidBrush(clBackground);
  with WndClass do
  begin
    style         := DS_SETFOREGROUND;
    lpfnWndProc   := @WindowProc;
    hInstance     := Inst;
    hbrBackground := Brush;
    lpszClassName := WndClassName;
    hCursor       := LoadCursor(0, IDC_ARROW);
    hIcon         := LoadIcon(Inst, IDI_APPLICATION);
  end;
  RegisterClass(WndClass);
  WndHandle := CreateWindowEx(WS_EX_TOPMOST, WndClassName, PROGRAM_NAME,
   WS_POPUP, 0, 0, 285, 150, 0, 0, Inst, nil);
  CentreWindow(WndHandle, GetDesktopWindow, True);
  AlphaBlend(WndHandle, True, 200);
  TtlLabel := CreateWindow(StaticClassName, PROGRAM_NAME, WS_VISIBLE or WS_CHILD or SS_CENTER,
   85, 15, 120, 20, WndHandle, 0, Inst, nil);
  CprLabel := CreateWindow(StaticClassName, 'Coded by '#13#10'Error13Tracer',
   WS_VISIBLE or WS_CHILD or SS_CENTER or BS_MULTILINE,
   85, 120, 120, 20, WndHandle, 0, Inst, nil);
  RegGRBtn := Createwindow(ButtonClassName, 'REGISTER GAME', BS_AUTORADIOBUTTON
   or WS_VISIBLE or BS_LEFT or WS_CHILD or BS_VCENTER or BS_FLAT, 30, 42,
   150, 20, WndHandle, 0, Inst, nil);
  ResTRBtn := Createwindow(ButtonClassName, 'CLEAN TRIAL', BS_AUTORADIOBUTTON
   or WS_VISIBLE or BS_LEFT or WS_CHILD or BS_VCENTER or BS_FLAT, 30, 66,
   150, 20, WndHandle, 0, Inst, nil);
  CrkGRBtn := Createwindow(ButtonClassName, 'CRACK GAME', BS_AUTORADIOBUTTON or
   WS_VISIBLE or BS_LEFT or WS_CHILD or BS_VCENTER or BS_FLAT, 30, 90, 120,
   20, WndHandle, 0, Inst, nil);
  SendMessage(RegGRBtn, BM_SETCHECK, DWord(True), 0);
  CreateBtns;
  SetWindowRgn(WndHandle, CreateEllipticRgn(0, 0, 285, 150), True);
  ShowWindow(WndHandle, SW_SHOWNORMAL);
  UpdateWindow(WndHandle);
  while(GetMessage(Msg, WndHandle, 0, 0)) do
  begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;
end.
