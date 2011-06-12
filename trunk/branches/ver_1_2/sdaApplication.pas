unit sdaApplication;

interface

{$INCLUDE 'sda.inc'}

uses
  Windows, Messages, sdaWinControl, sdaWinCreate;

type
  TSdaApplication = class(TObject)
  strict private
    FModalLevel: Integer;
    FTerminated: BOOL;
    FModalResult: Integer;
    function GetTerminated: Boolean;
    procedure SetTerminated(const Value: Boolean);
    function GetExeName: string;
  strict private
    function IsDialogMessage(var Message: TMsg): Boolean;
    procedure HandleApplicationMessage(var Message: TMsg);
    procedure CheckApplicationTerminate;
    procedure DestroyAllWindows;
  strict protected
    procedure Idle; virtual;
    function TryGetMessage(var Message: TMsg): Boolean; virtual;
    procedure DefDispatchMessage(var Message: TMsg); virtual;
  public
    constructor Create; virtual;

    procedure HandleException(const E: TObject); virtual;

    property ExeName: string read GetExeName;

    procedure Run;
    property Terminated: Boolean read GetTerminated write SetTerminated;
    procedure Terminate;

    function BeginModal(Wnd: HWND): Integer;
    procedure EndModal(ModalResult: Integer);
    property ModalLevel: Integer read FModalLevel;
  end;

  TSdaApplicationClass = class of TSdaApplication;

var
  MainApplication: TSdaApplication;

threadvar
  Application: TSdaApplication;

procedure SdaApplicationInitialize(ApplicationClass: TSdaApplicationClass = nil);
procedure SdaApplicationFinalize;

implementation

procedure SdaApplicationInitialize(ApplicationClass: TSdaApplicationClass);
begin
  if not Assigned(ApplicationClass) then
    ApplicationClass := TSdaApplication;
  Application := ApplicationClass.Create;
  InterlockedCompareExchangePointer(Pointer(MainApplication), Application, nil);
end;

procedure SdaApplicationFinalize;
var
  TempApp: TSdaApplication;
begin
  TempApp := InterlockedCompareExchangePointer(Pointer(MainApplication), nil, Application);
  if TempApp <> Application then TempApp.Free;
  TempApp := Application;
  Application := nil;
  TempApp.Free;
end;

{ TSdaApplication }

procedure TSdaApplication.CheckApplicationTerminate;

  function EnumThreadWndProc(hWnd: HWND; lParam: PLongInt): BOOL; stdcall;
  begin
    Inc(lParam^);
    Result := true;
  end;

var
  nWnd: LongInt;
begin
  nWnd := 0;
  EnumThreadWindows(GetCurrentThreadId, @EnumThreadWndProc, NativeInt(@nWnd));
  if nWnd <= 0 then PostQuitMessage(0);
end;

procedure TSdaApplication.DestroyAllWindows;

  function EnumThreadWndProc(hWnd: HWND; lParam: PLongInt): BOOL; stdcall;
  begin
    DestroyWindow(hWnd);
    Result := true;
  end;

begin
  EnumThreadWindows(GetCurrentThreadId, @EnumThreadWndProc, 0);
end;

constructor TSdaApplication.Create;
begin
  inherited Create;
end;

function TSdaApplication.IsDialogMessage(var Message: TMsg): Boolean;
var
  wnd: HWND;
begin
  wnd := GetForegroundWindow;
  if wnd = 0 then Exit(false);
  if GetWindowThreadProcessId(wnd, nil) <> GetCurrentThreadId then Result := false
    else Result := Windows.IsDialogMessage(wnd, Message);
end;

function TSdaApplication.TryGetMessage(var Message: TMsg): Boolean;
var
  Unicode: Boolean;
begin
  Result := false;
  while true do
  begin
    if PeekMessage(Message, 0, 0, 0, PM_NOREMOVE) then
    begin
      Unicode := (Message.hwnd = 0) or IsWindowUnicode(Message.hwnd);
      if Unicode then Result := PeekMessageW(Message, 0, 0, 0, PM_REMOVE)
                 else Result := PeekMessageA(Message, 0, 0, 0, PM_REMOVE);
      if Result then Break;
    end else
    begin
      CheckApplicationTerminate;
      Idle;
      if not WaitMessage then Exit(false);
    end;
  end;
end;

procedure TSdaApplication.DefDispatchMessage(var Message: TMsg);
var
  Unicode: Boolean;
begin
  if not IsDialogMessage(Message) then
  begin
    TranslateMessage(Message);
    Unicode := (Message.hwnd = 0) or IsWindowUnicode(Message.hwnd);
    if Unicode then DispatchMessageW(Message)
               else DispatchMessageA(Message);
  end;
end;

function TSdaApplication.BeginModal(Wnd: HWND): Integer;

type
  PModalList = ^TModalList;
  TModalList = record
    Next: PModalList;
    Wnd: HWND;
  end;

  TModalState = record
    Wnd: HWND;
    FgWnd: HWND;
    First: PModalList;
  end;
  PModalState = ^TModalState;

  function EnumThreadWndProc(hWnd: HWND; lParam: PModalState): BOOL; stdcall;
  var
    List: PModalList;
  begin
    if (hWnd <> lParam.Wnd) and IsWindowEnabled(hWnd) and IsWindowVisible(hWnd) then
    begin
      New(List);
      List.Wnd := hWnd;
      List.Next := lParam.First;
      lParam.First := List;
      EnableWindow(hWnd, false);
    end;
    Result := true;
  end;

  function StoreModalState(Wnd: HWND): PModalState;
  begin
    New(Result);
    Result.Wnd := Wnd;
    Result.FgWnd := GetActiveWindow;
    Result.First := nil;
    EnumThreadWindows(GetCurrentThreadId, @EnumThreadWndProc, NativeInt(Result));
  end;

  procedure RestoreModalState(State: PModalState);
  var
    Temp: PModalList;
  begin
    while State.First <> nil do
    begin
      Temp := State.First;
      State.First := Temp.Next;
      EnableWindow(Temp.Wnd, true);
      Dispose(Temp);
    end;
    SetActiveWindow(State.FgWnd);
    Dispose(State);
  end;

var
  Message: TMsg;
  ModalState: PModalState;
begin
  Result := 0;
  FModalResult := 0;
  ModalState := StoreModalState(Wnd);
  InterlockedIncrement(FModalLevel);
  ShowWindow(Wnd, SW_SHOWNORMAL);
  try
    while not Terminated do
    begin
      if FModalResult <> 0 then
      begin
        Result := FModalResult;
        FModalResult := 0;
        Break;
      end;
      if TryGetMessage(Message) then
      begin
        if Message.message <> WM_QUIT then
        begin
          if Message.hwnd = 0 then HandleApplicationMessage(Message)
            else DefDispatchMessage(Message);
        end else Terminate;
      end else Terminate;
    end;
  finally
    ShowWindow(Wnd, SW_HIDE);
    InterlockedDecrement(FModalLevel);
    RestoreModalState(ModalState);
  end;
end;

procedure TSdaApplication.EndModal(ModalResult: Integer);
begin
  FModalResult := ModalResult;
  PostThreadMessage(GetCurrentThreadId, WM_NULL, 0, 0); // Wake up modal message loop
end;

procedure TSdaApplication.Run;
var
  Message: TMsg;
begin
  while not Terminated do
  begin
    try
      if TryGetMessage(Message) then
      begin
        if Message.message <> WM_QUIT then
        begin
          if Message.hwnd = 0 then HandleApplicationMessage(Message)
            else DefDispatchMessage(Message);
        end else Terminate;
      end else Terminate;
    except
      HandleException(ExceptObject);
    end;
  end;
  DestroyAllWindows;
end;

procedure TSdaApplication.SetTerminated(const Value: Boolean);
begin
  InterlockedExchange(LongInt(FTerminated), LongInt(Value));
end;

function TSdaApplication.GetExeName: string;
begin
  Result := ParamStr(0);
end;

function TSdaApplication.GetTerminated: Boolean;
begin
  Result := FTerminated;
end;

procedure TSdaApplication.HandleApplicationMessage(var Message: TMsg);
var
  Msg: TMessage;
begin
  Msg.Msg := Message.message;
  Msg.WParam := Message.wParam;
  Msg.LParam := Message.lParam;
  Msg.Result := 0;
  Dispatch(Msg);
end;

procedure TSdaApplication.HandleException(const E: TObject);
begin
  if not Assigned(E) then Exit;
  SdaMessageDlg(E.ToString, E.ClassName, mtError, mbOk);
end;

procedure TSdaApplication.Terminate;
begin
  Terminated := true;
  PostQuitMessage(0);
end;

procedure TSdaApplication.Idle;
begin
end;

end.
