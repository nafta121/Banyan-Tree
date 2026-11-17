# Porting Twilight of the Banyan Tree ke Godot 4 Android Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membangun ulang (*porting*) *Twilight of the Banyan Tree* secara utuh ke **Godot 4 (`4.7.2-stable`) Android** pada cabang `godot4-android` menggunakan arsitektur data **Custom `Resource` (`.tres`)**, antarmuka **Minimalis Modern Satu Tangan (*Portrait*)**, penyimpanan *Autosave* + 5 Slot Manual, serta menghasilkan berkas `.apk` (`arm64-v8a`) pribadi siap pasang.

**Architecture:** Konverter deterministik Python (`tools/convert_json_to_tres.py`) mengubah seluruh 66 berkas JSON hulu (`data/language/english/` & `indonesian/`) satu kali menjadi berkas `Resource` `.tres` bertipe statis di `godot/resources/`, sementara `project.godot` di akar repositori memakai aset `res://photo/` dan `res://audio/` secara langsung tanpa duplikasi (mengabaikan kode web warisan via `.gdignore`). Delapan *Autoload* GDScript modular menjalankan simulasi politik, AI oposisi, pemilu 700 kursi, penyimpanan multi-slot, serta audio dua bus di balik *Scene* `Control` vertikal tiga zona (`412×915`, ramah jempol di paruh bawah layar).

**Tech Stack:** Godot Engine `4.7.2-stable` (GDScript 2.0, `Forward+`/`Mobile`/`Compatibility` GLES3 Android renderer), Python 3.11 (konverter `.tres` satu kali), OpenJDK 17 + Android Command-Line Build Tools (`sdkmanager` / `apksigner` + GitHub Actions CI).

**Spec:** `docs/superpowers/specs/2026-11-17-godot4-android-port-design.md`

## Global Constraints

- **Cabang Git**: Seluruh implementasi dikerjakan di cabang `godot4-android`; cabang `main` tidak boleh diubah.
- **Versi Mesin & Penghematan Daya**: Godot `4.7.2-stable` (`config_version=5`), `application/run/low_processor_usage_mode = true`, perender seluler `gl_compatibility` agar ringan di seluruh GPU Android.
- **Bebas Duplikasi Media**: `project.godot` berada di akar repositori; folder `js/`, `css/`, `data/`, `docs/`, dan `tools/` wajib memiliki berkas `.gdignore` agar tidak masuk ke `.apk`.
- **Layar & Ergonomi Satu Tangan**: Orientasi `portrait` (`window/size/viewport_width = 412`, `viewport_height = 915`, `stretch/mode = "canvas_items"`, `stretch/aspect = "expand"`), menghormati `DisplayServer.get_display_safe_area()`, tinggi minimum elemen sentuh interaktif `>= 48` px logis, seluruh tombol pilihan & tab navigasi berada di paruh bawah layar.
- **Bahasa & Tema Bawaan**: Bahasa awal `id` (`Bahasa Indonesia`) dengan pergantian instan ke `en` (`English`); tema awal `midnight_slate` (`#0F1419`) dengan alternatif `editorial_paper` (`#F6F4EF`) dan skala huruf `0.85..1.40`.
- **Kabut Informasi & Transparansi (`show_exact_numbers`)**: Default `false` (hanya `PC` dan jumlah kursi yang berupa angka; statistik, stabilitas, dan loyalitas fraksi tampil kualitatif tanpa angka delta pasca-pilihan). Bila diaktifkan (`true`), tampilkan angka `0–100`, bar progres kontinu, lantai dekrit, dan chip delta pasca-pilihan.
- **Penyimpanan Koleksi Pribadi**: Menyediakan `user://saves/autosave.tres` + 5 slot manual `slot_1.tres..slot_5.tres` (beserta ekspor/impor berkas cadangan) tanpa mendiskualifikasi ke-59 *achievements*.
- **Paritas Rumus & Perbaikan 5 Bug Hulu**: Wajib menjaga kuorum ganda `grand_total_for > grand_total_against and grand_total_for >= 351` terhadap ukuran majelis asli (`700` kursi), sekaligus mengaktifkan 22 pesan *loading*, memperbaiki `SSS` `show_option_effects = not hide_forecast`, auto-skip audio gagal muat, `weighted_shuffle` patuh genre + fallback 6 lagu, pemisahan bus `Music`/`SFX`, dan dukungan `'ucn'` pada pencapaian ambang statistik.

## Review Focus

1. **Markup Warisan Tak Seimbang & Escape `$$` pada Konversi JSON ke `.tres` (`Task 2`)**: Teks hulu memuat kode warna tak tertutup (`<b>§R$DRIFT$§</b>`), dolar ganda `US$$43`, `<br><br>`, `<font color>`, serta rekursi `$tier.*$`; konverter dan `LocaleService.tr_fmt()` wajib menghasilkan BBCode valid seimbang tanpa bocoran karakter `§` atau loop tak berujung.
2. **Pengosongan 30 Kursi (`dissolve_golkar_old_guard`) & Realokasi Berantai pada Fraksi Terlarang (`Task 3` & `Task 4`)**: Saat penerima kursi pada `ban_pdip_subversion` (mis. `utusan_golongan`) sudah lebih dulu dibubarkan oleh `purge_utusan_golongan`, kursi wajib dibagi proporsional hanya ke penerima yang masih aktif tanpa selisih pembulatan, sementara kuorum menang di `ElectionManager` tetap terkunci di `351` suara meskipun kursi aktif menyusut ke `670`.
3. **Pemuatan Slot Manual Lintas Fase Peleburan *Poros Tengah* (`Task 5`)**: Memuat slot simpanan Giliran 10 (sebelum T18) ketika permainan aktif sedang berada di Giliran 20 (setelah `ppp` & `pkb` melebur jadi `163` kursi `poros_tengah` dan TNI dalam fase `anger`) wajib memulihkan daftar 10 fraksi awal dan sub-state `OppositionManager` secara utuh tanpa kebocoran referensi.
4. **Lagu Gagal Dimuat, Filter Genre *International* pada *Weighted Shuffle*, & Bus SFX Mandiri (`Task 5`)**: Kegagalan membuka berkas MP3 wajib memicu lompatan otomatis ke lagu valid berikutnya (tanpa rekursi tak terbatas), mengaktifkan *Weighted Shuffle* pada genre `international` tidak boleh macet meski ke-5 lagunya tidak punya tag asli di JSON hulu, dan volume `Music = 0.0` tidak boleh membisukan bus `SFX`.
5. **Tombol *Back* Fisik/Gestur Android pada Tumpukan *Bottom Sheet* (`Task 6`)**: Menekan gestur *Back* Android (`NOTIFICATION_WM_GO_BACK_REQUEST` / `ui_cancel`) saat satu atau lebih `BottomSheet` terbuka wajib menutup lembar paling atas terlebih dahulu—bukan keluar dari aplikasi atau menyisakan penghalang transparan yang mengunci klik.

---

## Peta Struktur Berkas Proyek

```text
project.godot                                         # Konfigurasi engine Godot 4.7.2, Autoloads, Portrait 412x915
default_bus_layout.tres                               # 3 AudioBus: Master, Music, SFX
export_presets.cfg                                    # Konfigurasi ekspor Android APK (arm64-v8a)
js/.gdignore, css/.gdignore, data/.gdignore, docs/.gdignore, tools/.gdignore
tools/convert_json_to_tres.py                         # Konverter satu kali 66 JSON -> godot/resources/**/*.tres
godot/
├── scripts/
│   ├── resources/
│   │   ├── locale_pack_data.gd                       # class_name LocalePackData
│   │   ├── event_option_data.gd                      # class_name EventOptionData
│   │   ├── crisis_event_data.gd                      # class_name CrisisEventData
│   │   ├── routine_action_data.gd                    # class_name RoutineActionData
│   │   ├── decree_data.gd                            # class_name DecreeData
│   │   ├── faction_deal_data.gd                      # class_name FactionDealData
│   │   ├── faction_merged_data.gd                    # class_name FactionMergedData
│   │   ├── faction_data.gd                           # class_name FactionData
│   │   ├── difficulty_data.gd                        # class_name DifficultyData
│   │   ├── sss_card_data.gd                          # class_name SSSCardData
│   │   ├── library_entry_data.gd                     # class_name LibraryEntryData
│   │   ├── achievement_data.gd                       # class_name AchievementData
│   │   ├── music_track_data.gd                       # class_name MusicTrackData
│   │   ├── stat_tier_data.gd                         # class_name StatTierData
│   │   ├── campaign_save_data.gd                     # class_name CampaignSaveData
│   │   ├── user_settings_data.gd                     # class_name UserSettingsData
│   │   └── game_catalog_data.gd                      # class_name GameCatalogData
│   ├── autoload/
│   │   ├── content_db.gd                             # Autoload ContentDB
│   │   ├── locale_service.gd                         # Autoload LocaleService
│   │   ├── sss_controller.gd                         # Autoload SSSController
│   │   ├── opposition_manager.gd                     # Autoload OppositionManager
│   │   ├── campaign_manager.gd                       # Autoload CampaignManager
│   │   ├── election_manager.gd                       # Autoload ElectionManager
│   │   ├── achievement_service.gd                    # Autoload AchievementService
│   │   ├── save_and_settings_service.gd              # Autoload SaveAndSettingsService
│   │   ├── audio_controller.gd                       # Autoload AudioController
│   │   └── theme_manager.gd                          # Autoload ThemeManager
│   └── ui/
│       ├── safe_area_shell.gd                        # Penyesuai margin poni/gestur + router Back Android
│       ├── bottom_sheet_host.gd                      # Manajer tumpukan BottomSheet satu tangan
│       ├── widgets/
│       │   ├── stat_card_widget.gd                   # Bar/segmen adaptif show_exact_numbers
│       │   ├── hemicycle_canvas.gd                   # Vektor _draw() 700 kursi MPR
│       │   └── sss_graph_canvas.gd                   # Kanvas 2D geser-cubit 24 kartu SSS
│       └── screens/
│           ├── boot_loader_screen.gd                 # Layar muat + 22 pesan loading pulih
│           ├── title_screen.gd                       # Menu utama, Lanjut, Muat Slot, Bahasa, Changelog
│           ├── difficulty_screen.gd                  # 4 Kesulitan + SSS (Mode Daftar & Node 2D) + Briefing
│           ├── campaign_shell_screen.gd              # Shell utama 3 zona + 5 tab bawah
│           ├── agenda_tab_view.gd                    # Krisis, Aksi Rutin, Dekrit, Lobi Fraksi, Horse-Trading
│           ├── editorial_press_sheet.gd              # Lembar reaksi 14 media + chip delta opsional
│           ├── stat_dashboard_tab_view.gd            # 7 Stat, Stabilitas, Tiga Pilar Golkar A-B-G, Gazette
│           ├── mpr_parliament_tab_view.gd            # Hemisikel + 10 kartu kaukus & Favor
│           ├── library_tab_view.gd                   # Pencarian, 9 kategori, 112 entri + mode Criticism
│           ├── more_drawer_tab_view.gd               # Pemutar Musik, 5 Slot Simpan/Muat, 59 Achievement, Setelan
│           └── election_and_epilogue_screen.gd       # Malam SU MPR 19 Okt, TAP MPR, PNG Export, Epilog
├── scenes/                                           # Berkas .tscn pasangan 1:1 untuk ui/screens & widgets
├── resources/                                        # Hasil konversi .tres (locales/, catalog.tres)
└── tests/
    ├── test_base.gd                                  # Utilitas asersi ringan
    ├── run_tests.gd                                  # SceneTree runner: godot --headless -s godot/tests/run_tests.gd
    ├── test_resources_and_locale.gd
    ├── test_campaign_and_sss.gd
    ├── test_opposition_election_achievements.gd
    ├── test_save_and_audio.gd
    └── test_ui_smoke_and_back_navigation.gd
.github/workflows/build-android-apk.yml               # Workflow CI otomatis pembangun APK
```

---

### Task 1: Fondasi Proyek Godot 4.7.2, Isolasi `.gdignore`, Bus Audio, & Kerangka Uji Headless

**Files:**
- Create: `project.godot`
- Create: `default_bus_layout.tres`
- Create: `js/.gdignore`, `css/.gdignore`, `data/.gdignore`, `docs/.gdignore`, `tools/.gdignore`
- Create: `godot/tests/test_base.gd`
- Create: `godot/tests/run_tests.gd`

**Interfaces:**
- Produces:
  - Binary CLI `~/.local/bin/godot` (`Godot_v4.7.2-stable_linux.x86_64` di ruang pengguna lokal, tidak di-commit ke Git)
  - `class_name TestBase extends RefCounted` dengan `assert_eq(actual, expected, msg := "")`, `assert_true(cond: bool, msg := "")`, `assert_near(a: float, b: float, eps := 0.01, msg := "")`
  - `godot/tests/run_tests.gd` (`extends SceneTree`) yang memuat dan menjalankan seluruh berkas `res://godot/tests/test_*.gd` lalu keluar dengan kode `0` (lulus) atau `1` (gagal)
  - AudioBus `Master` (idx `0`), `Music` (idx `1`), `SFX` (idx `2`) pada `default_bus_layout.tres`

- [ ] **Step 1: Pasang biner Godot `4.7.2-stable` Linux x86_64 di `~/.local/bin/godot`**

Unduh rilis resmi dari `godotengine/godot` melalui `gh release download 4.7.2-stable -R godotengine/godot -p "*linux.x86_64.zip" -D /tmp/godot_dl`, ekstrak ke `~/.local/bin/godot`, dan verifikasi ` ~/.local/bin/godot --version` mencetak `4.7.2.stable`.

- [ ] **Step 2: Buat berkas `.gdignore`, `default_bus_layout.tres`, `project.godot`, dan runner uji awal yang menguji bus audio & konfigurasi viewport**

Buat `godot/tests/test_base.gd` dan `godot/tests/run_tests.gd` yang memeriksa:
```gdscript
assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 412)
assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 915)
assert_eq(ProjectSettings.get_setting("application/run/low_processor_usage_mode"), true)
assert_eq(AudioServer.get_bus_index("Music"), 1)
assert_eq(AudioServer.get_bus_index("SFX"), 2)
```
Sebelum `default_bus_layout.tres` dan `project.godot` diisi lengkap, jalankan `~/.local/bin/godot --headless -s godot/tests/run_tests.gd` dan pastikan gagal (`exit code 1`).

- [ ] **Step 3: Lengkapi `project.godot` dan `default_bus_layout.tres`**

Setel `config_version=5`, `run/main_scene="res://godot/scenes/boot_loader_screen.tscn"` (stub minimal sementara), `low_processor_usage_mode=true`, `handheld/orientation=1` (portrait), `stretch/mode="canvas_items"`, `stretch/aspect="expand"`, renderer `gl_compatibility`, serta `audio/buses/default_bus_layout="res://default_bus_layout.tres"` dengan bus `Master`, `Music`, dan `SFX`. Tambahkan `.gitignore` untuk `.godot/` dan `build/*.apk`.

- [ ] **Step 4: Jalankan runner uji headless untuk memastikan lulus**

Run: `~/.local/bin/godot --headless --import && ~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS` dengan `exit code 0`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore project.godot default_bus_layout.tres js/.gdignore css/.gdignore data/.gdignore docs/.gdignore tools/.gdignore godot/
git commit -m "chore(godot): initialize Godot 4.7.2 portrait project, audio buses, and headless test runner"
```

---

### Task 2: Skema Kelas `Resource` (`.tres`), Konverter `convert_json_to_tres.py`, `ContentDB`, & `LocaleService`

**Files:**
- Create: `godot/scripts/resources/*.gd` (17 berkas kelas `Resource` sesuai Peta Struktur Berkas)
- Create: `tools/convert_json_to_tres.py`
- Create: `godot/scripts/autoload/content_db.gd`
- Create: `godot/scripts/autoload/locale_service.gd`
- Create: `godot/resources/catalog.tres`, `godot/resources/locales/id.tres`, `godot/resources/locales/en.tres` (dihasilkan skrip)
- Create: `godot/tests/test_resources_and_locale.gd`
- Modify: `project.godot` (daftarkan Autoload `ContentDB` dan `LocaleService`)

**Interfaces:**
- Produces:
  - `ContentDB` (`Node`):
    - `var catalog: GameCatalogData`
    - `func get_event_by_turn(turn_one_based: int) -> CrisisEventData`
    - `func get_decree(id: String) -> DecreeData`
    - `func get_routine(id: String) -> RoutineActionData`
    - `func get_faction(id: String) -> FactionData`
    - `func get_difficulty(id: String) -> DifficultyData`
  - `LocaleService` (`Node`):
    - `signal locale_changed(new_locale: String)`
    - `var current_locale: String` (`"id"` atau `"en"`, default `"id"`)
    - `var active_palette_is_dark: bool` (default `true`)
    - `func set_locale(locale_code: String) -> void`
    - `func has_key(key: String) -> bool`
    - `func tr_fmt(key_or_raw: String, vars: Dictionary = {}) -> String` (resolusi kamus `current_locale` -> fallback `"en"`, interpolasi `$VAR$` rekursif maks kedalaman `8`, `$$` -> `$`, dan penggantian token warna `[color=__TOKEN__]` ke hex sesuai `active_palette_is_dark`)
    - `func get_loading_messages() -> PackedStringArray` (mengembalikan 11 kalimat loading sesuai bahasa aktif dari total 22 kalimat yang dipulihkan)

- [ ] **Step 1: Tulis pengujian gagal `godot/tests/test_resources_and_locale.gd`**

Uji jumlah eksak dan keutuhan data serta kasus tepi **Review Focus #1**:
```gdscript
assert_eq(ContentDB.catalog.events.size(), 23)
var total_opts := 0
for ev in ContentDB.catalog.events: total_opts += ev.options.size()
assert_eq(total_opts, 111)
assert_eq(ContentDB.catalog.routines.size(), 36)
assert_eq(ContentDB.catalog.decrees.size(), 35)
assert_eq(ContentDB.catalog.factions.size(), 10)
var total_seats := 0
for f in ContentDB.catalog.factions: total_seats += f.initial_seats
assert_eq(total_seats, 700)
assert_eq(ContentDB.catalog.sss_cards.size(), 24)
assert_eq(ContentDB.catalog.library_entries.size(), 112)
assert_eq(ContentDB.catalog.achievements.size(), 59)
assert_eq(ContentDB.catalog.music_tracks.size(), 36)
assert_eq(LocaleService.get_loading_messages().size(), 11)
# Review Focus #1: unclosed § color code, $$ literal dollar, no raw HTML/§ left
for lang in ["id", "en"]:
    LocaleService.set_locale(lang)
    for ev in ContentDB.catalog.events:
        var desc := LocaleService.tr_fmt(ev.desc_key)
        assert_true(not desc.contains("§") and not desc.contains("<br"), "clean BBCode in " + ev.id)
    var pill := LocaleService.tr_fmt("faction.golkar_pillars.g.effect", {"DRIFT": "+1"})
    assert_true(pill.count("[color=") == pill.count("[/color]"), "balanced color tags")
assert_eq(LocaleService.tr_fmt("Cadangan US$$43 miliar"), "Cadangan US$43 miliar")
```

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL` karena kelas `Resource`, `ContentDB`, dan `catalog.tres` belum ada.

- [ ] **Step 3: Implementasikan ke-17 kelas `Resource`, `tools/convert_json_to_tres.py`, `ContentDB`, dan `LocaleService`**

Pada `tools/convert_json_to_tres.py`:
- Baca seluruh JSON di `data/language/english/` dan `data/language/indonesian/` (termasuk `interface/loading_messages.json` array `en`/`id` secara langsung sebelum perataan kamus sehingga ke-22 pesan *loading* pulih utuh).
- Pecah seluruh 111 `alertMsg` pada `events.json` dengan regex `^([A-Z0-9\s.&'/\-]{2,45}):\s*['"](.+?)['"]\s*<br><br>([\s\S]+)$` ke `press_outlet`, `press_category` (`broadsheet`, `tabloid`, `magazine`, `financial`, `browser`, `international`), `press_headline_key`, dan `press_body_key`.
- Ubah `<b>`/`</b>` -> `[b]`/`[/b]`, `<i>`/`</i>` -> `[i]`/`[/i]`, `<br\s*/?>` -> `\n`, `<font color="...">` & 21 kode `§` (`localization.js:13-37`) menjadi token `[color=__STAT_POP__]...[/color]` dengan penutupan otomatis tumpukan tag tak tertutup di akhir kalimat (memperbaiki salah ketik `<b>§R$DRIFT$§</b>` dan spasi `network.<b>§CCendana` pada `gameplay.json`).
- Sesuaikan kalimat tutorial yang menyebut panel kiri desktop/ketiadaan angka menjadi panduan antarmuka *portrait* satu tangan dan sakelar *Tampilkan Angka Eksak*.
- Tulis berkas teks `.tres` berformat Godot `[gd_resource type="Resource" script_class="..." load_steps=... format=3]` untuk `locales/id.tres`, `locales/en.tres`, dan `catalog.tres` (yang menyematkan sub-resource terurut agar satu muatan `ResourceLoader.load("res://godot/resources/catalog.tres")` sangat cepat).

- [ ] **Step 4: Jalankan konverter dan verifikasi seluruh pengujian lulus**

Run: `python3 tools/convert_json_to_tres.py && ~/.local/bin/godot --headless --import && ~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS` dengan `0` kunci hilang dan seluruh hitungan resource cocok 100%.

- [ ] **Step 5: Commit**

```bash
git add tools/convert_json_to_tres.py godot/ project.godot
git commit -m "feat(data): add typed Resource schemas, JSON-to-tres converter, ContentDB, and LocaleService"
```

---

### Task 3: Pengendali `SSS` (`SSSController`) & Mesin Kampanye Inti (`CampaignManager`)

**Files:**
- Create: `godot/scripts/autoload/sss_controller.gd`
- Create: `godot/scripts/autoload/campaign_manager.gd`
- Create: `godot/tests/test_campaign_and_sss.gd`
- Modify: `project.godot` (daftarkan Autoload `SSSController` dan `CampaignManager`)

**Interfaces:**
- Consumes: `ContentDB`, `LocaleService`
- Produces:
  - `SSSController` (`Node`):
    - `const RANKS := [0, 5, 10, 20]`
    - `var levels: Dictionary` (`card_id -> int`)
    - `var hide_forecast: bool` (default `true`)
    - `func is_unlocked() -> bool`
    - `func is_card_unlocked(card_id: String, lvl_map: Dictionary = levels) -> bool`
    - `func set_card_rank(card_id: String, rank: int) -> void` (menegakkan prasyarat DAG secara rekursif)
    - `func apply_preset(rank: int) -> void`
    - `func lerp_card(level: float, n: float, h: float, m: float) -> float`
    - `func build_difficulty_data(lvl_map: Dictionary = levels) -> DifficultyData`
  - `CampaignManager` (`Node`):
    - `signal state_changed()`
    - `signal press_alert_queued(payload: Dictionary)` (memuat `kind`: `"press"` atau `"telex"`, `outlet`, `category`, `date_str`, `headline`, `body`, `net_deltas: Dictionary`)
    - `var current_turn: int`, `var is_action_phase: bool`, `var selected_difficulty: String`, `var show_option_effects: bool`
    - `var turn_executive_used: bool`, `var turn_faction_used: Dictionary`, `var event_resolved_this_turn: bool`
    - `var stats: Dictionary`, `var pc: int`, `var global_malus: int`, `var factions: Dictionary`, `var active_faction_order: PackedStringArray`
    - `var active_decrees: Dictionary`, `var banned_factions: Dictionary`, `var total_seats_vacated: int`, `var gazette_history: Array[Dictionary]`
    - `var min_stats: Dictionary`, `var max_cendana: int`, `var min_factions: Dictionary`
    - `func start_new_campaign(difficulty_id: String, forecast_enabled: bool) -> void`
    - `func get_gov_stability() -> int` & `func get_gov_stability_tier_id() -> String`
    - `func golkar_pillar_stands(pillar_id: String) -> bool` (`"a"`, `"b"`, `"g"`)
    - `func choose_event_option(option_idx: int) -> Dictionary`
    - `func can_execute_routine(id: String) -> Dictionary` & `func execute_routine(id: String) -> Dictionary`
    - `func can_enact_decree(id: String) -> Dictionary` & `func enact_decree(id: String) -> Dictionary`
    - `func can_engage_faction(faction_id: String, deal_id: String) -> Dictionary` & `func engage_faction(faction_id: String, deal_id: String) -> Dictionary`
    - `func can_final_appeal(faction_id: String) -> Dictionary` & `func execute_final_appeal(faction_id: String) -> Dictionary`
    - `func execute_horse_trade(faction_id: String, overtures: int) -> Dictionary`
    - `func finish_action_phase() -> void`
    - `func serialize_state() -> Dictionary` & `func restore_state(data: Dictionary) -> void`

- [ ] **Step 1: Tulis pengujian gagal `godot/tests/test_campaign_and_sss.gd`**

Cakup seluruh rumus inti serta **Perbaikan Issue #4** dan **Review Focus #2 (realokasi berantai)**:
```gdscript
# 1. Perbaikan Issue #4 pada SSS: uncheck hide_forecast mengaktifkan show_option_effects
CampaignManager.start_new_campaign("historical", true)
assert_eq(CampaignManager.show_option_effects, false)
SSSController.hide_forecast = false
CampaignManager.start_new_campaign("ucn", false)
assert_eq(CampaignManager.show_option_effects, true)

# 2. Hardcoded mil=50 awal, Stat Gravity (>78 -> -2/turn), & Tiga Pilar Golkar (B = -20% PC, G = +1 Cendana)
CampaignManager.start_new_campaign("medium", true)
assert_eq(CampaignManager.stats["mil"], 50)
assert_eq(int(round(CampaignManager.factions["abri"]["affinity"])), 50)
CampaignManager.stats["pop"] = 85
CampaignManager.finish_action_phase()
assert_eq(CampaignManager.stats["pop"], 83) # Stat gravity -2

# 3. Peleburan Poros Tengah pada awal Turn 18 = tepat 163 kursi & total 700 kursi terjaga
CampaignManager.current_turn = 17
CampaignManager.finish_action_phase() # maju ke Turn 18 -> memicu merger
assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 163)
assert_eq(CampaignManager.factions["ppp"]["seats"], 0)
assert_eq(CampaignManager.factions["pkb"]["seats"], 0)
assert_eq(CampaignManager.factions["other_parties"]["seats"], 26)

# 4. Review Focus #2: purge_utusan_golongan diikuti ban_pdip_subversion tidak membuang kursi ke fraksi terlarang
CampaignManager.start_new_campaign("easy", true)
CampaignManager.stats["ref"] = 20
CampaignManager.stats["mil"] = 85
CampaignManager.factions["abri"]["affinity"] = 85
CampaignManager.pc = 100
CampaignManager.enact_decree("purge_utusan_golongan")
CampaignManager.turn_executive_used = false; CampaignManager.pc = 100
CampaignManager.enact_decree("invoke_supersemar_ii")
CampaignManager.turn_executive_used = false; CampaignManager.pc = 100
CampaignManager.enact_decree("ban_pdip_subversion")
assert_eq(CampaignManager.factions["utusan_golongan"]["seats"], 0)
var active_sum := 0
for k in CampaignManager.factions:
    if not CampaignManager.banned_factions.get(k, false):
        active_sum += int(CampaignManager.factions[k]["seats"])
assert_eq(active_sum + CampaignManager.total_seats_vacated, 700)
```

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL`.

- [ ] **Step 3: Implementasikan `SSSController` dan `CampaignManager` dengan paritas penuh rumus `game.js` & `sss.js`**

Pastikan:
- Deduplikasi perubahan `mil` dan `abri` dalam satu objek efek (ambil satu yang bermagnitudo terbesar, lalu sinkronkan `stats["mil"] = int(round(factions["abri"]["affinity"]))`).
- Pada `start_new_campaign("ucn", _)`, tetapkan `show_option_effects = not SSSController.hide_forecast` (menambal *GitHub Issue #4*).
- Rekam `net_deltas` bersih (selisih statistik & afinitas sebelum vs sesudah `apply_effects`) ke dalam payload `press_alert_queued` agar UI dapat menampilkannya saat `show_exact_numbers == true`.
- Realokasi kursi berantai membagi bulat kursi terlarang ke penerima yang belum dibubarkan menggunakan metode sisa terbesar (*largest remainder*) sehingga jumlah kursi aktif + `total_seats_vacated` **selalu tepat `700`**.

- [ ] **Step 4: Jalankan runner uji untuk memastikan lulus**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/ project.godot
git commit -m "feat(engine): implement SSSController and CampaignManager turn/decree/pillar mechanics"
```

---

### Task 4: AI Oposisi (`OppositionManager`), Mesin Sidang Umum MPR (`ElectionManager`), & `AchievementService`

**Files:**
- Create: `godot/scripts/autoload/opposition_manager.gd`
- Create: `godot/scripts/autoload/election_manager.gd`
- Create: `godot/scripts/autoload/achievement_service.gd`
- Create: `godot/tests/test_opposition_election_achievements.gd`
- Modify: `godot/scripts/autoload/campaign_manager.gd` (hubungkan kait `OppositionManager` & `AchievementService`)
- Modify: `project.godot` (daftarkan Autoload `OppositionManager`, `ElectionManager`, `AchievementService`)

**Interfaces:**
- Consumes: `ContentDB`, `CampaignManager`, `SSSController`
- Produces:
  - `OppositionManager` (`Node`):
    - `func reset_for_campaign() -> void`
    - `func get_military_resistance() -> float`, `func get_military_gain_mult() -> float`, `func is_military_broken() -> bool`, `func get_military_meter() -> Dictionary` (`{live, phase, value, hostility}`)
    - `func get_pdip_cut() -> float`, `func get_pdip_gain_mult() -> float`, `func get_pdip_cost_mult() -> float`, `func get_pdip_tier() -> int`, `func is_pdip_locked() -> bool`, `func get_pdip_meter() -> Dictionary`
    - `func on_military_delta(delta: float) -> void`, `func apply_military_shock(points: float) -> void`, `func on_military_interaction() -> void`
    - `func on_pdip_delta(delta: float) -> void`, `func on_pdip_interaction() -> void`
    - `func snapshot_seats() -> Dictionary`, `func record_seat_transfer(before: Dictionary) -> void`
    - `func on_decree_enacted(decree: DecreeData) -> void`, `func on_end_of_turn() -> void`
    - `func affinity_adjust(faction_id: String) -> int`
    - `func election_seat_adjust(faction_id: String, final_aff: float, votes_for: int, votes_against: int, blank_votes: int) -> Dictionary`
    - `func original_chamber_size() -> int` & `func meets_quorum(votes_for: int) -> bool`
    - `func serialize_state() -> Dictionary` & `func restore_state(data: Dictionary) -> void`
  - `ElectionManager` (`Node`):
    - `func compute_election_roll_call(rng: RandomNumberGenerator = null) -> Dictionary` (mengembalikan `{accepted: bool, quorum_failed: bool, total_for: int, total_against: int, total_blank: int, chamber_seats: int, original_chamber_seats: int, factions: Array[Dictionary]}`)
  - `AchievementService` (`Node`):
    - `signal achievement_unlocked(ach_id: String)`
    - `var unlocked_ids: PackedStringArray`, `var difficulty_wins: PackedStringArray`
    - `func is_unlocked(ach_id: String) -> bool`, `func unlock(ach_id: String) -> void`
    - `func evaluate_mid_campaign() -> void`, `func evaluate_election_end(summary: Dictionary) -> void`

- [ ] **Step 1: Tulis pengujian gagal `godot/tests/test_opposition_election_achievements.gd`**

Uji mesin TNI, PDI-P Tier 4, pencapaian di mode `SSS`, serta **Review Focus #2 (kuorum 351 saat 30 kursi dikosongkan)**:
```gdscript
# 1. TNI shock memecah patience -> anger dan memotong perolehan global hingga 50% di Historical
CampaignManager.start_new_campaign("historical", false)
OppositionManager.apply_military_shock(60.0) # 50 - 60 = -10 -> anger = 7.5
assert_eq(OppositionManager.get_military_meter()["phase"], "anger")
OppositionManager.apply_military_shock(130.0) # dorong ke 100% anger
assert_near(OppositionManager.get_military_resistance(), 0.50, 0.01)

# 2. PDI-P 100% mengunci biaya 9.0x di Historical & memaksa 0 FOR / 153 AGAINST
OppositionManager.restore_state({"pdip": {"value": 100.0, "touched": false}})
assert_true(OppositionManager.is_pdip_locked())
assert_near(OppositionManager.get_pdip_cost_mult(), 9.0, 0.01)
var adj := OppositionManager.election_seat_adjust("pdip", 95.0, 140, 13, 0)
assert_eq(adj["votes_for"], 0)
assert_eq(adj["votes_against"], 153)

# 3. Review Focus #2: 30 kursi Golkar dikosongkan (670 aktif); 345 FOR vs 325 AGAINST tetap DITOLAK (< 351)
CampaignManager.total_seats_vacated = 30
CampaignManager.factions["golkar_akbar"]["seats"] = 0
CampaignManager.banned_factions["golkar_akbar"] = true
CampaignManager.factions["golkar_habibie"]["seats"] = 90
assert_eq(OppositionManager.original_chamber_size(), 700)
assert_eq(OppositionManager.meets_quorum(345), false)
assert_eq(OppositionManager.meets_quorum(351), true)

# 4. Perbaikan bug hulu: mode 'ucn' (SSS) tetap memicu achievement ambang statistik (pop_max)
AchievementService.unlocked_ids.clear()
CampaignManager.start_new_campaign("ucn", false)
CampaignManager.stats["pop"] = 92
AchievementService.evaluate_mid_campaign()
assert_true(AchievementService.is_unlocked("pop_max"))
```

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL`.

- [ ] **Step 3: Implementasikan `OppositionManager`, `ElectionManager`, dan `AchievementService`**

Replikasi presisi rumus `tni.js`, `pdip.js`, `opposition.js` (`getBetrayalPressure` + `getDefectionRate` + `tainted` walkout), ke-7 tahap `election.js:207-298` (dengan parameter opsional `RandomNumberGenerator` ber-seed untuk pengujian deterministik), serta ke-59 syarat *achievement* (dengan `is_challenge_difficulty` mencakup `["medium", "high", "historical", "ucn"]`).

- [ ] **Step 4: Jalankan runner uji untuk memastikan lulus**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/ project.godot
git commit -m "feat(simulation): add OppositionManager, 700-seat ElectionManager, and 59-item AchievementService"
```

---

### Task 5: Penyimpanan Multi-Slot (`SaveAndSettingsService`) & Audio Dua Bus (`AudioController`)

**Files:**
- Create: `godot/scripts/autoload/save_and_settings_service.gd`
- Create: `godot/scripts/autoload/audio_controller.gd`
- Create: `godot/tests/test_save_and_audio.gd`
- Modify: `project.godot` (daftarkan Autoload `SaveAndSettingsService` dan `AudioController`)

**Interfaces:**
- Consumes: `ContentDB`, `LocaleService`, `CampaignManager`, `OppositionManager`, `SSSController`, `AchievementService`
- Produces:
  - `SaveAndSettingsService` (`Node`):
    - `const SLOT_IDS := ["autosave", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5"]`
    - `var settings: UserSettingsData` (`locale`, `theme_id`, `text_scale`, `show_exact_numbers`, `music_enabled`, `music_volume`, `sfx_enabled`, `sfx_volume`, `active_genre`, `weighted_shuffle`, `auto_advance_turn`, `default_tally_speed`, `reduce_motion`)
    - `func save_settings() -> void` & `func load_settings() -> void`
    - `func save_campaign_slot(slot_id: String, note: String = "") -> bool`
    - `func load_campaign_slot(slot_id: String) -> bool`
    - `func delete_campaign_slot(slot_id: String) -> void`
    - `func list_slots_metadata() -> Array[Dictionary]`
    - `func export_backup_json(target_path: String) -> bool` & `func import_backup_json(source_path: String) -> bool`
  - `AudioController` (`Node`):
    - `signal track_changed(track: MusicTrackData)`
    - `var current_track_index: int`, `var is_playing: bool`
    - `func play_track(index: int) -> bool` (jika berkas gagal dibuka/rusak, otomatis melompat hingga menemukan lagu valid tanpa membeku)
    - `func next_track() -> void`, `func prev_track() -> void`, `func toggle_play_pause() -> void`
    - `func set_genre(genre: String) -> void`, `func set_weighted_shuffle(enabled: bool) -> void`
    - `func set_music_volume(linear: float) -> void`, `func set_sfx_volume(linear: float) -> void`
    - `func play_sfx(sfx_id: String) -> void` (`"click"`, `"blocked"`, `"notification"`, `"news"`, `"achievement"` pada bus `"SFX"`)

- [ ] **Step 1: Tulis pengujian gagal `godot/tests/test_save_and_audio.gd`**

Uji **Review Focus #3 (muat ulang slot pra-Poros Tengah dari giliran pasca-Poros Tengah)** dan **Review Focus #4 (lagu rusak, genre `international` + `weighted_shuffle`, dan bus SFX terpisah)**:
```gdscript
# 1. Review Focus #3: Simpan slot_1 di Turn 10 (10 fraksi, Poros Tengah 34 kursi), maju ke Turn 19 (163 kursi + anger), lalu muat slot_1
CampaignManager.start_new_campaign("high", true)
CampaignManager.current_turn = 10
CampaignManager.pc = 77
assert_true(SaveAndSettingsService.save_campaign_slot("slot_1", "Sebelum Baligate"))
CampaignManager.current_turn = 17
CampaignManager.finish_action_phase() # Turn 18 merger -> Poros Tengah 163, PPP 0
OppositionManager.apply_military_shock(80.0)
assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 163)

assert_true(SaveAndSettingsService.load_campaign_slot("slot_1"))
assert_eq(CampaignManager.current_turn, 10)
assert_eq(CampaignManager.pc, 77)
assert_eq(CampaignManager.factions["poros_tengah"]["seats"], 34)
assert_eq(CampaignManager.factions["ppp"]["seats"], 58)
assert_eq(OppositionManager.get_military_meter()["phase"], "patience")
# Pastikan pencapaian tetap bisa dibuka sesudah load manual
CampaignManager.stats["cendana"] = 0
AchievementService.evaluate_mid_campaign()
assert_true(AchievementService.is_unlocked("cendana_zero"))

# 2. Review Focus #4: Music volume 0% tidak membisukan SFX, weighted_shuffle + international tidak macet, stream gagal auto-skip
AudioController.set_music_volume(0.0)
AudioController.set_sfx_volume(0.8)
assert_true(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")) > -20.0)
AudioController.set_genre("international")
AudioController.set_weighted_shuffle(true)
AudioController.next_track()
assert_eq(ContentDB.catalog.music_tracks[AudioController.current_track_index].genre, "international")
var orig_path := ContentDB.catalog.music_tracks[0].file_path
ContentDB.catalog.music_tracks[0].file_path = "res://audio/music/nonexistent_corrupt_track.mp3"
AudioController.set_genre("all")
assert_true(AudioController.play_track(0))
assert_true(AudioController.current_track_index != 0)
ContentDB.catalog.music_tracks[0].file_path = orig_path
```

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL`.

- [ ] **Step 3: Implementasikan `SaveAndSettingsService` dan `AudioController`**

Pastikan:
- `CampaignManager` otomatis memanggil `SaveAndSettingsService.save_campaign_slot("autosave")` seusai setiap pilihan krisis, aksi rutin, dekrit, lobi fraksi, *horse-trading*, dan tepat sebelum `ElectionManager` dimulai.
- Pada `AudioController`, pilih kandidat dari irisan antara `active_genre` dan kuadran `weighted_tags` (`stab >= 50` x `ref >= 50`); apabila irisan kosong (seperti lagu `international`), jatuh kembali secara aman ke daftar lagu `active_genre` sehingga tidak pernah mengalami loop kosong atau pembagian nol.

- [ ] **Step 4: Jalankan runner uji untuk memastikan lulus**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/ project.godot
git commit -m "feat(services): add multi-slot SaveAndSettingsService and dual-bus error-resilient AudioController"
```

---

### Task 6: Sistem Tema Minimalis Modern, Shell *Safe Area* & *Bottom Sheet*, Layar Judul, Kesulitan, & Papan `SSS`

**Files:**
- Create: `godot/scripts/autoload/theme_manager.gd`
- Create: `godot/scripts/ui/safe_area_shell.gd`
- Create: `godot/scripts/ui/bottom_sheet_host.gd`
- Create: `godot/scripts/ui/widgets/stat_card_widget.gd`
- Create: `godot/scripts/ui/widgets/sss_graph_canvas.gd`
- Create: `godot/scripts/ui/screens/boot_loader_screen.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/title_screen.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/difficulty_screen.gd` (+ `.tscn`)
- Create: `godot/tests/test_ui_smoke_and_back_navigation.gd`
- Modify: `project.godot` (daftarkan Autoload `ThemeManager`)

**Interfaces:**
- Consumes: Seluruh Autoload dari Task 2–5
- Produces:
  - `ThemeManager` (`Node`):
    - `signal theme_updated()`
    - `func apply_theme(theme_id: String, text_scale: float) -> void` (`"midnight_slate"` `#0F1419` atau `"editorial_paper"` `#F6F4EF`; membangun `Theme` Godot terprogram dengan `StyleBoxFlat` sudut `14px`, tinggi minimum `Button` `48px`, dan menyinkronkan `LocaleService.active_palette_is_dark`)
    - `func color(role: String) -> Color` (`"bg"`, `"surface"`, `"surface_alt"`, `"border"`, `"text"`, `"muted"`, `"accent"`, `"good"`, `"bad"`, `"warn"`)
  - `BottomSheetHost` (`Control`):
    - `func push_sheet(content: Control, title: String = "") -> void`
    - `func pop_top_sheet() -> bool` (mengembalikan `true` bila ada lembar yang ditutup, `false` bila kosong)
    - `func get_open_count() -> int`
    - `func clear_all_sheets() -> void`
  - `StatCardWidget` (`PanelContainer`):
    - `func bind_stat(stat_key: String, value: int, delta_hint: int, min_floor: int, max_ceil: int, exact_mode: bool) -> void`
    - `func get_display_value_text() -> String`

- [ ] **Step 1: Tulis pengujian gagal `godot/tests/test_ui_smoke_and_back_navigation.gd` (Bagian 1)**

Uji pembuatan tema, sakelar kualitatif vs numerik `StatCardWidget`, kedua mode `SSS` (`Daftar 4 Jalur` & `Peta Node 2D`), serta **Review Focus #5 (gestur *Back* menutup `BottomSheet` teratas)**:
```gdscript
var host := BottomSheetHost.new()
var dummy_a := Control.new()
var dummy_b := Control.new()
host.push_sheet(dummy_a, "Sheet A")
host.push_sheet(dummy_b, "Sheet B")
assert_eq(host.get_open_count(), 2)
assert_true(host.pop_top_sheet())
assert_eq(host.get_open_count(), 1)
assert_true(host.pop_top_sheet())
assert_eq(host.pop_top_sheet(), false)

var card := StatCardWidget.new()
card.bind_stat("pop", 62, 1, 0, 100, false)
assert_true(not card.get_display_value_text().contains("62")) # kabut kualitatif terjaga
card.bind_stat("pop", 62, 1, 50, 100, true)
assert_true(card.get_display_value_text().contains("62")) # mode angka eksak aktif
```

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL`.

- [ ] **Step 3: Implementasikan `ThemeManager`, `SafeAreaShell`, `BottomSheetHost`, `StatCardWidget`, `SSSGraphCanvas`, `BootLoaderScreen`, `TitleScreen`, dan `DifficultyScreen`**

Pastikan:
- `SafeAreaShell` menangkap `NOTIFICATION_WM_GO_BACK_REQUEST` (`get_tree().set_quit_on_go_back(false)`) dan `ui_cancel`: pertama-tama memanggil `bottom_sheet_host.pop_top_sheet()`, lalu bila kosong kembali ke tab utama atau menampilkan konfirmasi keluar di bawah layar.
- `BootLoaderScreen` menampilkan salah satu dari 11 pesan *loading* bahasa aktif secara acak dan beralih mulus ke `TitleScreen`.
- `TitleScreen` menaruh seluruh tombol aksi (`Lanjutkan Autosave`, `Muat Slot`, `Kampanye Baru`, `Pustaka Sejarah`, `Pencapaian`, `Catatan Rilis / Changelog`, `Bahasa ID/EN`, `Tema`) di paruh bawah layar.
- `DifficultyScreen` menyertakan 4 tingkat kesulitan + papan 24 kartu `SSS` dengan pengalih bawah `[Daftar 4 Jalur]` / `[Peta Node 2D]` serta kotak centang *Sembunyikan Prakiraan Efek* yang sudah diperbaiki.

- [ ] **Step 4: Jalankan runner uji untuk memastikan lulus**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/ project.godot
git commit -m "feat(ui): build modern themes, one-handed BottomSheet shell, title, difficulty, and dual-mode SSS screens"
```

---

### Task 7: Layar Kampanye Utama *Portrait*, Kartu Reaksi Pers Editorial, & Seluruh 5 Tab Bawah

**Files:**
- Create: `godot/scripts/ui/widgets/hemicycle_canvas.gd`
- Create: `godot/scripts/ui/screens/campaign_shell_screen.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/agenda_tab_view.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/editorial_press_sheet.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/stat_dashboard_tab_view.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/mpr_parliament_tab_view.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/library_tab_view.gd` (+ `.tscn`)
- Create: `godot/scripts/ui/screens/more_drawer_tab_view.gd` (+ `.tscn`)
- Modify: `godot/tests/test_ui_smoke_and_back_navigation.gd` (tambahkan uji instansiasi & interaksi alur giliran penuh di UI)

**Interfaces:**
- Consumes: Seluruh Autoload + komponen Task 6
- Produces:
  - `CampaignShellScreen` (`Control`):
    - Zona atas: Header ringkas (`Tanggal • Giliran X/23`, `PC`, status `Stabilitas`, indikator `TNI` & `PDI-P` yang patuh pada `show_exact_numbers`).
    - Zona tengah & bawah: Pengalih 5 tab di dasar layar (`[Agenda]`, `[Stat]`, `[MPR]`, `[Buku]`, `[≡]`, masing-masing tinggi `56px`).
  - `EditorialPressSheet` (`Control`):
    - `func populate_alert(payload: Dictionary, show_exact_numbers: bool) -> void` (merender lencana 14 media editorial modern; hanya menampilkan chip delta numerik seperti `+8 Ekonomi` apabila `show_exact_numbers == true`).
  - `HemicycleCanvas` (`Control`):
    - `func set_seats_data(seat_colors: Array[Color], highlight_quorum: bool = false) -> void` (menggambar 700 kursi berbentuk busur 13 baris menggunakan `draw_circle` vektor tajam).

- [ ] **Step 1: Tambahkan pengujian alur UI kampanye pada `godot/tests/test_ui_smoke_and_back_navigation.gd`**

Uji bahwa `CampaignShellScreen` memuat ke-5 tab tanpa galat, memilih opsi krisis Giliran 1 memunculkan `EditorialPressSheet` di `BottomSheetHost` (menyembunyikan angka delta saat `show_exact_numbers == false` dan menampilkannya saat `true`), memilih 1 Aksi Rutin + 1 Lobi Fraksi lalu mengakhiri giliran memajukan layar ke Giliran 2, dan menekan potret Presiden di `LibraryTabView` mengganti teks biografi ke esai `Criticism`.

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL`.

- [ ] **Step 3: Implementasikan `CampaignShellScreen`, `EditorialPressSheet`, `HemicycleCanvas`, dan ke-5 Tab Bawah**

Pastikan ergonomi satu tangan:
- Pada `AgendaTabView` saat Fase Aksi, pengalih sub-mode (`[Rutin]`, `[Dekrit]`, `[Fraksi]`, `[Akhiri Giliran]`) serta pil filter kategori berada **tepat di atas bilah 5 tab bawah** (bukan di puncak layar!).
- Saat melihat detail `golkar_akbar` atau `golkar_habibie`, tampilkan widget interaktif **Tiga Pilar Golkar (`A`, `B`, `G`)** beserta status runtuh/berdiri dan dekrit pemutusnya.
- Pada Giliran 21–22 tampilkan tombol `Final Appeal (0 PC)` pencair *Favor*, dan pada Giliran 22 tampilkan tombol pembuka *Bottom Sheet* **`Horse-Trading Desk`** (`+1 Overture` / `+5 Overtures`).
- Pada `MoreDrawerTabView` (`[≡]`), sediakan: (a) Pemutar Musik Mini lengkap (sampul album, judul, Putar/Lanjut/Mundur, *seek*, dropdown 5 genre, sakelar *Weighted Shuffle*), (b) Manajer **Autosave + 5 Slot Simpan/Muat Manual** + tombol Ekspor/Impor Cadangan, (c) Galeri 59 *Achievements*, (d) Panduan *Tutorial* interaktif *portrait*, dan (e) Pengaturan (`Bahasa ID/EN`, Tema `Midnight Slate`/`Editorial Paper`, Skala Teks `85%–140%`, Sakelar *Tampilkan Angka Eksak*, *Otomatis Lanjut Giliran*, Volume Musik & SFX).

- [ ] **Step 4: Jalankan runner uji untuk memastikan lulus**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `PASS`.

- [ ] **Step 5: Commit**

```bash
git add godot/
git commit -m "feat(campaign-ui): implement one-handed portrait campaign shell, press sheet, and all 5 bottom tabs"
```

---

### Task 8: Malam Sidang Umum MPR, Ekspor PNG *State of the Republic*, Epilog, & Build `.apk` Android (`arm64-v8a`)

**Files:**
- Create: `godot/scripts/ui/screens/election_and_epilogue_screen.gd` (+ `.tscn`)
- Create: `export_presets.cfg`
- Create: `.github/workflows/build-android-apk.yml`
- Modify: `godot/scripts/ui/screens/agenda_tab_view.gd` (transisi Giliran 23 `ev_timtim_merdeka` langsung ke `ElectionAndEpilogueScreen`)
- Modify: `godot/tests/test_ui_smoke_and_back_navigation.gd` (tambahkan uji transisi Giliran 23 -> Sidang Umum MPR -> PNG *State of the Republic* -> Epilog)

**Interfaces:**
- Consumes: `ElectionManager`, `AchievementService`, `CampaignManager`, `OppositionManager`, `HemicycleCanvas`
- Produces:
  - `ElectionAndEpilogueScreen` (`Control`):
    - Animasi penghitungan 700 kursi (`19 Okt 1999 20:30` -> `20 Okt 1999 00:53`) dengan kontrol bawah `1x`, `2x`, `5x`, `10x`, dan `Lewati`.
    - Tampilan hasil putusan (`DITERIMA` / `DITOLAK`, termasuk pesan gagal kuorum `351` bila `for > against` tapi `< 351`), naskah resmi **TAP MPR No. III/MPR/1999**, tab *Dossier State of the Republic* + fungsi `export_dossier_png(output_path: String) -> Error` (merender kartu ringkasan via `SubViewport` lebar `1080px` tajam ke PNG di direktori dokumen pengguna / `user://exports/`), serta layar **Epilog** bergambar.
  - Berkas APK terkompilasi: `build/TwilightOfTheBanyanTree-Portrait-arm64.apk` + workflow GitHub Actions `.github/workflows/build-android-apk.yml`.

- [ ] **Step 1: Tambahkan pengujian akhir Sidang Umum MPR & ekspor gambar pada `godot/tests/test_ui_smoke_and_back_navigation.gd`**

Uji bahwa menyelesaikan pilihan pada Giliran 23 (`ev_timtim_merdeka`) membuka `ElectionAndEpilogueScreen`, memanggil tombol *Lewati* menuntaskan perhitungan 700 kursi + memicu `complete_run`, merender berkas gambar PNG *State of the Republic* berukuran valid (`> 10 KB`, lebar `1080px`) ke `user://test_dossier.png`, dan membuka layar Epilog.

- [ ] **Step 2: Jalankan runner uji untuk memverifikasi kegagalan**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd`
Expected: `FAIL`.

- [ ] **Step 3: Implementasikan `ElectionAndEpilogueScreen`, `export_presets.cfg`, dan `.github/workflows/build-android-apk.yml`**

- Siapkan `export_presets.cfg` untuk platform `Android` (`architectures/arm64-v8a=true`, `package/unique_name="id.banyantree.habibie1999"`, `package/name="Twilight of the Banyan Tree"`, `screen/immersive_mode=false` agar bilah status jam/baterai Android tetap terlihat rapi di atas `SafeAreaShell`, tanpa izin berbahaya).
- Pasang *Godot 4.7.2 Export Templates* + Android `commandlinetools` (`platform-tools`, `build-tools;34.0.0`, `platforms;android-34`) + `debug.keystore` pribadi di ruang pengguna lokal (`~/.local/share/godot/export_templates/4.7.2.stable/` & `~/android-sdk`), lalu jalankan ekspor headless untuk menghasilkan `build/TwilightOfTheBanyanTree-Portrait-arm64.apk` (atau apabila unduhan SDK Android dibatasi jaringan proxy sandbox, verifikasi *export pack* `.pck` penuh lokal + jalankan workflow `.github/workflows/build-android-apk.yml` di GitHub Actions `nafta121/Banyan-Tree` untuk menghasilkan artefak `.apk` terverifikasi).

- [ ] **Step 4: Jalankan seluruh suite pengujian headless & verifikasi berkas `.apk`**

Run: `~/.local/bin/godot --headless -s godot/tests/run_tests.gd && ls -lh build/TwilightOfTheBanyanTree-Portrait-arm64.apk`
Expected: Seluruh suite tes `PASS` (`exit code 0`) dan berkas `.apk` terverifikasi utuh (`apksigner verify` lulus).

- [ ] **Step 5: Commit cabang `godot4-android`**

```bash
git add godot/ export_presets.cfg .github/workflows/build-android-apk.yml
git commit -m "feat(election-apk): add MPR plenary screen, PNG dossier export, epilogue, and Android arm64 APK build"
```
