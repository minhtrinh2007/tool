import tkinter as tk
from tkinter import filedialog, messagebox, BooleanVar, Toplevel, simpledialog
from tkinter import ttk
import webbrowser
import subprocess
import json
import os
import time
import requests
import concurrent.futures
import socket
import datetime
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

# Lấy thư mục chứa file code hiện tại
current_directory = os.path.dirname(os.path.abspath(__file__))

# (Các dòng liên quan đến logo đã bị xóa)

# Tạo thư mục "data" nếu chưa tồn tại
data_dir = os.path.join(current_directory, "data")
if not os.path.exists(data_dir):
    os.makedirs(data_dir)

# Định nghĩa đường dẫn file JSON bên trong thư mục "data"
ADV_SETTINGS_FILE = os.path.join(data_dir, "advanced_settings.json")
SAVE_FILE = os.path.join(data_dir, "saved_accounts.json")
DISPLAY_SETTINGS_FILE = os.path.join(data_dir, "display_settings.json")
FOLDER_SETTINGS_FILE = os.path.join(data_dir, "folders.json")
# File lưu key đã xác thực
KEY_FILE = os.path.join(data_dir, "key.txt")

# Hàm hỗ trợ lưu và load file JSON
def update_json(file_path, data):
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Đã lưu dữ liệu vào {file_path}")
    except Exception as e:
        print(f"Lỗi khi ghi dữ liệu vào file {file_path}: {e}")

def load_json(file_path):
    if os.path.exists(file_path):
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            print(f"Lỗi khi đọc file {file_path}: {e}")
    return {}

# Các biến toàn cục
ADV_PROFILE_PATH = os.path.join(current_directory, "profile")
if not os.path.exists(ADV_PROFILE_PATH):
    os.makedirs(ADV_PROFILE_PATH)
ADV_CHROMEDRIVER_PATH = os.path.join(current_directory, "chromedriver.exe")
FIELDS = ["uid", "email", "phone", "ten", "theo_doi", "ban_be", "nhom", "page", "ngay_sinh",
          "gioi_tinh", "mat_khau", "mail_khoi_phuc", "mat_khau_mail", "twofa", "useragent",
          "proxy", "ngay_tao", "avatar", "thu_muc", "tinh_trang", "ghi_chú"]
ALL_COLUMNS = ["stt"] + FIELDS + ["trang_thai"]

COLUMN_HEADERS = {
    "stt": "STT", "uid": "UID", "email": "Email", "phone": "Phone", "ten": "Tên",
    "theo_doi": "Theo dõi", "ban_be": "Bạn bè", "nhom": "Nhóm", "page": "Page",
    "ngay_sinh": "Ngày sinh", "gioi_tinh": "Giới tính", "mat_khau": "Mật khẩu",
    "mail_khoi_phuc": "Mail khôi phục", "mat_khau_mail": "Mật khẩu mail", "twofa": "2FA",
    "useragent": "Useragent", "proxy": "Proxy", "ngay_tao": "Ngày tạo", "avatar": "Avatar",
    "thu_muc": "Thư mục", "tinh_trang": "Tình trạng", "ghi_chú": "Ghi chú",
    "trang_thai": "Trạng Thái"
}

default_column_widths = {col: 100 for col in ALL_COLUMNS}
default_column_widths["stt"] = 50
default_column_widths["trang_thai"] = 250

class ToolMTR:
    def __init__(self, root):
        self.root = root
        self.root.title("TOOL MT - QUẢNG LÍ TÀI KHOẢNG FACEBOOK")
        self.root.geometry("1250x650")
        self.root.configure(bg="#f0f0f0")
        
        # Các dòng liên quan đến logo đã bị xóa

        self.accounts = []
        self.display_columns = {col: True for col in ALL_COLUMNS}
        self.chrome_delay = 0
        self.chrome_arrange = False
        self.load_advanced_settings()
        self.load_display_settings()
        self.folders = self.load_folders()
        self.current_folder_filter = "Tất cả"

        # Kiểm tra key trước khi cho phép sử dụng tool
        self.key_valid = False
        self.key_remaining_days = 0
        self.check_key_on_start()

        self.setup_styles()
        self.like_img = self.create_like_image()
        self.create_widgets()
        self.accounts = self.load_accounts()
        for account in self.accounts:
            account.setdefault("trang_thai", "")
        self.apply_display_columns()
        self.refresh_treeview()

    def setup_styles(self):
        style = ttk.Style()
        style.theme_use('clam')
        style.configure("TButton", background="#4CAF50", foreground="white",
                        font=("Helvetica", 10, "bold"), padding=3)
        style.map("TButton", background=[("active", "#45a049")])
        style.configure("Treeview", rowheight=25, font=("Helvetica", 10),
                        background="#ffffff", fieldbackground="#ffffff")
        style.map("Treeview", background=[("selected", "#347083")])
        style.configure("TCombobox", padding=3)

    def create_like_image(self):
        like_img = tk.PhotoImage(width=20, height=20)
        for x in range(20):
            for y in range(20):
                like_img.put("#4CAF50", (x, y))
        return like_img

    def get_ip_address(self):
        try:
            hostname = socket.gethostname()
            ip_address = socket.gethostbyname(hostname)
            return ip_address
        except Exception as e:
            return f"Lỗi: {e}"
        

    def check_key_on_start(self):
        stored_key = ""
        if os.path.exists(KEY_FILE):
            try:
                with open(KEY_FILE, "r", encoding="utf-8") as f:
                    stored_key = f.read().strip()
            except Exception as e:
                print("Lỗi đọc file key:", e)
        # Tạo cửa sổ modal yêu cầu nhập key
        self.key_modal = Toplevel(self.root)
        self.key_modal.title("Nhập KEY")
        self.key_modal.geometry("300x150")
        self.key_modal.transient(self.root)
        self.key_modal.grab_set()
    
        tk.Label(self.key_modal, text="Nhập key:").pack(pady=10)
        self.key_entry = tk.Entry(self.key_modal)
        self.key_entry.pack(pady=5)
        self.key_entry.insert(0, stored_key)
        self.key_status_label = tk.Label(self.key_modal, text="")
        self.key_status_label.pack(pady=5)
        ttk.Button(self.key_modal, text="CHECK", command=self.perform_key_check, style="TButton").pack(pady=5)
    
        self.root.wait_window(self.key_modal)
        if not self.key_valid:
            messagebox.showerror("Lỗi", "Key không hợp lệ. Tool sẽ đóng lại!")
            self.root.destroy()

    def perform_key_check(self):
        input_key = self.key_entry.get().strip()
        # URL RAW của file key.py trên GitHub (cập nhật lại nếu cần)
        key_url = "https://raw.githubusercontent.com/minhtrinh2007/key/main/key.py"
        try:
            response = requests.get(key_url, timeout=5)
            if response.status_code == 200:
                # Thực thi file key.py để lấy biến KEYS
                key_globals = {}
                exec(response.text, key_globals)
                keys = key_globals.get("KEYS", {})
            else:
                self.key_status_label.config(text="Không thể kiểm tra key!")
                return
        except Exception as e:
            self.key_status_label.config(text="Lỗi kết nối!")
            return

    # Hàm tính số ngày còn lại của key (định dạng: YYYY-MM-DD)
        def days_remaining(expiration_date_str):
            expiration_date = datetime.datetime.strptime(expiration_date_str, "%Y-%m-%d")
            today = datetime.datetime.now()
            remaining = (expiration_date - today).days
            return max(remaining, 0)

        if input_key in keys:
            remaining_days = days_remaining(keys[input_key])
            if remaining_days > 0:
                self.key_status_label.config(text=f"KEYVIP - Còn {remaining_days} ngày")
                self.key_valid = True
                self.key_remaining_days = remaining_days
                try:
                    with open(KEY_FILE, "w", encoding="utf-8") as f:
                        f.write(input_key)
                except Exception as e:
                    print("Lỗi lưu key:", e)
                self.key_modal.destroy()
            else:
                self.key_status_label.config(text="Key đã hết hạn!")
        else:
            self.key_status_label.config(text="Key sai!")

    def load_advanced_settings(self):
        global ADV_PROFILE_PATH
        if os.path.exists(ADV_SETTINGS_FILE):
            try:
                with open(ADV_SETTINGS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    ADV_PROFILE_PATH = data.get("profile_path", ADV_PROFILE_PATH)
                    if not os.path.exists(ADV_PROFILE_PATH):
                        os.makedirs(ADV_PROFILE_PATH)
                    self.chrome_delay = data.get("chrome_delay", 0)
                    self.chrome_arrange = data.get("chrome_arrange", False)
            except Exception as e:
                messagebox.showwarning("Lỗi", f"Lỗi đọc file cấu hình nâng cao: {e}")

    def save_advanced_settings(self):
        data = {
            "profile_path": ADV_PROFILE_PATH,
            "chrome_delay": self.chrome_delay,
            "chrome_arrange": self.chrome_arrange
        }
        try:
            with open(ADV_SETTINGS_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            messagebox.showerror("Lỗi", f"Không thể lưu file cấu hình nâng cao: {e}")

    def load_display_settings(self):
        if os.path.exists(DISPLAY_SETTINGS_FILE):
            try:
                with open(DISPLAY_SETTINGS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    for col in ALL_COLUMNS:
                        if col not in ["stt", "trang_thai"]:
                            self.display_columns[col] = data.get(col, True)
                    self.display_columns["trang_thai"] = True
            except Exception as e:
                print("Lỗi đọc cài đặt hiển thị:", e)

    def save_display_settings(self):
        try:
            with open(DISPLAY_SETTINGS_FILE, "w", encoding="utf-8") as f:
                json.dump({col: self.display_columns[col] for col in ALL_COLUMNS if col not in ["stt", "trang_thai"]},
                          f, ensure_ascii=False, indent=2)
        except Exception as e:
            print("Lỗi lưu cài đặt hiển thị:", e)

    def load_folders(self):
        data = load_json(FOLDER_SETTINGS_FILE)
        if not data.get("folders"):
            data["folders"] = ["Mặc định"]
            update_json(FOLDER_SETTINGS_FILE, data)
        return data["folders"]

    def save_folders(self):
        data = {"folders": self.folders}
        update_json(FOLDER_SETTINGS_FILE, data)

    def save_accounts(self):
        data = []
        for item in self.accounts:
            entry = {field: item.get(field, "") for field in FIELDS}
            entry["trang_thai"] = item.get("trang_thai", "")
            entry["color_state"] = item.get("color_state", 0)
            entry["tinh_trang"] = item.get("tinh_trang", "")
            data.append(entry)
        try:
            with open(SAVE_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            messagebox.showerror("Lỗi", f"Không thể lưu file: {e}")

    def load_accounts(self):
        if os.path.exists(SAVE_FILE):
            try:
                with open(SAVE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    for item in data:
                        for field in FIELDS:
                            item.setdefault(field, "")
                        item.setdefault("color_state", 0)
                        item.setdefault("tinh_trang", "")
                        item.setdefault("trang_thai", "")
                    return data
            except Exception as e:
                messagebox.showwarning("Lỗi", f"Lỗi đọc file: {e}")
        return []

    def create_widgets(self):
        top_frame = tk.Frame(self.root, bg="#f0f0f0")
        top_frame.grid(row=0, column=0, columnspan=2, sticky="ew", pady=5, padx=10)
        
        left_frame = tk.Frame(top_frame, bg="#f0f0f0")
        left_frame.pack(side="left", padx=5)
        tk.Label(left_frame, text="Chọn thư mục:", bg="#f0f0f0", font=("Helvetica", 9, "bold")).pack(side="left", padx=5)
        self.folder_filter_cb = ttk.Combobox(left_frame, state="readonly", style="TCombobox", width=15)
        self.update_folder_filter_options()
        self.folder_filter_cb.current(0)
        self.folder_filter_cb.bind("<<ComboboxSelected>>", self.on_folder_filter_change)
        self.folder_filter_cb.pack(side="left", padx=5)
        ttk.Button(left_frame, text="QUẢNG LÍ THƯ MỤC", command=self.manage_folders, style="TButton").pack(side="left", padx=4)
        
        right_frame = tk.Frame(top_frame, bg="#f0f0f0")
        right_frame.pack(side="right", padx=5)
        ip_address = self.get_ip_address()
        tk.Label(right_frame, text=f"Địa chỉ IP: {ip_address}", bg="#f0f0f0", font=("Helvetica", 9)).pack(side="right", padx=5)
        tk.Label(right_frame, text=f"Key: còn {self.key_remaining_days} ngày", bg="#f0f0f0", font=("Helvetica", 9)).pack(side="right", padx=5)
        btn_texts = [
            ("Thêm Tài Khoảng", self.add_account),
            ("Cài đặt hiển thị", self.display_settings),
            ("Tắt ALL CHROME", self.close_all_chrome),
            ("Thiết lập nâng cao", self.advanced_settings)
        ]
        for text, cmd in reversed(btn_texts):
            ttk.Button(right_frame, text=text, command=cmd, style="TButton").pack(side="left", padx=3)
        
        self.tree = ttk.Treeview(self.root, columns=ALL_COLUMNS, show="headings", selectmode="extended")
        for col in ALL_COLUMNS:
            self.tree.heading(col, text=COLUMN_HEADERS[col])
            self.tree.column(col, width=default_column_widths[col], minwidth=default_column_widths[col],
                             anchor="center", stretch=True)
        self.tree.tag_configure("live", background='#d0f0c0')
        self.tree.tag_configure("die", background='#ff7f7f')
        
        vsb = ttk.Scrollbar(self.root, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=vsb.set)
        hsb = ttk.Scrollbar(self.root, orient="horizontal", command=self.tree.xview)
        self.tree.configure(xscrollcommand=hsb.set)
        
        self.tree.grid(row=1, column=0, sticky="nsew", padx=10, pady=5)
        vsb.grid(row=1, column=1, sticky="ns", pady=5)
        hsb.grid(row=2, column=0, sticky="ew", padx=10)
        
        self.root.grid_rowconfigure(1, weight=1)
        self.root.grid_columnconfigure(0, weight=1)
        
        self.tree.bind("<Button-3>", self.on_right_click)
        self.tree.bind("<ButtonPress-1>", self.on_drag_start)
        self.tree.bind("<B1-Motion>", self.on_drag_update)
        self.tree.bind("<ButtonRelease-1>", self.on_drag_stop)
        self.drag_data = {"start": None, "current": None}
        bottom_frame = tk.Frame(self.root, bg="#f0f0f0")
        bottom_frame.grid(row=3, column=0, columnspan=2, sticky="ew", pady=5)
        link_label = tk.Label(bottom_frame, text="Báo Lỗi or Mua Key or Hướng Dẫn Nuôi Nick",
                              fg="blue", cursor="hand2", bg="#f0f0f0", font=("Helvetica", 10, "underline"))
        link_label.pack()
        link_label.bind("<Button-1>", lambda e: webbrowser.open("https://zalo.me/84328007257"))

    def update_folder_filter_options(self):
        options = ["Tất cả"] + self.folders
        self.folder_filter_cb["values"] = options

    def on_folder_filter_change(self, event):
        self.current_folder_filter = self.folder_filter_cb.get()
        self.refresh_treeview()

    def check_uid(self, uid):
        url = f"https://graph.facebook.com/v19.0/{uid}/picture?redirect=0"
        try:
            response = requests.get(url, timeout=5)
            json_data = response.json()
            if "error" in json_data:
                return uid, "die"
            elif "data" in json_data:
                if "url" in json_data["data"] and json_data["data"]["url"].endswith("UlIqmHJn-SK.gif"):
                    return uid, "die"
                else:
                    return uid, "live"
            return uid, "die"
        except Exception:
            return uid, "error"

    def check_live_selected(self):
        selected_uids = [self.accounts[int(iid)]["uid"] for iid in self.tree.selection()]
        if not selected_uids:
            messagebox.showwarning("Cảnh báo", "Vui lòng chọn ít nhất một UID để check")
            return
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = {executor.submit(self.check_uid, uid): uid for uid in selected_uids}
            for future in concurrent.futures.as_completed(futures):
                uid, status = future.result()
                for idx, account in enumerate(self.accounts):
                    if account["uid"] == uid:
                        account["color_state"] = 0 if status == "live" else 1
                        account["tinh_trang"] = "LIVE" if status == "live" else "DIE"
                        self.tree.item(str(idx), tags=("live" if status == "live" else "die",))
                        break
        self.save_accounts()
        messagebox.showinfo("Hoàn thành", "Đã cập nhật trạng thái các UID!")

    def apply_display_columns(self):
        visible = ["stt"] + [col for col in ALL_COLUMNS if col not in ["stt"] and self.display_columns.get(col)]
        self.tree["displaycolumns"] = visible
        for col in ALL_COLUMNS:
            if col in visible:
                self.tree.column(col, width=default_column_widths[col], minwidth=default_column_widths[col])

    def refresh_treeview(self):
        self.tree.delete(*self.tree.get_children())
        for i, item in enumerate(self.accounts):
            if self.current_folder_filter != "Tất cả":
                if item.get("thu_muc", "Mặc định") != self.current_folder_filter:
                    continue
            tag = "live" if item.get("color_state", 0) == 0 else "die"
            values = [str(i + 1)] + [item.get(field, "") for field in FIELDS] + [item.get("trang_thai", "")]
            self.tree.insert("", "end", iid=str(i), values=values, tags=(tag,))
            self.tree.item(str(i), tags=(tag,))

    def start_chrome_for_item(self, item):
        uid = item.get("uid", "").strip()
        if not uid:
            messagebox.showerror("Lỗi", "UID không hợp lệ!")
            return None
        profile_path = os.path.join(ADV_PROFILE_PATH, uid)
        os.makedirs(profile_path, exist_ok=True)
        chrome_options = Options()
        chrome_options.add_argument(f"--user-data-dir={profile_path}")
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_argument("--start-maximized")
        try:
            if not os.path.exists(ADV_CHROMEDRIVER_PATH):
                messagebox.showerror("Lỗi", "KHÔNG TÌM THẤY CHROMEDRIVER")
                return None
            service = Service(ADV_CHROMEDRIVER_PATH)
            driver = webdriver.Chrome(service=service, options=chrome_options)
            driver.get("https://www.facebook.com")
            time.sleep(5)
            current_time = time.strftime("%H:%M:%S")
            item["trang_thai"] = f"{current_time} mở chrome thành công"
            item["status"] = time.strftime("%H:%M:%S %d/%m")
            item["chrome_process"] = driver
            if self.chrome_arrange:
                self.arrange_chrome_windows()
            return driver
        except Exception as e:
            messagebox.showerror("Lỗi", str(e))
            return None

    def arrange_chrome_windows(self):
        drivers = [item.get("chrome_process") for item in self.accounts if item.get("chrome_process")]
        if not drivers:
            return
        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        columns = 5
        rows = 2
        window_width = int(screen_width / columns)
        window_height = int(screen_height / rows)
        for i, driver in enumerate(drivers):
            if i >= columns * rows:
                break
            row = i // columns
            col = i % columns
            x = col * window_width
            y = row * window_height
            try:
                driver.set_window_position(x, y)
                driver.set_window_size(window_width, window_height)
            except Exception as e:
                print("Error arranging window:", e)

    def start_row(self, row_id):
        try:
            index = int(row_id)
        except ValueError:
            return
        self.start_chrome_for_item(self.accounts[index])
        self.refresh_treeview()

    def start_selected(self):
        for iid in self.tree.selection():
            try:
                index = int(iid)
            except ValueError:
                continue
            self.start_chrome_for_item(self.accounts[index])
            if self.chrome_delay > 0:
                time.sleep(self.chrome_delay)
        self.refresh_treeview()

    def delete_selected(self):
        sels = self.tree.selection()
        if not sels:
            return
        if not messagebox.askokcancel("Xác nhận", "Bạn có chắc muốn xóa?"):
            return
        for idx in sorted([int(iid) for iid in sels], reverse=True):
            del self.accounts[idx]
        self.save_accounts()
        self.refresh_treeview()

    def advanced_edit(self):
        sels = self.tree.selection()
        if len(sels) != 1:
            messagebox.showerror("Lỗi", "Vui lòng chọn một hàng duy nhất để chỉnh sửa nâng cao!")
            return
        index = int(sels[0])
        item = self.accounts[index]
        edit_win = Toplevel(self.root)
        edit_win.title("Chỉnh sửa nâng cao")
        edit_win.geometry("500x600")
        # Không gọi iconphoto
        vars_dict = {}
        for row, field in enumerate(FIELDS):
            tk.Label(edit_win, text=COLUMN_HEADERS[field] + ":", anchor="w").grid(row=row, column=0, sticky="w", padx=5, pady=2)
            vars_dict[field] = tk.StringVar(value=item.get(field, ""))
            tk.Entry(edit_win, textvariable=vars_dict[field], width=40).grid(row=row, column=1, padx=5, pady=2)
        def save_edit():
            for field in FIELDS:
                item[field] = vars_dict[field].get().strip()
            self.save_accounts()
            self.refresh_treeview()
            edit_win.destroy()
            messagebox.showinfo("Thành công", "Thông tin tài khoản đã được cập nhật!")
        ttk.Button(edit_win, text="Lưu", command=save_edit, style="TButton").grid(row=len(FIELDS), column=0, columnspan=2, pady=10)

    def multi_advanced_edit(self):
        sels = self.tree.selection()
        if len(sels) < 2:
            messagebox.showerror("Lỗi", "Vui lòng chọn nhiều hơn một hàng để chỉnh sửa nâng cao nhiều!")
            return
        edit_win = Toplevel(self.root)
        edit_win.title("Chỉnh sửa nâng cao nhiều hàng")
        edit_win.geometry("500x400")
        # Không gọi iconphoto
        tk.Label(edit_win, text="Chọn các cột cần chỉnh sửa:").pack(pady=5)
        frame = tk.Frame(edit_win)
        frame.pack(padx=10, pady=10, fill="both", expand=True)
        var_dict = {}
        columns_per_row = 3
        for idx, field in enumerate(FIELDS):
            var = tk.BooleanVar(value=False)
            var_dict[field] = var
            tk.Checkbutton(frame, text=COLUMN_HEADERS.get(field, field.upper()), variable=var).grid(row=idx//columns_per_row, column=idx % columns_per_row, sticky="w", padx=5, pady=5)
        tk.Label(edit_win, text="Nhập nội dung chỉnh sửa (cách nhau bởi dấu '|'):").pack(pady=5)
        content_entry = tk.Entry(edit_win, width=50)
        content_entry.pack(pady=5)
        def save_multi_edit():
            selected_fields = [field for field in FIELDS if var_dict[field].get()]
            if not selected_fields:
                messagebox.showerror("Lỗi", "Bạn phải chọn ít nhất một cột để chỉnh sửa!")
                return
            parts = [p.strip() for p in content_entry.get().strip().split("|")]
            if len(parts) != len(selected_fields):
                messagebox.showerror("Lỗi", f"Số giá trị nhập ({len(parts)}) không khớp với số cột đã chọn ({len(selected_fields)})!")
                return
            for iid in sels:
                idx = int(iid)
                for field, new_val in zip(selected_fields, parts):
                    self.accounts[idx][field] = new_val
            self.save_accounts()
            self.refresh_treeview()
            edit_win.destroy()
            messagebox.showinfo("Thành công", "Đã cập nhật thông tin cho các hàng đã chọn!")
        ttk.Button(edit_win, text="Lưu", command=save_multi_edit, style="TButton").pack(pady=10)

    def advanced_copy(self):
        sels = self.tree.selection()
        if len(sels) != 1:
            messagebox.showerror("Lỗi", "Vui lòng chọn một hàng duy nhất để sao chép nâng cao!")
            return
        index = int(sels[0])
        item = self.accounts[index]
        copy_win = Toplevel(self.root)
        copy_win.title("Sao chép nâng cao")
        copy_win.geometry("1100x300")
        # Không gọi iconphoto
        top_frame = tk.Frame(copy_win)
        top_frame.pack(padx=10, pady=5, fill="x")
        num_columns = 22
        option_vars = [tk.StringVar(value="–") for _ in range(num_columns)]
        for var in option_vars:
            om = tk.OptionMenu(top_frame, var, *(["–"] + FIELDS))
            om.config(width=10)
            om.pack(side="left", padx=2)
        tk.Label(copy_win, text="Kết quả sao chép:").pack(pady=5)
        result_text = tk.Text(copy_win, width=120, height=5)
        result_text.pack(padx=10, pady=5)
        def update_result():
            mapping = [var.get() for var in option_vars]
            active_mapping = [field for field in mapping if field != "–"]
            fields_values = [item.get(field, "") for field in active_mapping]
            result = "|".join(fields_values)
            result_text.delete("1.0", tk.END)
            result_text.insert(tk.END, result)
            return result
        def do_copy():
            result = update_result()
            self.root.clipboard_clear()
            self.root.clipboard_append(result)
            messagebox.showinfo("Sao chép", f"Đã sao chép: {result}")
            copy_win.destroy()
        btn_frame = tk.Frame(copy_win)
        btn_frame.pack(pady=10)
        ttk.Button(btn_frame, text="Cập nhật kết quả", command=update_result, style="TButton").pack(side="left", padx=5)
        ttk.Button(btn_frame, text="Sao chép", command=do_copy, style="TButton").pack(side="left", padx=5)

    def multi_advanced_copy(self):
        sels = self.tree.selection()
        if not sels:
            messagebox.showerror("Lỗi", "Vui lòng chọn ít nhất một hàng để sao chép!")
            return
        copy_win = Toplevel(self.root)
        copy_win.title("Sao chép nhiều hàng")
        copy_win.geometry("1100x300")
        # Không gọi iconphoto
        top_frame = tk.Frame(copy_win)
        top_frame.pack(padx=10, pady=5, fill="x")
        num_columns = 22
        option_vars = [tk.StringVar(value="–") for _ in range(num_columns)]
        for var in option_vars:
            om = tk.OptionMenu(top_frame, var, *(["–"] + FIELDS))
            om.config(width=10)
            om.pack(side="left", padx=2)
        tk.Label(copy_win, text="Kết quả sao chép (nhiều hàng):").pack(pady=5)
        result_text = tk.Text(copy_win, width=120, height=5)
        result_text.pack(padx=10, pady=5)
        def update_result():
            mapping = [var.get() for var in option_vars]
            active_mapping = [field for field in mapping if field != "–"]
            if not active_mapping:
                messagebox.showerror("Lỗi", "Bạn phải chọn ít nhất một mục trong cấu hình!")
                return ""
            header_line = "|".join([COLUMN_HEADERS.get(field, field.upper()) for field in active_mapping])
            lines = [header_line]
            for iid in sels:
                idx = int(iid)
                row_values = [str(self.accounts[idx].get(field, "")) for field in active_mapping]
                lines.append("|".join(row_values))
            result = "\n".join(lines)
            result_text.delete("1.0", tk.END)
            result_text.insert(tk.END, result)
            return result
        def do_copy():
            result = update_result()
            if result:
                self.root.clipboard_clear()
                self.root.clipboard_append(result)
                messagebox.showinfo("Sao chép", f"Đã sao chép dữ liệu:\n{result}")
                copy_win.destroy()
        btn_frame = tk.Frame(copy_win)
        btn_frame.pack(pady=10)
        ttk.Button(btn_frame, text="Cập nhật kết quả", command=update_result, style="TButton").pack(side="left", padx=5)
        ttk.Button(btn_frame, text="Sao chép", command=do_copy, style="TButton").pack(side="left", padx=5)

    def toggle_color_selected(self):
        for iid in self.tree.selection():
            idx = int(iid)
            self.accounts[idx]["color_state"] = 1 - self.accounts[idx].get("color_state", 0)
        self.refresh_treeview()

    def move_to_folder(self):
        sels = self.tree.selection()
        if not sels:
            messagebox.showerror("Lỗi", "Vui lòng chọn ít nhất một hàng để chuyển thư mục!")
            return
        move_win = Toplevel(self.root)
        move_win.title("Chuyển vào thư mục")
        move_win.geometry("300x150")
        # Không gọi iconphoto
        tk.Label(move_win, text="Chọn thư mục để chuyển:").pack(pady=10)
        folder_var = tk.StringVar(value=self.folders[0] if self.folders else "")
        folder_menu = ttk.Combobox(move_win, textvariable=folder_var, values=self.folders, state="readonly", style="TCombobox")
        folder_menu.pack(pady=5)
        def do_move():
            target_folder = folder_var.get()
            for iid in sels:
                idx = int(iid)
                self.accounts[idx]["thu_muc"] = target_folder
            self.save_accounts()
            self.refresh_treeview()
            messagebox.showinfo("Thành công", f"Đã chuyển {len(sels)} nick vào thư mục '{target_folder}'!")
            move_win.destroy()
        ttk.Button(move_win, text="Chuyển", command=do_move, style="TButton").pack(pady=10)

    def on_drag_start(self, event):
        row_id = self.tree.identify_row(event.y)
        if row_id:
            self.drag_data["start"] = int(row_id)
            self.drag_data["current"] = int(row_id)
            if not event.state & 0x0004:
                self.tree.selection_set(row_id)

    def on_drag_update(self, event):
        if self.drag_data["start"] is None:
            return
        current_row = self.tree.identify_row(event.y)
        if current_row:
            current_row_idx = int(current_row)
            start_idx = self.drag_data["start"]
            end_idx = current_row_idx
            rows = list(range(min(start_idx, end_idx), max(start_idx, end_idx) + 1))
            if event.state & 0x0004:
                current_selection = set(map(int, self.tree.selection()))
                rows = list(current_selection.union(rows))
            self.tree.selection_set(rows)
            self.drag_data["current"] = current_row_idx

    def on_drag_stop(self, event):
        self.drag_data = {"start": None, "current": None}

    def on_right_click(self, event):
        row_id = self.tree.identify_row(event.y)
        if row_id:
            if row_id not in self.tree.selection():
                self.tree.selection_set(row_id)
            sels = self.tree.selection()
            context_menu = tk.Menu(self.root, tearoff=0)
            context_menu.add_command(label="BẮT ĐẦU", command=self.start_selected)
            context_menu.add_command(label="Check Live", command=self.check_live_selected)
            context_menu.add_command(label="XÓA", command=self.delete_selected)
            context_menu.add_command(label="CHUYỂN VÀO THƯ MỤC", command=self.move_to_folder)
            if len(sels) == 1:
                context_menu.add_command(label="CHỈNH SỬA nâng cao", command=self.advanced_edit)
                context_menu.add_command(label="Sao chép nâng cao", command=self.advanced_copy)
            else:
                context_menu.add_command(label="Chỉnh sửa nâng cao", command=self.multi_advanced_edit)
                context_menu.add_command(label="Sao chép nhiều", command=self.multi_advanced_copy)
            context_menu.post(event.x_root, event.y_root)

    def add_account(self):
        add_win = Toplevel(self.root)
        add_win.title("Thêm Tài Khoản")
        add_win.geometry("1000x550")
        # Không gọi iconphoto
        top_frame = tk.Frame(add_win)
        top_frame.pack(padx=10, pady=5, fill="x")
        num_columns = 22
        option_vars = [tk.StringVar(value="–") for _ in range(num_columns)]
        for var in option_vars:
            om = tk.OptionMenu(top_frame, var, *(["–"] + FIELDS))
            om.config(width=10)
            om.pack(side="left", padx=2)
        folder_frame = tk.Frame(add_win)
        folder_frame.pack(pady=5)
        tk.Label(folder_frame, text="Chọn thư mục:").pack(side="left", padx=5)
        folder_var = tk.StringVar(value=self.folders[0] if self.folders else "Mặc định")
        folder_cb = ttk.Combobox(folder_frame, textvariable=folder_var, values=self.folders, state="readonly", style="TCombobox")
        folder_cb.pack(side="left", padx=5)
        tk.Label(add_win, text="Nhập thông tin tài khoản (mỗi dòng là 1 tài khoản, các trường phân cách bởi dấu '|')").pack(pady=5)
        text_area = tk.Text(add_win, width=120, height=15)
        text_area.pack(padx=10, pady=5)
        def confirm_add():
            mapping = [var.get() for var in option_vars]
            active_mapping = [field for field in mapping if field != "–"]
            if not active_mapping:
                messagebox.showerror("Lỗi", "Bạn phải chọn ít nhất 1 mục để nhập thông tin!")
                return
            if len(active_mapping) != len(set(active_mapping)):
                messagebox.showerror("Lỗi", "Có trùng lặp trong cấu hình các mục. Vui lòng chọn mỗi mục chỉ một lần!")
                return
            new_accounts = []
            for line in text_area.get("1.0", tk.END).strip().split("\n"):
                parts = [p.strip() for p in line.strip().split("|")]
                if len(parts) != len(active_mapping):
                    messagebox.showerror("Lỗi", f"Số trường ở dòng\n'{line}'\nkhông khớp với số cột đã chọn ({len(active_mapping)}).")
                    return
                account = {field: parts[i] for i, field in enumerate(active_mapping)}
                if not account.get("uid", ""):
                    messagebox.showerror("Lỗi", f"Mỗi tài khoản phải có UID! (Dòng: {line})")
                    return
                if any(acc.get("uid", "") == account["uid"] for acc in self.accounts):
                    messagebox.showerror("Lỗi", f"Tài khoản đã tồn tại: {account['uid']}")
                    return
                if not account.get("thu_muc", ""):
                    account["thu_muc"] = folder_var.get()
                account.update({"color_state": 0, "status": "", "chrome_process": None, "trang_thai": ""})
                new_accounts.append(account)
            self.accounts.extend(new_accounts)
            self.save_accounts()
            self.refresh_treeview()
            add_win.destroy()
            messagebox.showinfo("Thành công", f"Đã thêm {len(new_accounts)} tài khoản!")
        btn_frame = tk.Frame(add_win)
        btn_frame.pack(pady=10)
        ttk.Button(btn_frame, text="Đóng", command=add_win.destroy, style="TButton").pack(side="left", padx=5)
        ttk.Button(btn_frame, text="Thêm Tài Khoản", command=confirm_add, style="TButton").pack(side="left", padx=5)

    def close_all_chrome(self):
        try:
            subprocess.run(["taskkill", "/F", "/IM", "chrome.exe"], shell=True, check=True)
            messagebox.showinfo("Thành công", "Đã tắt tất cả Chrome!")
        except Exception as e:
            messagebox.showerror("Lỗi", f"Không thể tắt Chrome: {e}")

    def display_settings(self):
        self.load_display_settings()
        set_win = Toplevel(self.root)
        set_win.title("Cài đặt hiển thị")
        set_win.geometry("400x300")
        # Không gọi iconphoto
        var_dict = {}
        columns_to_show = [col for col in ALL_COLUMNS if col not in ["stt", "trang_thai"]]
        frame = tk.Frame(set_win)
        frame.pack(padx=10, pady=10, fill="both", expand=True)
        columns_per_row = 3
        for idx, c in enumerate(columns_to_show):
            var = BooleanVar(value=self.display_columns.get(c, True))
            var_dict[c] = var
            tk.Checkbutton(frame, text=COLUMN_HEADERS.get(c, c.upper()), variable=var).grid(row=idx//columns_per_row, column=idx % columns_per_row, sticky="w", padx=5, pady=5)
        btn_frame = tk.Frame(set_win)
        btn_frame.pack(pady=10)
        def apply_settings():
            for c in columns_to_show:
                self.display_columns[c] = var_dict[c].get()
            self.apply_display_columns()
            self.save_display_settings()
            set_win.destroy()
        ttk.Button(btn_frame, text="OK", command=apply_settings, style="TButton").pack(side="left", padx=5)
        ttk.Button(btn_frame, text="Hủy", command=set_win.destroy, style="TButton").pack(side="left", padx=5)

    def advanced_settings(self):
        global ADV_PROFILE_PATH
        adv_win = Toplevel(self.root)
        adv_win.title("Thiết lập nâng cao")
        adv_win.geometry("400x300")
        # Không gọi iconphoto
        tk.Label(adv_win, text="Đường dẫn lưu/truy xuất profile:").pack(pady=5)
        profile_var = tk.StringVar(value=ADV_PROFILE_PATH)
        tk.Entry(adv_win, textvariable=profile_var, width=50).pack()
        ttk.Button(adv_win, text="Chọn thư mục", command=lambda: profile_var.set(filedialog.askdirectory()), style="TButton").pack(pady=5)
        tk.Label(adv_win, text="Thời gian chờ giữa các lần mở chrome (giây):").pack(pady=5)
        delay_var = tk.StringVar(value=str(self.chrome_delay))
        tk.Entry(adv_win, textvariable=delay_var, width=10).pack()
        arrange_var = tk.BooleanVar(value=self.chrome_arrange)
        tk.Checkbutton(adv_win, text="Sắp xếp chrome", variable=arrange_var).pack(pady=5)
        def save_adv():
            global ADV_PROFILE_PATH
            ADV_PROFILE_PATH = profile_var.get()
            if not os.path.exists(ADV_PROFILE_PATH):
                os.makedirs(ADV_PROFILE_PATH)
            try:
                self.chrome_delay = float(delay_var.get()) if delay_var.get() else 0
            except ValueError:
                messagebox.showerror("Lỗi", "Thời gian delay phải là số!")
                return
            self.chrome_arrange = arrange_var.get()
            self.save_advanced_settings()
            adv_win.destroy()
            messagebox.showinfo("Thành công", "Đã lưu thiết lập nâng cao!")
        ttk.Button(adv_win, text="Lưu", command=save_adv, style="TButton").pack(pady=10)
        ttk.Button(adv_win, text="Hủy", command=adv_win.destroy, style="TButton").pack()

    def manage_folders(self):
        folder_win = Toplevel(self.root)
        folder_win.title("Quản lý thư mục")
        folder_win.geometry("400x300")
        # Không gọi iconphoto
        tk.Label(folder_win, text="Danh sách thư mục:").pack(pady=5)
        listbox = tk.Listbox(folder_win)
        listbox.pack(padx=10, pady=5, fill="both", expand=True)
        for folder in self.folders:
            listbox.insert(tk.END, folder)
        btn_frame = tk.Frame(folder_win)
        btn_frame.pack(pady=10)
        def add_folder():
            new_folder = simpledialog.askstring("Thêm thư mục", "Nhập tên thư mục mới:")
            if new_folder:
                if new_folder in self.folders:
                    messagebox.showerror("Lỗi", "Thư mục đã tồn tại!")
                else:
                    self.folders.append(new_folder)
                    self.save_folders()
                    listbox.insert(tk.END, new_folder)
                    self.update_folder_filter_options()
        def delete_folder():
            sel = listbox.curselection()
            if not sel:
                messagebox.showerror("Lỗi", "Vui lòng chọn thư mục cần xóa!")
                return
            folder_to_delete = listbox.get(sel[0])
            if messagebox.askokcancel("Xác nhận", f"Bạn có chắc muốn xóa thư mục '{folder_to_delete}'?"):
                self.folders.remove(folder_to_delete)
                self.save_folders()
                listbox.delete(sel[0])
                self.update_folder_filter_options()
                for account in self.accounts:
                    if account.get("thu_muc", "Mặc định") == folder_to_delete:
                        account["thu_muc"] = "Mặc định"
                self.save_accounts()
                self.refresh_treeview()
        ttk.Button(btn_frame, text="Thêm thư mục", command=add_folder, style="TButton").pack(side="left", padx=5)
        ttk.Button(btn_frame, text="Xóa thư mục", command=delete_folder, style="TButton").pack(side="left", padx=5)
        ttk.Button(btn_frame, text="Đóng", command=folder_win.destroy, style="TButton").pack(side="left", padx=5)

if __name__ == "__main__":
    root = tk.Tk()
    # Không gọi iconphoto ở cửa sổ chính vì không có logo
    app = ToolMTR(root)
    root.mainloop()
