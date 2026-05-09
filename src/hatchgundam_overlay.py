import json
import os
import sys
import tkinter as tk
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageTk


APP_NAME = "hatchgundam"
HOME = Path.home()

STATUS_SOURCES = [
    ("codex", HOME / ".codex" / "codex_status.json"),
    ("claude", HOME / ".claude" / "claude_status.json"),
]

COLS = 8
ROWS = 9
CELL_W = 192
CELL_H = 208

DISPLAY_W = CELL_W // 2
DISPLAY_H = CELL_H // 2
TEXT_AREA_H = 20
WINDOW_H = DISPLAY_H + TEXT_AREA_H

STATE_ROWS = {
    "idle": 0,
    "running": 1,
    "waiting": 2,
    "awaiting_permission": 3,
    "permission": 3,
    "perm": 3,
}

STATE_LABELS = {
    "idle": "idle",
    "running": "run",
    "waiting": "wait",
    "awaiting_permission": "perm",
    "permission": "perm",
    "perm": "perm",
}

FRAME_INTERVAL = 150
STATUS_POLL_INTERVAL = 500


def _base_dir():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent.parent


def _bundle_dir():
    if hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS)
    return _base_dir()


def _sprite_candidates():
    env_path = os.environ.get("HATCHGUNDAM_SPRITE_PATH")
    if env_path:
        yield Path(env_path)
    yield _base_dir() / "assets" / "spritesheet.webp"
    yield _bundle_dir() / "assets" / "spritesheet.webp"
    yield HOME / ".codex" / "pets" / "hatchgundam" / "spritesheet.webp"


def _find_sprite_path():
    for candidate in _sprite_candidates():
        if candidate.exists():
            return candidate
    return None


def _parse_timestamp(value):
    if not value:
        return None
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
        except ValueError:
            return None
    return None


def _remove_translucent_pixels(image):
    alpha = image.getchannel("A")
    alpha = alpha.point(lambda value: 255 if value >= 80 else 0)
    image.putalpha(alpha)
    return image


class HatchgundamOverlay:
    def __init__(self):
        sprite_path = _find_sprite_path()
        if sprite_path is None:
            raise FileNotFoundError("spritesheet.webp not found")

        self.root = tk.Tk()
        self.root.title(APP_NAME)
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.attributes("-transparentcolor", "magenta")

        sheet = Image.open(sprite_path).convert("RGBA")
        self.frames = self._extract_frames(sheet)

        self.current_state = "idle"
        self.current_frame = 0
        self.last_status_signature = None

        screen_w = self.root.winfo_screenwidth()
        x = screen_w - DISPLAY_W - 20
        y = 60
        self.root.geometry(f"{DISPLAY_W}x{WINDOW_H}+{x}+{y}")

        self.canvas = tk.Canvas(
            self.root,
            width=DISPLAY_W,
            height=WINDOW_H,
            bg="magenta",
            highlightthickness=0,
        )
        self.canvas.pack()

        self.image_id = self.canvas.create_image(
            DISPLAY_W // 2, DISPLAY_H // 2, image=None
        )
        self.canvas.create_rectangle(
            0, DISPLAY_H, DISPLAY_W, WINDOW_H, fill="black", outline=""
        )
        self.status_text = self.canvas.create_text(
            DISPLAY_W // 2,
            DISPLAY_H + TEXT_AREA_H // 2,
            text="idle",
            fill="white",
            font=("Arial", 9, "bold"),
        )

        self.canvas.bind("<Button-1>", self._start_drag)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<Button-3>", lambda _event: self.root.destroy())

        self._drag_x = 0
        self._drag_y = 0

        self._update_frame()
        self._poll_status()

    def _extract_frames(self, sheet):
        frames = {}
        for row in range(ROWS):
            row_frames = []
            for col in range(COLS):
                left = col * CELL_W
                upper = row * CELL_H
                right = left + CELL_W
                lower = upper + CELL_H
                cell = sheet.crop((left, upper, right, lower))
                if cell.getbbox() is not None:
                    cell = cell.resize((DISPLAY_W, DISPLAY_H), Image.LANCZOS)
                    cell = _remove_translucent_pixels(cell)
                    row_frames.append(ImageTk.PhotoImage(cell))
            if row_frames:
                frames[row] = row_frames
        return frames

    def _read_source(self, source, path):
        try:
            if not path.exists():
                return None
            stat = path.stat()
            with open(path, "r", encoding="utf-8-sig") as status_file:
                data = json.load(status_file)
            status = str(data.get("status", "idle"))
            updated_at = _parse_timestamp(data.get("updated_at") or data.get("timestamp"))
            freshness = updated_at if updated_at is not None else stat.st_mtime
            return {
                "source": source,
                "status": status,
                "freshness": freshness,
                "signature": (source, str(path), stat.st_mtime_ns, stat.st_size),
            }
        except (json.JSONDecodeError, OSError):
            return None

    def _read_status(self):
        candidates = [
            status
            for source, path in STATUS_SOURCES
            if (status := self._read_source(source, path)) is not None
        ]
        if not candidates:
            return None

        candidates.sort(key=lambda item: item["freshness"], reverse=True)
        selected = candidates[0]
        signature = selected["signature"]
        if signature == self.last_status_signature:
            return None
        self.last_status_signature = signature
        return selected

    def _poll_status(self):
        status = self._read_status()
        if status:
            new_state = status["status"]
            if new_state != self.current_state:
                self.current_state = new_state
                self.current_frame = 0
            label = STATE_LABELS.get(new_state, new_state)
            self.canvas.itemconfig(self.status_text, text=label)
        self.root.after(STATUS_POLL_INTERVAL, self._poll_status)

    def _update_frame(self):
        row = STATE_ROWS.get(self.current_state, 0)
        row_frames = self.frames.get(row) or self.frames.get(0, [])
        if row_frames:
            frame_img = row_frames[self.current_frame % len(row_frames)]
            self.canvas.itemconfig(self.image_id, image=frame_img)
            self.current_frame += 1
        self.root.after(FRAME_INTERVAL, self._update_frame)

    def _start_drag(self, event):
        self._drag_x = event.x_root - self.root.winfo_x()
        self._drag_y = event.y_root - self.root.winfo_y()

    def _on_drag(self, event):
        x = event.x_root - self._drag_x
        y = event.y_root - self._drag_y
        self.root.geometry(f"+{x}+{y}")

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    app = HatchgundamOverlay()
    app.run()
