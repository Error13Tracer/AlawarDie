unit Utils;

interface

uses
  Windows, Messages;
  
procedure ProcessMessages;
function LowerCase(const S: string): string;
function FileExists(FileName: String): BOOL;
function ExtractFilePath(const FileName: shortstring): shortstring;

implementation

function ExtractFilePath(const FileName: shortstring): shortstring;
var
  I: Integer;
begin
  I := Length(FileName);
  while (I > 1) and not (FileName[I] in ['\', ':']) do Dec(I);
  Result := Copy(FileName, 1, I);
  if Result[0] > #0 then
    if Result[Ord(Result[0])] = #0 then Dec(Result[0]);
end;

function FileExists(FileName: String): BOOL;
var
  fd: _WIN32_FIND_DATAA;
  hSearch: DWORD;
begin
  Result:=False;
  hSearch:=FindFirstFile(PChar(FileName),fd);
  if hSearch<>INVALID_HANDLE_VALUE then
    Result:=True;
  FindClose(hsearch);
end;

function LowerCase(const S: string): string;
var
  Ch: Char;
  L: Integer;
  Source, Dest: PChar;
begin
  L := Length(S);
  SetLength(Result, L);
  Source := Pointer(S);
  Dest := Pointer(Result);
  while L <> 0 do
  begin
    Ch := Source^;
    if (Ch >= 'A') and (Ch <= 'Z') then Inc(Ch, 32);
    Dest^ := Ch;
    Inc(Source);
    Inc(Dest);
    Dec(L);
  end;
end;

function ProcessMsg(var Msg: TMsg): Boolean;
begin
  Result := False;
  if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
  begin
    Result := True;
    if Msg.Message <> WM_QUIT then
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end
    else
      DispatchMessage(Msg);
  end;
end;

procedure ProcessMessages;
var
  Msg: TMsg;
begin
  while ProcessMsg(Msg) do;
end;

end.
