import os
os.environ['SDL_MOUSE_FOCUS_CLICKTHROUGH'] = '1'
os.environ['SDL_IME_SHOW_UI'] = '1'
import subprocess, time, ctypes, ctypes.wintypes, re

kernel32 = ctypes.windll.kernel32
user32 = ctypes.windll.user32

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

def find_cast_window():
    for title in ["PC_Mode", "Honor_PC_Mode", "Phone_Mirror", "Honor_Phone_Mirror"]:
        hwnd = user32.FindWindowW(None, title)
        if hwnd and user32.IsWindowVisible(hwnd):
            return hwnd, title
    return None, None

def bring_to_front(timeout_sec=5.0):
    t0 = time.time()
    while time.time() - t0 < timeout_sec:
        hwnd, _ = find_cast_window()
        if hwnd:
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
        bring_to_front(5.0)
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
core_dir = script_dir if os.path.exists(os.path.join(script_dir, "scrcpy.exe")) else r"D:\data\Antigravity\项目\日常电脑操作\荣耀手机电脑模式与超清投屏套件\windows\core"

adb = os.path.join(core_dir, "adb.exe")
scrcpy = os.path.join(core_dir, "scrcpy.exe")
helper_jar = os.path.join(core_dir, "screen_off_helper.jar")
daemon_sh = os.path.join(core_dir, "auto_screen_off.sh")

os.environ['SCRCPY_SERVER_PATH'] = os.path.join(core_dir, "scrcpy-server")

def probe_and_prepare_device():
    try:
        brand = subprocess.check_output([adb, "shell", "getprop", "ro.product.brand"], creationflags=CREATE_NO_WINDOW, timeout=4).decode("utf-8", errors="ignore").strip()
        manu = subprocess.check_output([adb, "shell", "getprop", "ro.product.manufacturer"], creationflags=CREATE_NO_WINDOW, timeout=4).decode("utf-8", errors="ignore").strip()
        sdk_str = subprocess.check_output([adb, "shell", "getprop", "ro.build.version.sdk"], creationflags=CREATE_NO_WINDOW, timeout=4).decode("utf-8", errors="ignore").strip()
        m = re.search(r'\d+', sdk_str)
        sdk = int(m.group(0)) if m else 30
        
        # Universal Android settings
        subprocess.run([adb, "shell", "settings put global adb_allowed_connection_time 0; settings put global force_desktop_mode_on_external_displays 1; settings put global enable_freeform_support 1"], creationflags=CREATE_NO_WINDOW, timeout=5)
        
        # Brand adaptations
        combined = f"{brand} {manu}".lower()
        if "honor" in combined or "huawei" in combined:
            subprocess.run([adb, "shell", "settings put secure selected-proj-mode 1"], creationflags=CREATE_NO_WINDOW, timeout=4)
        
        # Push screen-off helper and auto daemon
        if os.path.exists(helper_jar):
            subprocess.run([adb, "push", helper_jar, "/data/local/tmp/screen_off_helper.jar"], creationflags=CREATE_NO_WINDOW, timeout=5)
        if os.path.exists(daemon_sh):
            subprocess.run([adb, "push", daemon_sh, "/data/local/tmp/auto_screen_off.sh"], creationflags=CREATE_NO_WINDOW, timeout=5)
            subprocess.run([adb, "shell", "chmod 755 /data/local/tmp/auto_screen_off.sh; (ps -ef 2>/dev/null || ps 2>/dev/null) | grep -q '[a]uto_screen_off.sh' || (nohup /data/local/tmp/auto_screen_off.sh >/dev/null 2>&1 < /dev/null &)"], creationflags=CREATE_NO_WINDOW, timeout=5)
            
        return sdk
    except Exception:
        return 30

hwnd_init, _ = find_cast_window()
was_connected = bool(hwnd_init)
h_proc = None
tick = 0

while True:
    try:
        # Check global hotkey Ctrl + Alt + D
        hotkey_pressed = (
            (user32.GetAsyncKeyState(0x11) & 0x8000) and
            (user32.GetAsyncKeyState(0x12) & 0x8000) and
            (user32.GetAsyncKeyState(0x44) & 0x8000)
        )
        if hotkey_pressed:
            hwnd, _ = find_cast_window()
            if hwnd:
                bring_to_front(1.0)
            else:
                was_connected = False
                tick = 5

        tick += 1
        if tick >= 5:
            tick = 0
            out = subprocess.check_output([adb, "devices"], creationflags=CREATE_NO_WINDOW, timeout=4).decode("utf-8", errors="ignore")
            lines = [l.strip() for l in out.splitlines() if "\tdevice" in l]
            if lines:
                exit_code = get_exit_code(h_proc)
                hwnd_current, _ = find_cast_window()
                is_running = (exit_code == STILL_ACTIVE) or bool(hwnd_current)
                disconnected_abnormally = (h_proc is not None) and (exit_code != STILL_ACTIVE) and (exit_code != 0)
                
                if (not was_connected) or disconnected_abnormally:
                    was_connected = True
                    sdk = probe_and_prepare_device()
                    if not is_running:
                        if h_proc:
                            kernel32.CloseHandle(h_proc)
                        
                        if sdk >= 29:
                            # Try Desktop Mode
                            cmd = f'"{scrcpy}" --new-display=1920x1080/160 --turn-screen-off --no-audio --no-mouse-hover --window-title=PC_Mode'
                            h_proc = launch_on_real_desktop(cmd, core_dir)
                            time.sleep(2.5)
                            code = get_exit_code(h_proc)
                            if code != STILL_ACTIVE and code != 0:
                                # Fallback to 1:1 Mirror mode automatically
                                if h_proc:
                                    kernel32.CloseHandle(h_proc)
                                cmd_fallback = f'"{scrcpy}" --turn-screen-off --stay-awake --no-audio --window-title=Phone_Mirror'
                                h_proc = launch_on_real_desktop(cmd_fallback, core_dir)
                        else:
                            # Older Android SDK < 29, launch Mirror Mode directly
                            cmd = f'"{scrcpy}" --turn-screen-off --stay-awake --no-audio --window-title=Phone_Mirror'
                            h_proc = launch_on_real_desktop(cmd, core_dir)
            else:
                was_connected = False
    except Exception:
        pass
    time.sleep(0.2)
