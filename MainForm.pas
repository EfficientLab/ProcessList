unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, TlHelp32,
  ExtCtrls, JwaPsApi;

type
  TForm1 = class(TForm)
    ListView1: TListView;
    Panel1: TPanel;
    btnRefresh: TButton;
    CheckBox1: TCheckBox;
    procedure btnRefreshClick(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses StrUtils;

{$R *.dfm}

function GetSystemErrorMessage(AErrorCode: Integer): String;
var
  Buf: PChar;
begin
  Result := '';

  if FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER + FORMAT_MESSAGE_FROM_SYSTEM,
    nil, AErrorCode, 0, @Buf, 0, nil) <> 0 then
  begin
    Result := Buf;
    LocalFree(Integer(Buf));
  end
end;

type
  TOsVersionInfoExA = packed record
    old : TOsVersionInfoA;
    wServicePackMajor : Word;
    wServicePackMinor : Word;
    wSuiteMask : Word;
    wProductType : Byte;
    wReserved : Byte;
  end;

function IsWindows2000: Boolean;
var
  VerInfo: TOsVersionInfoExA;
begin
  Result := False;

  FillChar(VerInfo, sizeof(VerInfo), 0);
  VerInfo.old.dwOSVersionInfoSize := Sizeof(TOsVersionInfoExA);
  if not GetVersionExA(VerInfo.old) then begin
    VerInfo.old.dwOSVersionInfoSize := Sizeof(TOsVersionInfoA);
    GetVersionExA(VerInfo.old);
  end;

  if (VerInfo.old.dwPlatformId = VER_PLATFORM_WIN32_NT) and
    (Verinfo.old.dwMajorVersion = 5) and (Verinfo.old.dwMinorVersion = 0) then
  Result := True;
end;

type

  PTOKEN_USER = ^TOKEN_USER;
  _TOKEN_USER = record
    User : TSidAndAttributes;
  end;
  TOKEN_USER = _TOKEN_USER;

function EnableDebugPrivilege(const Value: Boolean): Boolean;
const
  SE_DEBUG_NAME = 'SeDebugPrivilege';
var
  hToken: THandle;
  tp: TOKEN_PRIVILEGES;
  d: DWORD;
begin
  Result := False;
  if OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, hToken) then
  begin
    tp.PrivilegeCount := 1;
    LookupPrivilegeValue(nil, SE_DEBUG_NAME, tp.Privileges[0].Luid);
    if Value then
      tp.Privileges[0].Attributes := $00000002
    else
      tp.Privileges[0].Attributes := $80000000;
    AdjustTokenPrivileges(hToken, False, tp, SizeOf(TOKEN_PRIVILEGES), nil, d);
    if GetLastError = ERROR_SUCCESS then
    begin
      Result := True;
    end;
    CloseHandle(hToken);
  end;
end;

function DevicePathToWin32Path(path:string):string;
var c:char; 
    s:string;
    i:integer;
begin
  i:=PosEx('\', path, 2);
  i:=posex('\', path, i+1);
  result:=copy(path, i, length(path));
  delete(path, i, length(path));
  if (path = '\Device\LanmanRedirector') or (path = '\Device\Mup') then
  begin
    result := '\' + result;
    Exit;
  end;
  for c:='A' to 'Z' do
  begin
    setlength(s, 1000);
    if querydosdevice(pchar(string(c)+':'), pchar(s), 1000)<>0 then
    begin
      s:=pchar(s);
      if sametext(path, s) then
      begin 
        result:=c+':'+result;
        exit; 
      end; 
    end; 
  end;
  result := '';
end;

function GetProcessFilePath(pid:cardinal):string;
var 
  hp: THandle;
  Buffer1: array[0..MAX_PATH] of Char;

  mh: hmodule;
  ModName: array[0..max_path] of char;
  cm: Cardinal;
begin 
  Result := '';

  if pid > 0 then 
  begin 
    hp := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,False,pid);

    if hp > 0 then 
    begin 
        if IsWindows2000 then
        begin 
             if GetModuleFileNameEx(hp,0,Buffer1,Length(Buffer1)) > 0 then
                result := DevicePathToWin32Path(Buffer1);
        end else
        begin
             GetProcessImageFileName(hp, Buffer1, Length(Buffer1));



           result := DevicePathToWin32Path(Buffer1);
        end;

        if (Trim(result) = '') and (hp > 0) then
        begin   
          EnumProcessModules(hp, @mh, 4, cm);
          if GetModuleFileNameEx(hp, mh, ModName, sizeof(ModName)) <> 0 then
            Result := string(ModName);
        end;

        CloseHandle(hp);

    end;
  end; 
end;

function GetProcUserName(AProcId: Integer): string;
var
  phToken, hProcess, hWindow: THandle;
  cbBuf: Cardinal;
  ptiUser: PTOKEN_USER;
  snu: SID_NAME_USE;
  szDomain, szUser : array [0..50] of Char;
  chDomain, chUser : Cardinal;

  UserName1: array[0..250] of char;
  FriendlyUserName: array[0..250] of char;
  Size: DWORD;

const
  NameUnknown = 0; // Unknown name type.
  NameFullyQualifiedDN = 1;  // Fully qualified distinguished name
  NameSamCompatible = 2; // Windows NT® 4.0 account name
  NameDisplay = 3;  // A "friendly" display name
  NameUniqueId = 6; // GUID string that the IIDFromString function returns
  NameCanonical = 7;  // Complete canonical name
  NameUserPrincipal = 8; // User principal name
  NameCanonicalEx = 9;
  NameServicePrincipal = 10;  // Generalized service principal name
  DNSDomainName = 11;  // DNS domain name, plus the user name

begin
  Result := '';

    hProcess := OpenProcess(PROCESS_ALL_ACCESS, FALSE, AProcId);
    if hProcess <> 0 then
    begin
      if OpenProcessToken(hProcess, TOKEN_ALL_ACCESS, phToken) then
      begin
        if not GetTokenInformation(phToken, TokenUser, nil, 0, cbBuf) then
          if GetLastError()<> ERROR_INSUFFICIENT_BUFFER then exit;
        if cbBuf = 0 then exit;
        GetMem(ptiUser, cbBuf);
        try
          chDomain := 50;
          chUser   := 50;
          if GetTokenInformation(phToken, TokenUser, ptiUser, cbBuf, cbBuf) then
            if LookupAccountSid(nil, ptiUser.User.Sid, szUser, chUser, szDomain,
              chDomain, snu) then
              begin
                Result := szUser;
              end
            else
              raise Exception.Create('Error in GetTokenUser');
        finally
          FreeMem(ptiUser);
        end;
      end
      else begin
        Result := '';
      end
    end
    else begin
      Result := '';
    end
end;


function GetProcAccountFullName(AProcId: Integer): string;
var
  phToken, hProcess, hWindow: THandle;
  cbBuf: Cardinal;
  ptiUser: PTOKEN_USER;
  snu: SID_NAME_USE;
  szDomain, szUser : array [0..50] of Char;
  chDomain, chUser : Cardinal;

  UserName1: array[0..250] of char;
  FriendlyUserName: array[0..250] of char;
  Size: DWORD;

const
  NameUnknown = 0; // Unknown name type.
  NameFullyQualifiedDN = 1;  // Fully qualified distinguished name
  NameSamCompatible = 2; // Windows NT® 4.0 account name
  NameDisplay = 3;  // A "friendly" display name
  NameUniqueId = 6; // GUID string that the IIDFromString function returns
  NameCanonical = 7;  // Complete canonical name
  NameUserPrincipal = 8; // User principal name
  NameCanonicalEx = 9;
  NameServicePrincipal = 10;  // Generalized service principal name
  DNSDomainName = 11;  // DNS domain name, plus the user name

begin
  Result := '';

    hProcess := OpenProcess(PROCESS_ALL_ACCESS, FALSE, AProcId);
    if hProcess <> 0 then
    begin
      if OpenProcessToken(hProcess, TOKEN_QUERY, phToken) then
      begin
        if not GetTokenInformation(phToken, TokenUser, nil, 0, cbBuf) then
          if GetLastError()<> ERROR_INSUFFICIENT_BUFFER then exit;
        if cbBuf = 0 then exit;
        GetMem(ptiUser, cbBuf);
        try
          chDomain := 50;
          chUser   := 50;
          if GetTokenInformation(phToken, TokenUser, ptiUser, cbBuf, cbBuf) then
            if LookupAccountSid(nil, ptiUser.User.Sid, szUser, chUser, szDomain,
              chDomain, snu) then
              begin
                Result := szDomain + '\' + szUser;
              end
            else
              raise Exception.Create('Error in GetTokenUser');
        finally
          FreeMem(ptiUser);
        end;
      end
      else begin
        Result := '';
      end
    end
    else begin
      Result := '';
    end
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  EnableDebugPrivilege(CheckBox1.Checked);
end;

procedure TForm1.btnRefreshClick(Sender: TObject);
var
  pe: TProcessEntry32;
  ph, snap:THandle;
  mh: hmodule;
  procs: array[0..$fff] of DWORD;
  count, cm: Cardinal;
  i: Integer;
  ModName: array[0..max_path] of widechar;
  LastIndex: Integer;
  fn:string;
begin
  ListView1.Clear;

  if not EnumProcesses(@procs, sizeof(procs), count) then
  begin
    exit;
  end;
  for i := 0 to count div 4 - 1 do
  begin
    begin
      fn := GetProcessFilePath(procs[i]);
      if fn = '' then
      begin
        with ListView1.Items.Add do
        begin
          Caption := 'GetModuleFileNameExW failed: ';
          SubItems.Add(IntToStr(procs[i]));
          SubItems.Add(IntToStr(GetLastError) + ': ' + GetSystemErrorMessage(GetLastError));
          SubItems.Add(GetProcUserName(procs[i]));
        end;
      end
      else
      with ListView1.Items.Add do
      begin
        Caption := fn;
        SubItems.Add(IntToStr(procs[i]));
        SubItems.Add('');
        SubItems.Add(GetProcAccountFullName(procs[i]));
      end;
    end
  end;
end;


end.
