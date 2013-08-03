unit Alawar;

interface

uses
  Windows;

type
  TAlawarVerStruct = record
    Version                : DWORD;
    StolenBytesRVAOffset   : WORD;
    StolenBytesOffset      : WORD;
    StolenBytesCountOffset : WORD;
    GameFileOffset         : WORD;
    TrialTimeOffset        : WORD;
    TrialKeyOffset         : WORD;
    GameKeyOffset          : WORD;
    Reserved               : WORD;
  end;
  TAlawarData = record
    StolenBytesRVA  : DWORD;
    StolenBytes     : Pointer;
    StolenBytesCount: BYTE;
    GameFile        : Pointer;
    TrialTime       : BYTE;
    TrialKey        : Pointer;
    GameKey         : Pointer;
  end;
  {Name: TSmsKey, Size: 0x400, Resource: RT_RCDATA->SMSKEY}
  TSmsKey = array [0..$3FF] of BYTE; //SMSKEY start: offset 0x01, end: char 0x00
  {Name: TPackInfo, Size: 0x1000, Resource: RT_RCDATA->PACKINFO}
  TPackInfo = array [0..$FFF] of BYTE;
  TAlawar = class(TObject)
  private
    LastError   : BYTE;
    Openned     : BOOL;
    PackInfoVA  : DWORD;
    SmsKeyVA    : DWORD;
    WrapperVer  : DWORD;
    FileName    : string;
    FilePath    : string;
    SmsKeyBuf   : TSmsKey;
    PackInfoBuf : TPackInfo;
    AlawarData  : TAlawarData;
    SI          : TStartupInfo;
    PI          : TProcessInformation;
    function    IsAlawarFile: BOOL;
    function    GrabAlawarInfo: BOOL;
    function    FindRes(ResName, ResType: PAnsiChar): DWORD;
  public
    constructor Create;
    procedure   ChangeAlawarData(AVS: TAlawarVerStruct);
    function    RestoreTrial: BOOL;
    function    RegisterGame: BOOL;
    function    CrackGame: BOOL;
    function    GetWrapperVersion  : DWORD;
    function    GrabInfo(szFileName: string): BOOL;
    function    ReplaceOriginalFile: BOOL;
  published
    property GetLastError: BYTE read LastError;
  end;
const
  FILE_NOT_FOUND        = 1;
  CANT_OPEN_FILE        = 2;
  INVALID_PE_FILE       = 3;
  IS_NOT_ALAWAR_FILE    = 4;
  CANT_EXECUTE_FILE     = 5;
  FILE_CORRUPTED        = 6;
  FILE_NOT_REPLACED     = 7;

implementation

uses Utils;

const
  ResType          = 'RT_RCDATA';
  ResNamePackInfo  = 'PACKINFO';
  ResNameSmsKey    = 'SMSKEY';
  WrapperWndClass  = 'WrapperWND';
  RegTrialValue    = 'Program';
  RegRegisterValue = 'Key';

procedure TAlawar.ChangeAlawarData(AVS: TAlawarVerStruct);

function GetNextNotNullByte(PIBVA,OFS: DWORD): DWORD; assembler;
asm
  pushad
  mov ebx, PIBVA
  add ebx, OFS
  dec ebx
@next:
  inc ebx
  cmp BYTE PTR[ebx], 0
  je @next
  mov Result,ebx
  popad
end;

begin
  AlawarData.StolenBytesRVA:=DWORD(Pointer(DWORD(@PackInfoBuf)+AVS.StolenBytesRVAOffset)^);
  AlawarData.StolenBytesCount:=BYTE(Pointer(DWORD(@PackInfoBuf)+AVS.StolenBytesCountOffset)^);
  AlawarData.TrialTime:=BYTE(Pointer(DWORD(@PackInfoBuf)+AVS.TrialTimeOffset)^);
  AlawarData.StolenBytes:=Pointer(DWORD(@PackInfoBuf)+AVS.StolenBytesOffset);
  //AlawarData.TrialKey:=Pointer(DWORD(@PackInfoBuf)+AVS.TrialKeyOffset);
  AlawarData.TrialKey:=Pointer(GetNextNotNullByte(DWORD(@PackInfoBuf),AVS.TrialKeyOffset));
  //AlawarData.GameFile:=Pointer(DWORD(@PackInfoBuf)+AVS.GameFileOffset);
  AlawarData.GameFile:=Pointer(GetNextNotNullByte(DWORD(@PackInfoBuf),AVS.GameFileOffset));
  //AlawarData.GameKey:=Pointer(DWORD(@PackInfoBuf)+AVS.GameKeyOffset);
  AlawarData.GameKey:=Pointer(GetNextNotNullByte(DWORD(@PackInfoBuf),AVS.GameKeyOffset));
end;

function TAlawar.RestoreTrial:BOOL;
var
  Key       : HKEY;
  Res       : DWORD;
  TrialTime : DWORD;
begin
  Result := False;
  if not Openned then Exit;
  TrialTime := AlawarData.TrialTime*60000;
  RegCreateKeyEx(HKEY_CURRENT_USER, PChar(AlawarData.TrialKey), 0, nil,
    REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, Key, @Res);
  if Key = ERROR_SUCCESS then Exit;
  RegSetValueEx(Key, RegTrialValue, 0, REG_DWORD, @TrialTime, SizeOf(TrialTime));
  RegCloseKey(Key);
  Result := True;
end;

function TAlawar.RegisterGame:BOOL;
const
  BufSize = $400;
var
  Key  : HKEY;
  Size : DWORD;
  Res  : DWORD;
begin
  Result := False;
  if not Openned then Exit;
  Size := 1;
  while (Size < BufSize) and (SmsKeyBuf[Size] <> 0) do Inc(Size);
  Dec(Size);
  RegCreateKeyEx(HKEY_LOCAL_MACHINE, PChar(AlawarData.GameKey), 0, nil,
    REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nil, Key, @Res);
  if Key = ERROR_SUCCESS then Exit;
  RegSetValueEx(Key, RegRegisterValue, 0, REG_BINARY, @SmsKeyBuf[1], Size);
  RegCloseKey(Key);
  Result := True;
end;

function TAlawar.CrackGame: BOOL;
const
  INVALID_RVA = $FFFFFFFF;
var
  hFile, n, i : DWORD;
  Offset      : DWORD;
  GameFile    : string;
  IDH         : IMAGE_DOS_HEADER;
  INTH        : IMAGE_NT_HEADERS;
  ISH         : IMAGE_SECTION_HEADER;
begin
  Result := False;
  if not Openned then Exit;
  GameFile := FilePath+PChar(AlawarData.GameFile);
  if not FileExists(GameFile) then
  begin
    LastError := FILE_NOT_FOUND;
    Exit;
  end;
  Offset := INVALID_RVA;
  hFile := CreateFile(PChar(GameFile), GENERIC_READ or GENERIC_WRITE,
   FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
  if hFile <> INVALID_HANDLE_VALUE then
  try
    SetFilePointer(hFile, 0, nil, 0);
    ReadFile(hFile, IDH, SizeOf(IDH), n, nil);
    SetFilePointer(hFile, IDH._lfanew, nil, 0);
    ReadFile(hFile, INTH, SizeOf(INTH), n, nil);
    if ((LoWord(IDH.e_magic) <> IMAGE_DOS_SIGNATURE)
     or (LoWord(INTH.Signature) <> IMAGE_NT_SIGNATURE)) then
    begin
      LastError := INVALID_PE_FILE;
      CloseHandle(hFile);
      Exit;
    end;
    for i := 0 to INTH.FileHeader.NumberOfSections do
    begin
      ReadFile(hFile, ISH, SizeOf(ISH), n, nil);
      if (AlawarData.StolenBytesRva >= ISH.VirtualAddress)
       and (AlawarData.StolenBytesRva <=
       (ISH.VirtualAddress+ISH.Misc.VirtualSize)) then
      begin
        Offset := ISH.PointerToRawData+AlawarData.StolenBytesRva-
         ISH.VirtualAddress;
        Break;
      end;
      ProcessMessages;
    end;
    if Offset<>INVALID_RVA then
    begin
      SetFilePointer(hFile, Offset, nil, 0);
      Result := WriteFile(hFile, AlawarData.StolenBytes^,
       AlawarData.StolenBytesCount, n, nil);
    end else LastError := FILE_CORRUPTED;
  finally
    CloseHandle(hFile);
  end else LastError := CANT_OPEN_FILE;
end;

function TAlawar.ReplaceOriginalFile: BOOL;
var
  GameFileName: PChar;
begin
  GameFileName:=PChar(Pointer(AlawarData.GameFile));
  Result:=DeleteFile(PChar(FileName));
  Result:=Result and MoveFile(PChar(FilePath+GameFileName), PChar(FileName));
  if not Result then
    LastError := FILE_NOT_REPLACED;
end;

function TAlawar.FindRes(ResName, ResType: PAnsiChar): DWORD;
var
  hModule : DWORD;
begin
  Result  := 0;
  hModule := LoadLibrary(PAnsiChar(FileName));
  if hModule = 0 then Exit;
  Result := FindResource(hModule, ResName, ResType);
  if Result <> 0 then
  asm
    push eax
    mov eax, Result
    mov eax, [eax]
    mov Result, eax
    mov eax, hModule
    add eax, $3C //PE Header
    mov eax, [eax]
    add eax, hModule
    add eax, $34 //ImageBase
    mov eax, [eax]
    add Result, eax
    pop eax
  end;
  FreeLibrary(hModule);
end;

function TAlawar.GetWrapperVersion: DWORD;
begin
  Result:=DWORD(Pointer(DWORD(@PackInfoBuf))^);
  WrapperVer := Result;
end;

function TAlawar.IsAlawarFile: BOOL;
var
  hModule : DWORD;
begin
  Result := False;
  if FileExists(FileName) then
  begin
    hModule := LoadLibrary(PChar(FileName));
    case hModule of
      11..15:        LastError := INVALID_PE_FILE;
      0..10, 16..32: LastError := CANT_OPEN_FILE;
      else begin
        Result := (FindResource(hModule, ResNamePackInfo, ResType) <> 0)
         and (FindResource(hModule, ResNameSmsKey, ResType) <> 0);
        FreeLibrary(hModule);
        if not Result then LastError := IS_NOT_ALAWAR_FILE;
      end;
    end;
  end else
    LastError := FILE_NOT_FOUND;
end;

function TAlawar.GrabAlawarInfo: BOOL;
const
  WaitTime = 10000;
var
  Wnd : HWND;
  tmp : DWORD;
begin
  Result     := False;
  PackInfoVA := FindRes(ResNamePackInfo, ResType);
  SmsKeyVA   := FindRes(ResNameSmsKey, ResType);
  if CreateProcess(nil, PChar(FileName), nil, nil, False,
   NORMAL_PRIORITY_CLASS, nil, nil, SI, PI) = False then
  begin
    LastError := CANT_EXECUTE_FILE;
    Exit;
  end;
  tmp := GetTickCount;
  while (GetTickCount-tmp < WaitTime) do
  begin
    Wnd:=FindWindow(WrapperWndClass, nil);
    if (Wnd <> 0) and (GetWindowTask(Wnd) = PI.dwThreadId) then
    begin
      tmp := 0;
      ShowWindow(Wnd,SW_HIDE);
      Break;
    end;
    ProcessMessages;
  end;
  try
    if tmp = 0 then
    begin
      SuspendThread(PI.hThread);
      VirtualProtectEx(PI.hProcess, Pointer(PackInfoVA),
       SizeOf(PackInfoBuf), PAGE_READONLY, tmp);
      ReadProcessMemory(PI.hProcess, Pointer(PackInfoVa),
       @PackInfoBuf, SizeOf(PackInfoBuf), tmp);
      VirtualProtectEx(PI.hProcess, Pointer(SmsKeyVA),
       SizeOf(SmsKeyBuf), PAGE_READONLY, tmp);
      ReadProcessMemory(PI.hProcess, Pointer(SmsKeyVA),
       @SmsKeyBuf, SizeOf(SmsKeyBuf), tmp);
      Result := True;
    end else LastError := IS_NOT_ALAWAR_FILE;
  finally
    TerminateProcess(PI.hProcess, 0);
  end;
end;

function TAlawar.GrabInfo(szFileName: string):BOOL;
begin
  Result   := False;
  Openned  := Result;
  FileName := szFileName;
  FilePath := ExtractFilePath(FileName);
  if not IsAlawarFile then Exit;
  Result   := GrabAlawarInfo;
  Openned  := Result;
end;

constructor TAlawar.Create;
begin
  inherited Create;
  Openned   := False;
  LastError := 0;
  FileName  := '';
  FilePath  := '';
  ZeroMemory(@PackInfoBuf, SizeOf(PackInfoBuf));
  ZeroMemory(@SmsKeyBuf, SizeOf(SmsKeyBuf));
end;

end.

