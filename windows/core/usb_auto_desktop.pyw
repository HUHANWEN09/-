import os
os.environ['SDL_MOUSE_FOCUS_CLICKTHROUGH'] = '1'
os.environ['SDL_IME_SHOW_UI'] = '1'
import subprocess, time, ctypes, ctypes.wintypes

kernel32 = ctypes.windll.kernel32
user32 = ctypes.windll.user32

# Switch current thread to WinSta0\Default (real user physical desktop)
try:
    hdesk = user32.OpenDesktopW("Default", 0, False, 0x10000000)
    if hdesk:
        user32.SetThreadDesktop(hdesk)
except Exception:
    pass

class STARTUPINFOW(ctypes.Structure):
    _fields_ = [
        ("cb", ctypes.wintypes.DWORD),
        ("lpReserved", ctypes.wintypes.LPWSTR),
        ("lpDesktop", ctypes.wintypes.LPWSTR),
        ("lpTitle", ctypes.wintypes.LPWSTR),
        ("dwX", ctypes.wintypes.DWORD),
        ("dwY", ctypes.wintypes.DWORD),
        ("dwXSize", ctypes.wintypes.DWORD),
        ("dwYSize", ctypes.wintypes.DWORD),
        ("dwXCountChars", ctypes.wintypes.DWORD),
        ("dwYCountChars", ctypes.wintypes.DWORD),
        ("dwFillAttribute", ctypes.wintypes.DWORD),
        ("dwFlags", ctypes.wintypes.DWORD),
        ("wShowWindow", ctypes.wintypes.WORD),
        ("cbReserved2", ctypes.wintypes.WORD),
        ("lpReserved2", ctypes.POINTER(ctypes.c_byte)),
        ("hStdInput", ctypes.wintypes.HANDLE),
        ("hStdOutput", ctypes.wintypes.HANDLE),
        ("hStdError", ctypes.wintypes.HANDLE),
    ]

class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("hProcess", ctypes.wintypes.HANDLE),
        ("hThread", ctypes.wintypes.HANDLE),
        ("dwProcessId", ctypes.wintypes.DWORD),
        ("dwThreadId", ctypes.wintypes.DWORD),
    ]

CREATE_NO_WINDOW = 0x08000000
STARTF_USESHOWWINDOW = 0x00000001
SW_SHOWNORMAL = 1
STILL_ACTIVE = 259
SWP_NOMOVE = 0x0002
SWP_NOSIZE = 0x0001
SWP_SHOWWINDOW = 0x0040

def bring_to_front(title="Honor_PC_Mode", timeout_sec=6.0):
    t0 = time.time()
    while time.time() - t0 < timeout_sec:
        hwnd = user32.FindWindowW(None, title)
        if hwnd and user32.IsWindowVisible(hwnd):
            user32.ShowWindow(hwnd, 9)
            user32.SetWindowPos(hwnd, -1, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW)
            user32.SetWindowPos(hwnd, -2, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW)
            user32.SetForegroundWindow(hwnd)
            return True
        time.sleep(0.3)
    return False

def launch_on_real_desktop(cmd_line, cwd):
    si = STARTUPINFOW()
    si.cb = ctypes.sizeof(STARTUPINFOW)
    si.lpDesktop = "WinSta0\\Default"
    si.dwFlags = STARTF_USESHOWWINDOW
    si.wShowWindow = SW_SHOWNORMAL
    pi = PROCESS_INFORMATION()
    cmd_buf = ctypes.create_unicode_buffer(cmd_line)
    ok = kernel32.CreateProcessW(
        None,
        cmd_buf,
        None,
        None,
        False,
        CREATE_NO_WINDOW,
        None,
        cwd,
        ctypes.byref(si),
        ctypes.byref(pi)
    )
    if ok:
        kernel32.CloseHandle(pi.hThread)
        bring_to_front("Honor_PC_Mode", 6.0)
        return pi.hProcess
    return None

def get_exit_code(hProcess):
    if not hProcess:
        return None
    code = ctypes.wintypes.DWORD()
    if kernel32.GetExitCodeProcess(hProcess, ctypes.byref(code)):
        return code.value
    return None

script_dir = os.path.dirname(os.path.abspath(__file__))
if os.path.exists(os.path.join(script_dir, "scrcpy.exe")):
    core_dir = script_dir
else:
    xm = chr(0x9879) + chr(0x76ee)
    rc = chr(0x65e5) + chr(0x5e38) + chr(0x7535) + chr(0x8111) + chr(0x64cd) + chr(0x4f5c)
    sj = chr(0x624b) + chr(0x673a) + chr(0x7535) + chr(0x8111) + chr(0x6a21) + chr(0x5f0f) + "_Win_Mac"
    core_dir = f"D:\\data\\Antigravity\\{xm}\\{rc}\\{sj}\\Windows_Core"
    if not os.path.exists(os.path.join(core_dir, "scrcpy.exe")):
        ruanjian = chr(0x8f6f) + chr(0x4ef6)
        core_dir = f"D:\\{ruanjian}\\scrcpy-win64-v3.1"

adb = os.path.join(core_dir, "adb.exe")
scrcpy = os.path.join(core_dir, "scrcpy.exe")
helper_jar = os.path.join(core_dir, "screen_off_helper.jar")
daemon_sh = os.path.join(core_dir, "auto_screen_off.sh")

def ensure_phone_daemon():
    try:
        if os.path.exists(helper_jar):
            subprocess.run([adb, "push", helper_jar, "/data/local/tmp/screen_off_helper.jar"], creationflags=CREATE_NO_WINDOW, timeout=5)
        if os.path.exists(daemon_sh):
            subprocess.run([adb, "push", daemon_sh, "/data/local/tmp/auto_screen_off.sh"], creationflags=CREATE_NO_WINDOW, timeout=5)
            subprocess.run([adb, "shell", "chmod 755 /data/local/tmp/auto_screen_off.sh; ps -ef | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)"], creationflags=CREATE_NO_WINDOW, timeout=5)
    except Exception:
        pass

existing_hwnd = user32.FindWindowW(None, "Honor_PC_Mode")
was_connected = bool(existing_hwnd)
h_proc = None
tick = 0

while True:
    try:
        # Check global hotkey Ctrl + Alt + D (VK_CONTROL=0x11, VK_MENU=0x12, 'D'=0x44)
        hotkey_pressed = (
            (user32.GetAsyncKeyState(0x11) & 0x8000) and
            (user32.GetAsyncKeyState(0x12) & 0x8000) and
            (user32.GetAsyncKeyState(0x44) & 0x8000)
        )
        if hotkey_pressed:
            hwnd = user32.FindWindowW(None, "Honor_PC_Mode")
            if hwnd:
                bring_to_front("Honor_PC_Mode", 1.0)
            else:
                was_connected = False
                tick = 5

        tick += 1
        if tick >= 5:
            tick = 0
            out = subprocess.check_output([adb, "devices"], creationflags=CREATE_NO_WINDOW, timeout=5).decode("utf-8", errors="ignore")
            lines = [l.strip() for l in out.splitlines() if "\tdevice" in l]
            if lines:
                exit_code = get_exit_code(h_proc)
                is_running = (exit_code == STILL_ACTIVE) or bool(user32.FindWindowW(None, "Honor_PC_Mode"))
                disconnected_abnormally = (h_proc is not None) and (exit_code != STILL_ACTIVE) and (exit_code != 0)
                if (not was_connected) or disconnected_abnormally:
                    was_connected = True
                    subprocess.run([adb, "shell", "settings put global adb_allowed_connection_time 0; settings put secure selected-proj-mode 1"], creationflags=CREATE_NO_WINDOW, timeout=5)
                    ensure_phone_daemon()
                    if not is_running:
                        if h_proc:
                            kernel32.CloseHandle(h_proc)
                        cmd = f'"{scrcpy}" --new-display=1920x1080/160 --turn-screen-off --no-audio --no-mouse-hover --window-title=Honor_PC_Mode'
                        h_proc = launch_on_real_desktop(cmd, core_dir)
            else:
                was_connected = False
    except Exception:
        pass
    time.sleep(0.2)
