unit sdaProcess;

interface

{$INCLUDE 'sda.inc'}

uses
  sdaWindows;

type
  TProcessDefaultLayout = (LayoutLTR = LAYOUT_LTR, LayoutRTL = LAYOUT_RTL);

  TSdaCurrentProcess = {$IFDEF FPC}object{$ELSE}record{$ENDIF}
  private
    function GetCommandLine: string;
    function GetHandle: THandle;
    function GetId: UINT;
    function GetParamCount: Integer;
    function GetParams(Index: Integer): string;
    function GetExeName: string;
    function GetMainThread: THandle;
    function GetMainThreadId: UINT;
    function GetDefaultLayout: TProcessDefaultLayout;
    procedure SetDefaultLayout(const Value: TProcessDefaultLayout);
  public
    property Handle: THandle read GetHandle;
    property Id: UINT read GetId;
    property ParamCount: Integer read GetParamCount;
    property Params[Index: Integer]: string read GetParams;
    property CommandLine: string read GetCommandLine;
    property ExeName: string read GetExeName;
    property MainThread: THandle read GetMainThread;
    property MainThreadId: UINT read GetMainThreadId;
    property DefaultLayout: TProcessDefaultLayout read GetDefaultLayout
      write SetDefaultLayout;

    procedure EnablePrivilege(const Name: string);
    procedure DisablePrivilege(const Name: string);
  end;

var
  Process: TSdaCurrentProcess;

implementation

var
  FMainThread: THandle;
  FMainThreadId: UINT;

{ TSdaProcess }

procedure TSdaCurrentProcess.DisablePrivilege(const Name: string);
var
  hToken: DWORD;
  SeDebugNameValue: Int64;
  tkp: TOKEN_PRIVILEGES;
  ReturnLength: DWORD;
begin
  if not OpenProcessToken(INVALID_HANDLE_VALUE, TOKEN_ADJUST_PRIVILEGES or
    TOKEN_QUERY, hToken) then Exit;
  try
    if not LookupPrivilegeValue(nil, PChar(Name), SeDebugNameValue) then Exit;

    tkp.PrivilegeCount := 1;
    tkp.Privileges[0].Luid := SeDebugNameValue;
    tkp.Privileges[0].Attributes := 0; // Disable

    if not AdjustTokenPrivileges(hToken, false, tkp, SizeOf(TOKEN_PRIVILEGES),
      tkp, ReturnLength) then Exit;
  finally
    CloseHandle(hToken);
  end;
end;

procedure TSdaCurrentProcess.EnablePrivilege(const Name: string);
var
  hToken: DWORD;
  SeDebugNameValue: Int64;
  tkp: TOKEN_PRIVILEGES;
  ReturnLength: DWORD;
begin
  if not OpenProcessToken(INVALID_HANDLE_VALUE, TOKEN_ADJUST_PRIVILEGES or
    TOKEN_QUERY, hToken) then Exit;
  try
    if not LookupPrivilegeValue(nil, PChar(Name), SeDebugNameValue) then Exit;

    tkp.PrivilegeCount := 1;
    tkp.Privileges[0].Luid := SeDebugNameValue;
    tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;

    if not AdjustTokenPrivileges(hToken, false, tkp, SizeOf(TOKEN_PRIVILEGES),
      tkp, ReturnLength) then Exit;
  finally
    CloseHandle(hToken);
  end;
end;

function TSdaCurrentProcess.GetCommandLine: string;
begin
  Result := GetCommandLine;
end;

function TSdaCurrentProcess.GetDefaultLayout: TProcessDefaultLayout;
var
  dw: DWORD;
begin
  GetProcessDefaultLayout(dw);
  Result := TProcessDefaultLayout(dw);
end;

function TSdaCurrentProcess.GetExeName: string;
begin
  Result := ParamStr(0);
end;

function TSdaCurrentProcess.GetHandle: THandle;
begin
  Result := GetCurrentProcess;
end;

function TSdaCurrentProcess.GetID: UINT;
begin
  Result := GetCurrentProcessId;
end;

function TSdaCurrentProcess.GetMainThread: THandle;
begin
  Result := FMainThread;
end;

function TSdaCurrentProcess.GetMainThreadId: UINT;
begin
  Result := FMainThreadId;
end;

function TSdaCurrentProcess.GetParamCount: Integer;
begin
  Result := System.ParamCount;
end;

function TSdaCurrentProcess.GetParams(Index: Integer): string;
begin
  Result := ParamStr(Index);
end;

procedure TSdaCurrentProcess.SetDefaultLayout(const Value: TProcessDefaultLayout);
begin
  SetProcessDefaultLayout(DWORD(Value));
end;

initialization
  FMainThread := GetCurrentThread;
  FMainThreadId := GetCurrentThreadId;
end.
