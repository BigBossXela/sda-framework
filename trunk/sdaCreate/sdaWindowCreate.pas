unit sdaWindowCreate;

interface

{$INCLUDE 'sda.inc'}

uses
  sdaSystem, sdaWindows, sdaMessages;

type
  TSdaWindowProc = function(Window: HWND; var Message: TMessage): BOOL; stdcall;

  TSdaWindowObject = class(TObject)
  private
    FHandle: HWND;
  protected
    property Handle: HWND read FHandle write FHandle;
    procedure DestroyHandle;
    procedure RegisteredMessage(var Message: TMessage); virtual;
  public
    constructor Create; virtual;
    procedure DefaultHandler(var Message); override;

    class function GetWindowClass(out WndClass: TWndClassEx): Boolean; virtual;
  end;

  TSdaWindowObjectClass = class of TSdaWindowObject;

function SdaRegisterWindowClass(const ObjectClass: TSdaWindowObjectClass): Boolean;

implementation

function SdaWindowProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): LRESULT; stdcall;
var
  nObj, nClass: Integer;
  ObjectClass: TSdaWindowObjectClass;
  Obj: TSdaWindowObject;
  Msg: TMessage;
begin
  nObj := GetClassLongPtr(hWnd, GCL_CBWNDEXTRA) - SizeOf(Pointer);
  if nObj >= 0 then
  begin
    if uMsg = WM_NCCREATE then
    begin
      nClass := GetClassLongPtr(hWnd, GCL_CBCLSEXTRA) - SizeOf(Pointer);
      if nClass >= 0 then
      begin
        ObjectClass := Pointer(GetClassLongPtr(hWnd, nClass));
        if Assigned(ObjectClass) then
        begin
          Obj := ObjectClass.Create;
          Obj.Handle := hWnd;
          SetWindowLongPtr(hWnd, nObj, NativeInt(Obj));
        end;
      end;
    end;

    Obj := Pointer(GetWindowLongPtr(hWnd, nObj));
    if Assigned(Obj) then
    begin
      Msg.Msg := uMsg;
      Msg.WParam := wParam;
      Msg.LParam := lParam;
      Msg.Result := 0;
      Obj.Dispatch(Msg);
      Result := Msg.Result;
    end else Result := DefWindowProc(hWnd, uMsg, wParam, lParam);

    if uMsg = WM_NCDESTROY then
    begin
      Obj := Pointer(SetWindowLongPtr(hWnd, nObj, NativeInt(nil)));
      Obj.Free;
    end;
  end else Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
end;

{ WndClass.cbClsExtra
    �������� �� SizeOf(Pointer) - ��� ��������� ��������� �� ����
  WndClass.cbWndExtra
    �������� �� SizeOf(Pointer) - ��� ��������� ��������� �� ��'���
  WndClass.lpfnWndProc
    �� ���� - �������� �� ������ ��������� ����; �������� �� DefWindowProc,
    ��������� ��������� ��������. �������� ������������ DefWindowProc ���
    ����, ��� ����� ���� �������� ��������� ���� ��� ���������� ������,
    ���� ������� �� SdaWindowProc - �� ��� ���� ������ ������������ �
    ����� ������� ����������
}
function SdaRegisterWindowClass(const ObjectClass: TSdaWindowObjectClass): Boolean;
var
  WndClass: TWndClassEx;
  h: HWND;
begin
  if not Assigned(ObjectClass) then Exit(false);
  FillChar(WndClass, SizeOf(WndClass), 0);
  WndClass.cbSize := SizeOf(WndClass);
  if not ObjectClass.GetWindowClass(WndClass) then Exit(false);

  WndClass.cbClsExtra := WndClass.cbClsExtra + SizeOf(Pointer);
  WndClass.cbWndExtra := WndClass.cbWndExtra + SizeOf(Pointer);
  WndClass.lpfnWndProc := @DefWindowProc;
  Result := RegisterClassEx(WndClass) <> 0;
  if Result then
  begin
    h := CreateWindow(WndClass.lpszClassName, nil, WS_OVERLAPPED, 0, 0, 0, 0, 0,
      0, WndClass.hInstance, nil);
    if h <> 0 then
    begin
      SetClassLongPtr(h, WndClass.cbClsExtra - SizeOf(Pointer), NativeInt(ObjectClass));
      SetClassLongPtr(h, GCL_WNDPROC, NativeInt(@SdaWindowProc));
      DestroyWindow(h);
    end;
  end;
end;

{ TSdaWindowObject }

class function TSdaWindowObject.GetWindowClass(out WndClass: TWndClassEx): Boolean;
begin
  FillChar(WndClass, SizeOf(WndClass), 0);
  WndClass.cbSize := SizeOf(WndClass);
  WndClass.hInstance := HInstance;
  WndClass.hCursor := LoadCursor(0, IDC_ARROW);
  WndClass.hbrBackground := COLOR_WINDOW + 1;
  Result := false;
end;

procedure TSdaWindowObject.RegisteredMessage(var Message: TMessage);
begin
  Message.Result := 0;
end;

constructor TSdaWindowObject.Create;
begin
  inherited Create;
end;

procedure TSdaWindowObject.DefaultHandler(var Message);
begin
  with TMessage(Message) do
  begin
    if Msg >= $C000 then RegisteredMessage(TMessage(Message))
      else Result := DefWindowProc(Handle, Msg, WParam, LParam);
  end;
end;

procedure TSdaWindowObject.DestroyHandle;
begin
  if IsWindow(Handle) then
    PostMessage(Handle, SDAM_DESTROYWINDOW, 0, 0);
end;

end.
