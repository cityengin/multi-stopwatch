import sys
import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

def create_deck(output_path):
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Color Palette: Clean Academic on Pure White Background
    COLOR_BG = RGBColor(255, 255, 255)
    COLOR_PRIMARY = RGBColor(20, 35, 60)      # Deep Navy Blue
    COLOR_ACCENT = RGBColor(26, 75, 140)      # Academic Blue
    COLOR_TEXT = RGBColor(30, 30, 30)         # Charcoal Dark (High Contrast)
    COLOR_MUTED = RGBColor(90, 95, 105)       # Dark Slate Gray
    COLOR_CARD_BG = RGBColor(248, 250, 252)   # Very Soft Slate
    COLOR_CARD_BORDER = RGBColor(208, 215, 222)
    COLOR_CODE_BG = RGBColor(246, 248, 250)   # Clean GitHub-style Code Box
    COLOR_CODE_TEXT = RGBColor(36, 41, 47)    # Dark Code Text
    COLOR_GREEN = RGBColor(34, 139, 34)
    COLOR_RED = RGBColor(178, 34, 34)

    FONT_FAMILY = "Times New Roman"
    FONT_CODE = "Consolas"

    def add_p(tf, text, size_pt, bold=False, italic=False, color=COLOR_TEXT, space_after=6, space_before=0, align=PP_ALIGN.LEFT, font_name=FONT_FAMILY):
        if len(tf.paragraphs) == 1 and tf.paragraphs[0].text == "":
            p = tf.paragraphs[0]
        else:
            p = tf.add_paragraph()
        p.text = text
        p.space_after = Pt(space_after)
        p.space_before = Pt(space_before)
        p.alignment = align
        for run in p.runs:
            run.font.name = font_name
            run.font.size = Pt(size_pt)
            run.font.bold = bold
            run.font.italic = italic
            run.font.color.rgb = color
        return p

    def add_slide_header(slide, title, category=None):
        # 1. Pure white background
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = COLOR_BG
        bg.line.fill.background()

        # 2. Header Box (No horizontal divider line)
        header_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.733), Inches(1.1))
        tf = header_box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0

        if category:
            add_p(tf, category.upper(), 13, bold=True, color=COLOR_ACCENT, space_after=4)
        add_p(tf, title, 26, bold=True, color=COLOR_PRIMARY, space_after=0)

    def add_code_box(slide, left, top, width, height, filename, code_lines, explanation_note):
        # Outer Code Box Container
        box = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        box.fill.solid()
        box.fill.fore_color.rgb = COLOR_CODE_BG
        box.line.color.rgb = COLOR_CARD_BORDER
        box.line.width = Pt(1.5)

        # Header bar for file name
        tb_fn = slide.shapes.add_textbox(left + Inches(0.2), top + Inches(0.12), width - Inches(0.4), Inches(0.35))
        tf_fn = tb_fn.text_frame
        tf_fn.word_wrap = True
        tf_fn.margin_left = tf_fn.margin_top = tf_fn.margin_right = tf_fn.margin_bottom = 0
        add_p(tf_fn, f"📄 {filename}", 12, bold=True, color=COLOR_ACCENT, font_name=FONT_CODE)

        # Code content
        tb_code = slide.shapes.add_textbox(left + Inches(0.2), top + Inches(0.52), width - Inches(0.4), height - Inches(1.5))
        tf_c = tb_code.text_frame
        tf_c.word_wrap = True
        tf_c.margin_left = tf_c.margin_top = tf_c.margin_right = tf_c.margin_bottom = 0

        for line in code_lines:
            line_color = COLOR_CODE_TEXT
            if line.strip().startswith("//") or line.strip().startswith("///"):
                line_color = COLOR_MUTED
            elif any(line.strip().startswith(kw) for kw in ["class ", "abstract ", "factory ", "static ", "Future<", "Stream<"]):
                line_color = COLOR_PRIMARY
            add_p(tf_c, line, 11, bold=False, color=line_color, space_after=2, font_name=FONT_CODE)

        # Bottom Callout banner inside the box
        callout_y = top + height - Inches(0.85)
        co = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left + Inches(0.15), callout_y, width - Inches(0.3), Inches(0.72))
        co.fill.solid()
        co.fill.fore_color.rgb = RGBColor(238, 243, 250)
        co.line.color.rgb = COLOR_ACCENT
        co.line.width = Pt(1.0)
        tf_co = co.text_frame
        tf_co.word_wrap = True
        tf_co.margin_left = tf_co.margin_right = Inches(0.2)
        tf_co.margin_top = Inches(0.08)
        p = add_p(tf_co, "💡 Ý nghĩa đoạn code: ", 12, bold=True, color=COLOR_ACCENT, space_after=2)
        r2 = p.add_run()
        r2.text = explanation_note
        r2.font.name = FONT_FAMILY
        r2.font.size = Pt(12)
        r2.font.bold = False
        r2.font.color.rgb = COLOR_TEXT

    def set_notes(slide, notes):
        notes_slide = slide.notes_slide
        tf = notes_slide.notes_text_frame
        tf.text = notes

    # =========================================================================
    # SLIDE 1: TRANG TIÊU ĐỀ
    # =========================================================================
    slide1 = prs.slides.add_slide(blank_layout)
    bg1 = slide1.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
    bg1.fill.solid()
    bg1.fill.fore_color.rgb = COLOR_BG
    bg1.line.fill.background()

    # Top University Banner
    tb_inst = slide1.shapes.add_textbox(Inches(0.8), Inches(0.7), Inches(11.733), Inches(0.9))
    tf_inst = tb_inst.text_frame
    tf_inst.word_wrap = True
    add_p(tf_inst, "ĐẠI HỌC ĐÀ NẴNG  •  TRƯỜNG ĐẠI HỌC BÁCH KHOA  •  KHOA CÔNG NGHỆ THÔNG TIN", 13, bold=True, color=COLOR_ACCENT, space_after=3)
    add_p(tf_inst, "BÁO CÁO ĐỒ ÁN MÔN HỌC: LẬP TRÌNH ĐA NỀN TẢNG", 12, bold=False, italic=True, color=COLOR_MUTED)

    # Big Title & Subtitle
    tb_title = slide1.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(11.733), Inches(1.6))
    tf_title = tb_title.text_frame
    tf_title.word_wrap = True
    add_p(tf_title, "LẬP TRÌNH BẤT ĐỒNG BỘ VỚI FUTURE & STREAM", 30, bold=True, color=COLOR_PRIMARY, space_after=8)
    add_p(tf_title, "Xây dựng Module Reactive thời gian thực – Ứng dụng Multi-Stopwatch", 20, bold=False, italic=True, color=COLOR_ACCENT)

    # 2 Big Clean Member Cards
    card1 = slide1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(3.7), Inches(5.7), Inches(2.2))
    card1.fill.solid()
    card1.fill.fore_color.rgb = COLOR_CARD_BG
    card1.line.color.rgb = COLOR_CARD_BORDER
    card1.line.width = Pt(1.5)
    tf_c1 = card1.text_frame
    tf_c1.word_wrap = True
    tf_c1.margin_left = Inches(0.35)
    tf_c1.margin_top = Inches(0.25)
    add_p(tf_c1, "THÀNH VIÊN 1: UI & STATE MANAGEMENT (45%)", 15, bold=True, color=COLOR_ACCENT, space_after=8)
    add_p(tf_c1, "• Họ và tên:   [Họ và tên sinh viên 1]", 16, bold=False, color=COLOR_TEXT, space_after=4)
    add_p(tf_c1, "• Mã số SV:   [Mã số sinh viên 1]", 16, bold=False, color=COLOR_TEXT, space_after=4)
    add_p(tf_c1, "• Lớp SH:      [Lớp sinh viên 1]", 16, bold=False, color=COLOR_TEXT)

    card2 = slide1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.8), Inches(3.7), Inches(5.7), Inches(2.2))
    card2.fill.solid()
    card2.fill.fore_color.rgb = COLOR_CARD_BG
    card2.line.color.rgb = COLOR_CARD_BORDER
    card2.line.width = Pt(1.5)
    tf_c2 = card2.text_frame
    tf_c2.word_wrap = True
    tf_c2.margin_left = Inches(0.35)
    tf_c2.margin_top = Inches(0.25)
    add_p(tf_c2, "THÀNH VIÊN 2: BUSINESS LOGIC, API & SLIDE (55%)", 15, bold=True, color=COLOR_ACCENT, space_after=8)
    add_p(tf_c2, "• Họ và tên:   [Họ và tên sinh viên 2]", 16, bold=False, color=COLOR_TEXT, space_after=4)
    add_p(tf_c2, "• Mã số SV:   [Mã số sinh viên 2]", 16, bold=False, color=COLOR_TEXT, space_after=4)
    add_p(tf_c2, "• Lớp SH:      [Lớp sinh viên 2]", 16, bold=False, color=COLOR_TEXT)

    # Footer
    tb_foot = slide1.shapes.add_textbox(Inches(0.8), Inches(6.3), Inches(11.733), Inches(0.6))
    tf_foot = tb_foot.text_frame
    add_p(tf_foot, "Giảng viên hướng dẫn: [Họ và tên Thầy / Cô]    •    Đà Nẵng, Học kỳ 1 Năm học 2026 – 2027", 13, italic=True, color=COLOR_MUTED)

    set_notes(slide1, 
        "Kính chào Thầy/Cô và các bạn sinh viên. Hôm nay nhóm chúng em xin được báo cáo đề tài đồ án môn Lập trình Đa nền tảng: "
        "'Lập trình Bất đồng bộ với Future & Stream: Xây dựng Module Reactive thời gian thực' thông qua ứng dụng Multi-Stopwatch. "
        "Nhóm gồm 2 thành viên: Bạn [Tên 1] phụ trách toàn bộ giao diện và State Management, và em là [Tên 2] phụ trách kiến trúc "
        "Business Logic, API Core và thiết kế báo cáo. Sau đây em xin bắt đầu phần trình bày."
    )

    # =========================================================================
    # SLIDE 2: BẢNG PHÂN CÔNG CÔNG VIỆC & ĐÓNG GÓP (TINH GỌN THEO YÊU CẦU: BỎ CHI TIẾT)
    # =========================================================================
    slide2 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide2, "PHÂN CÔNG CÔNG VIỆC VÀ TỶ LỆ ĐÓNG GÓP", "TỔ CHỨC DỰ ÁN & LÀM VIỆC NHÓM")

    # Member 2 (Core, API, Slide - 55%) Box
    c_m2 = slide2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.8), Inches(5.7), Inches(3.6))
    c_m2.fill.solid()
    c_m2.fill.fore_color.rgb = COLOR_CARD_BG
    c_m2.line.color.rgb = COLOR_ACCENT
    c_m2.line.width = Pt(2.0)
    tf_m2 = c_m2.text_frame
    tf_m2.word_wrap = True
    tf_m2.margin_left = tf_m2.margin_right = Inches(0.4)
    tf_m2.margin_top = Inches(0.35)
    add_p(tf_m2, "[HỌ VÀ TÊN SINH VIÊN 2]", 22, bold=True, color=COLOR_PRIMARY, space_after=8)
    add_p(tf_m2, "Lớp: [Lớp sinh hoạt 2]   |   MSSV: [Mã số SV 2]", 15, bold=False, color=COLOR_MUTED, space_after=22)
    add_p(tf_m2, "ĐẢM NHIỆM CHÍNH:", 16, bold=True, color=COLOR_ACCENT, space_after=8)
    add_p(tf_m2, "Business Logic, Developer API & Slide Báo cáo", 18, bold=True, color=COLOR_PRIMARY, space_after=24)
    add_p(tf_m2, "TỶ LỆ ĐÓNG GÓP: 55%", 24, bold=True, color=COLOR_PRIMARY, align=PP_ALIGN.CENTER)

    # Member 1 (UI, State - 45%) Box
    c_m1 = slide2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.8), Inches(1.8), Inches(5.7), Inches(3.6))
    c_m1.fill.solid()
    c_m1.fill.fore_color.rgb = COLOR_CARD_BG
    c_m1.line.color.rgb = COLOR_ACCENT
    c_m1.line.width = Pt(2.0)
    tf_m1 = c_m1.text_frame
    tf_m1.word_wrap = True
    tf_m1.margin_left = tf_m1.margin_right = Inches(0.4)
    tf_m1.margin_top = Inches(0.35)
    add_p(tf_m1, "[HỌ VÀ TÊN SINH VIÊN 1]", 22, bold=True, color=COLOR_PRIMARY, space_after=8)
    add_p(tf_m1, "Lớp: [Lớp sinh hoạt 1]   |   MSSV: [Mã số SV 1]", 15, bold=False, color=COLOR_MUTED, space_after=22)
    add_p(tf_m1, "ĐẢM NHIỆM CHÍNH:", 16, bold=True, color=COLOR_ACCENT, space_after=8)
    add_p(tf_m1, "UI Components, State Management & Widget Tests", 18, bold=True, color=COLOR_PRIMARY, space_after=24)
    add_p(tf_m1, "TỶ LỆ ĐÓNG GÓP: 45%", 24, bold=True, color=COLOR_ACCENT, align=PP_ALIGN.CENTER)

    # Bottom Collaboration Principle Box
    c_box = slide2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(5.7), Inches(11.733), Inches(1.1))
    c_box.fill.solid()
    c_box.fill.fore_color.rgb = RGBColor(240, 245, 252)
    c_box.line.color.rgb = COLOR_ACCENT
    c_box.line.width = Pt(1.5)
    tf_cb = c_box.text_frame
    tf_cb.word_wrap = True
    tf_cb.margin_left = tf_cb.margin_right = Inches(0.4)
    tf_cb.margin_top = Inches(0.18)
    p = add_p(tf_cb, "Nguyên tắc cộng tác: ", 15, bold=True, color=COLOR_ACCENT, space_after=4)
    r = p.add_run()
    r.text = "Phân chia ranh giới module rõ ràng. Hai thành viên chỉ giao tiếp qua hợp đồng độc lập (StopwatchService), phát triển và kiểm thử song song, đảm bảo mã nguồn tuân thủ lint tuyệt đối và không có rò rỉ bộ nhớ."
    r.font.name = FONT_FAMILY
    r.font.size = Pt(15)
    r.font.color.rgb = COLOR_TEXT

    set_notes(slide2,
        "Về phân công công việc: Nhóm chia ranh giới module rất rạch ròi. Em đảm nhận 55% khối lượng bao gồm toàn bộ "
        "tầng Business Logic, nguồn nhịp, thuật toán mốc thời gian, xử lý stream cấp thấp, tầng lưu trữ, viết slide và tài liệu API. "
        "Bạn cùng nhóm đảm nhận 45% khối lượng bao gồm toàn bộ giao diện người dùng, quản lý State qua InheritedWidget, tối ưu hiệu năng "
        "dựng hình và kiểm thử widget. Nhờ có hợp đồng API tách bạch, hai bạn có thể lập trình song song mà không bị phụ thuộc lẫn nhau."
    )

    # =========================================================================
    # SLIDE 3: KIẾN TRÚC TỔNG THỂ & DÒNG DỮ LIỆU REACTIVE
    # =========================================================================
    slide3 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide3, "KIẾN TRÚC TỔNG THỂ VÀ REACTIVE DATA FLOW", "PHẦN 1: BUSINESS LOGIC & CORE ARCHITECTURE")

    tb_l = slide3.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts3 = [
        ("Tách biệt hoàn toàn Core và UI", 
         "Module lib/core/ viết bằng Dart thuần túy, không phụ thuộc bất kỳ API nào của Flutter SDK. Cho phép unit test nhanh chóng và độc lập."),
        ("Giao tiếp qua Interface StopwatchService", 
         "UI chỉ phụ thuộc vào bản hợp đồng interface trừu tượng. Mọi chi tiết cài đặt bên trong có thể thay đổi linh hoạt mà không phá vỡ giao diện."),
        ("Phân tách rõ ràng 2 luồng Stream",
         "• tasksStream: Chỉ phát khi danh sách/trạng thái đổi (thêm, xóa, pause, lap) -> Tránh rebuild UI liên tục.\n"
         "• elapsedStream(id): Phát số mili-giây riêng cho từng đồng hồ theo nhịp tick -> Chỉ ô giờ vẽ lại.")
    ]
    for h, b in pts3:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=18)

    code3 = [
        "abstract interface class StopwatchService {",
        "  /// Stream phát danh sách khi trạng thái đổi",
        "  Stream<List<TaskSnapshot>> get tasksStream;",
        "",
        "  /// Stream phát thời gian chạy cho từng đồng hồ",
        "  Stream<Duration> elapsedStream(String id);",
        "",
        "  Future<StopwatchTask> createTask({required String name, ...});",
        "  Future<void> start(String id);",
        "  Future<void> pause(String id);",
        "  Future<void> lap(String id);",
        "  Future<void> dispose();",
        "}"
    ]
    add_code_box(slide3, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/services/stopwatch_service.dart", code3,
                 "Giao diện chuẩn hóa che giấu toàn bộ logic phức tạp; tách 2 stream riêng biệt để UI đạt hiệu năng cao nhất.")

    set_notes(slide3,
        "Bước vào phần 1, đây là bức tranh kiến trúc tổng thể của hệ thống. Nhóm tách biệt hoàn toàn tầng Core và tầng UI. "
        "Toàn bộ logic bất đồng bộ nằm trong lib/core/, được viết bằng Dart thuần túy, hoàn toàn không dính líu đến widget hay context của Flutter. "
        "Điểm mấu chốt ở đây là việc phân tách rõ ràng 2 luồng Stream: 'tasksStream' chỉ phát khi trạng thái đồng hồ thay đổi, "
        "giúp danh sách không bị vẽ lại thừa thãi. Trong khi đó, 'elapsedStream' chỉ phát số thời gian chạy theo nhịp tick tới thẳng ô hiển thị Text."
    )

    # =========================================================================
    # SLIDE 4: BÀI TOÁN TRÔI GIỜ & THUẬT TOÁN TÍNH THEO MỐC
    # =========================================================================
    slide4 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide4, "BÀI TOÁN TRÔI GIỜ VÀ THUẬT TOÁN TÍNH THEO MỐC", "XỬ LÝ THỜI GIAN CHÍNH XÁC")

    tb_l = slide4.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts4 = [
        ("Hạn chế chết người của phép cộng dồn tick (+33ms)",
         "Timer trong Dart phụ thuộc Event Loop. Khi GC chạy, dựng frame nặng hoặc app xuống nền, nhịp tick bị trễ hoặc bỏ qua. Phép cộng dồn tích lũy sai số lên hàng phút sau vài giờ."),
        ("Giải pháp: Thuật toán tính theo mốc thời gian",
         "elapsed = accumulated + (now - runningSince)\n"
         "Trong đó accumulated là tổng thời gian các đoạn trước, runningSince là mốc bắt đầu đoạn hiện tại. Tick chỉ là tín hiệu đọc lại giờ."),
        ("Nguồn thời gian kép (Dual Time Sources)",
         "• Trong phiên chạy: Dùng đồng hồ đơn điệu Stopwatch (không bị giật khi user/NTP chỉnh giờ hệ thống).\n"
         "• Giờ hệ thống UTC: Lưu mốc để tự bù thời gian khi máy vào chế độ ngủ (Sleep mode) hoặc mở lại app.")
    ]
    for h, b in pts4:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY if not h.startswith("Hạn chế") else COLOR_RED, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=16)

    code4 = [
        "Duration elapsedAt(DateTime now) {",
        "  final since = runningSince;",
        "  if (since == null) return accumulated;",
        "",
        "  // Tính khoảng cách từ mốc bắt đầu đến hiện tại",
        "  final segment = now.difference(since);",
        "  return segment.isNegative ",
        "      ? accumulated ",
        "      : accumulated + segment;",
        "}"
    ]
    add_code_box(slide4, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/models/stopwatch_task.dart", code4,
                 "Tick chỉ là thời điểm 'đọc lại'. Giá trị luôn tính từ đồng hồ thực nên không bao giờ bị trôi dù Timer có bị trễ.")

    set_notes(slide4,
        "Một trong những câu hỏi học thuật quan trọng nhất của đề tài này là: 'Tại sao không dùng Timer cộng dồn +33ms mỗi tick?' "
        "Lý do là vì Timer trong Dart hoạt động trên Event Loop đơn luồng. Khi điện thoại bận xử lý đồ họa, dọn rác, hoặc app xuống nền, "
        "Dart sẽ bỏ qua các nhịp bị lỡ. Nếu cộng dồn tick, toàn bộ thời gian đó sẽ bị mất vĩnh viễn. "
        "Do đó, nhóm áp dụng công thức tính theo mốc thời gian: elapsed bằng accumulated cộng khoảng cách từ runningSince đến now. "
        "Tick chỉ đóng vai trò đánh thức giao diện đọc lại giờ, nên dù tick có trễ hay mất nhịp, thời gian đo được vẫn chính xác tuyệt đối."
    )

    # =========================================================================
    # SLIDE 5: NGUỒN NHỊP DÙNG CHUNG: LAZY TICKSOURCE
    # =========================================================================
    slide5 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide5, "NGUỒN NHỊP DÙNG CHUNG: LAZY TICKSOURCE", "TỐI ƯU HÓA TÀI NGUYÊN & BROADCAST STREAM")

    tb_l = slide5.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts5 = [
        ("Vấn đề khi mỗi đồng hồ tạo 1 Timer riêng",
         "10 đồng hồ chạy song song sẽ tạo ra 10 Timer định kỳ riêng biệt -> Lãng phí CPU, tốn pin và các nhịp cập nhật bị lệch pha nhau."),
        ("Duy nhất 1 Timer 33ms (~30fps) cho toàn app",
         "Toàn bộ ứng dụng dùng chung 1 nguồn nhịp phát qua StreamController.broadcast. Nhịp 33ms đủ mượt để mắt người nhìn thấy phần trăm giây."),
        ("Cơ chế chạy lười (Lazy Evaluation)",
         "Lợi dụng trực tiếp 2 callback onListen và onCancel của broadcast stream:\n"
         "• Có ít nhất 1 listener: Tự động khởi động Timer.periodic.\n"
         "• Hết listener (0 listener): Tự động cancel Timer ngay lập tức.\n"
         "• Tiết kiệm 100% CPU khi không có ai nhìn đồng hồ.")
    ]
    for h, b in pts5:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=18)

    code5 = [
        "late final _controller = StreamController<int>.broadcast(",
        "  onListen: _startTimer, // Bật Timer khi có listener",
        "  onCancel: _stopTimer,  // Tắt Timer khi hết listener",
        ");",
        "",
        "void _startTimer() {",
        "  _timer ??= Timer.periodic(interval, ",
        "      (timer) => _controller.add(timer.tick));",
        "}",
        "",
        "void _stopTimer() {",
        "  _timer?.cancel();",
        "  _timer = null;",
        "}"
    ]
    add_code_box(slide5, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/ticker/tick_source.dart", code5,
                 "Timer chỉ tồn tại khi thực sự có người lắng nghe; tự hủy ngay khi số listener về 0, giúp app không chạy ngầm hao pin.")

    set_notes(slide5,
        "Để tối ưu hóa tài nguyên, nhóm thiết kế lớp TickSource hoạt động theo cơ chế chạy lười (Lazy Evaluation). "
        "Thay vì mỗi đồng hồ tạo một Timer riêng làm tiêu tốn CPU và cập nhật lệch pha nhau, TickSource chỉ dùng duy nhất 1 Timer 33ms chung. "
        "Điểm thú vị là Timer này chỉ thực sự tồn tại khi có ít nhất một widget đang lắng nghe. "
        "Khi người dùng tạm dừng tất cả đồng hồ hoặc rời khỏi màn hình, callback 'onCancel' của broadcast stream sẽ lập tức hủy Timer. "
        "Nhờ đó ứng dụng không bao giờ bị chạy ngầm vô ích."
    )

    # =========================================================================
    # SLIDE 6: HANDCRAFTED STREAM TRANSFORMERS
    # =========================================================================
    slide6 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide6, "STREAM TRANSFORMERS THUẦN DART", "XỬ LÝ DÒNG DỮ LIỆU CẤP SÂU (THUẦN DART)")

    tb_l = slide6.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts6 = [
        ("Tự viết bằng Dart thuần túy",
         "Kế thừa trực tiếp StreamTransformerBase của Dart SDK, tuyệt đối không dùng thư viện rxdart bên ngoài."),
        ("ThrottleTransformer (kèm cờ trailing: true)",
         "• Phát ngay sự kiện đầu tiên, rồi 'đóng cửa sổ' trong duration.\n"
         "• Cờ trailing: Giữ lại sự kiện cuối cùng bị chặn để phát ngay khi đóng cửa sổ -> Không bao giờ bị mất frame cuối cùng khi bấm Pause hoặc Reset."),
        ("DebounceTransformer",
         "• Đặt lại thời gian chờ sau mỗi sự kiện, chỉ phát khi nguồn đã im lặng đủ duration.\n"
         "• Ứng dụng: Ô tìm kiếm tên đồng hồ (300ms) -> Chờ người dùng gõ xong mới lọc danh sách, không truy vấn theo từng phím."),
        ("Quản lý vòng đời trọn vẹn",
         "Pause/resume lan ngược về nguồn; khi stream done thì xả hết sự kiện pending rồi mới đóng controller an toàn.")
    ]
    for h, b in pts6:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code6 = [
        "void onData(T event, EventSink<T> sink) {",
        "  if (_window == null) {",
        "    sink.add(event);",
        "    _openWindow(sink);",
        "  } else if (_trailing) {",
        "    _hasTrailing = true;",
        "    _trailingEvent = event; // Lưu frame cuối",
        "  }",
        "}",
        "",
        "void _openWindow(EventSink<T> sink) {",
        "  _window = Timer(_duration, () {",
        "    _window = null;",
        "    if (_takeTrailing(sink)) _openWindow(sink);",
        "  });",
        "}"
    ]
    add_code_box(slide6, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/transformers/rate_limit.dart", code6,
                 "Cờ trailing bảo toàn frame thời gian cuối cùng khi bấm dừng; Debounce trì hoãn 300ms lọc mượt mà không lag.")

    set_notes(slide6,
        "Về xử lý luồng dữ liệu cấp sâu, nhóm không sử dụng bất kỳ thư viện bên thứ ba nào như rxdart mà tự triển khai "
        "các StreamTransformer thuần Dart kế thừa StreamTransformerBase. "
        "Chúng em viết hai bộ biến đổi chính: Throttle và Debounce. "
        "Trong ThrottleTransformer, nhóm thiết kế thêm cờ 'trailing: true'. Cờ này đảm bảo khi người dùng bấm Pause, "
        "sự kiện cuối cùng bị chặn trong cửa sổ throttle vẫn được phát ra, giúp màn hình không bao giờ bị lệch frame cuối. "
        "Còn DebounceTransformer được áp dụng cho ô tìm kiếm, trì hoãn 300ms sau phím bấm cuối để tránh việc lọc danh sách liên tục."
    )

    # =========================================================================
    # SLIDE 7: TẦNG LƯU TRỮ & KHẢ NĂNG CHỊU LỖI
    # =========================================================================
    slide7 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide7, "TẦNG LƯU TRỮ VÀ KHẢ NĂNG CHỊU LỖI", "REPOSITORY PATTERN & TRANSACTION ROLLBACK")

    tb_l = slide7.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts7 = [
        ("Thiết kế theo Repository Pattern",
         "Interface TaskRepository trừu tượng hóa toàn bộ thao tác nạp/lưu dữ liệu (loadAll, upsert, delete, replaceAll)."),
        ("Đa dạng môi trường lưu trữ",
         "• LocalTaskRepository: Lưu SharedPreferences với format JSON có versioning (version: 1). Tự bù thời gian khi mở lại app.\n"
         "• InMemoryTaskRepository: Giả lập độ trễ mạng và tỷ lệ lỗi ngẫu nhiên để phục vụ kiểm thử."),
        ("RetryingTaskRepository (Decorator Pattern)",
         "Tự động thử lại khi gặp StorageException với thời gian chờ tăng dần theo cấp số nhân (Exponential backoff: 200ms, 400ms...)."),
        ("Xếp hàng tuần tự & Tự động Rollback",
         "Mọi thao tác thay đổi trạng thái được tuần tự hóa tránh Race Condition. Nếu lưu ổ đĩa thất bại, trạng thái trong RAM lập tức được hoàn tác về trước đó.")
    ]
    for h, b in pts7:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code7 = [
        "// RetryingTaskRepository: Thử lại với delay tăng dần",
        "Future<T> _retry<T>(Future<T> Function() action) async {",
        "  for (var attempt = 1; ; attempt++) {",
        "    try {",
        "      return await action();",
        "    } on StorageException {",
        "      if (attempt >= maxAttempts) rethrow;",
        "      final delay = initialDelay * (1 << (attempt - 1));",
        "      await Future.delayed(delay);",
        "    }",
        "  }",
        "}",
        "// StopwatchManager: Tự động Rollback trạng thái nếu lỗi"
    ]
    add_code_box(slide7, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/storage/retrying_task_repository.dart", code7,
                 "Tự động thử lại khi gặp lỗi lưu trữ tạm thời; hoàn tác (rollback) trạng thái nếu thất bại, bảo vệ tính toàn vẹn dữ liệu.")

    set_notes(slide7,
        "Ở tầng lưu trữ, nhóm triển khai mẫu thiết kế Repository Pattern với LocalTaskRepository dùng SharedPreferences, "
        "lưu dữ liệu dưới cấu trúc JSON có định danh phiên bản. "
        "Ngoài ra, chúng em xây dựng thêm RetryingTaskRepository áp dụng Decorator Pattern, có khả năng tự động thử lại "
        "với khoảng chờ tăng dần khi xảy ra lỗi ghi đĩa hoặc mất kết nối API giả lập. "
        "Đặc biệt, StopwatchManager có cơ chế bảo vệ giao dịch: nếu lưu trữ thất bại hoàn toàn, hệ thống sẽ tự động hoàn tác "
        "trạng thái trong bộ nhớ về trước đó (Rollback) và thông báo lên UI, đảm bảo dữ liệu hiển thị không bao giờ bị sai lệch so với dữ liệu lưu trên đĩa."
    )

    # =========================================================================
    # SLIDE 8: ĐIỂM SÁNG: STREAMTRACKER & EVENT LOOP LAB
    # =========================================================================
    slide8 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide8, "STREAMTRACKER VÀ EVENT LOOP LAB", "MINH CHỨNG HỌC THUẬT & KIỂM CHỨNG KHÔNG RÒ RỈ")

    tb_l = slide8.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts8 = [
        ("StreamTracker – Minh chứng 0% rò rỉ bộ nhớ",
         "• Bọc các stream để đếm số lượng subscription đang hoạt động (activeCount) theo thời gian thực.\n"
         "• Ghi nhận chính xác 4 loại sự kiện: LISTEN, CANCEL, DONE, DISPOSE.\n"
         "• Minh chứng thực nghiệm: Khi đóng màn hình, activeCount luôn giảm chính xác về 0."),
        ("EventLabRunner – Khảo sát Event Loop thực tế",
         "• Ứng dụng kỹ thuật Dart Zone (Zone.current.fork) để chặn và theo dõi scheduleMicrotask và createTimer.\n"
         "• Đo đạc thứ tự thực thi thật của 6 kịch bản bất đồng bộ kinh điển:\n"
         "  1. scheduleMicrotask vs Timer\n"
         "  2. Các cách khởi tạo Future (sync, microtask, delayed)\n"
         "  3. Bản chất 0ms Timer của Future.delayed(zero)\n"
         "  4. Async gap & rủi ro thay đổi state khi đang chờ Future")
    ]
    for h, b in pts8:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code8 = [
        "final zone = Zone.current.fork(",
        "  specification: ZoneSpecification(",
        "    scheduleMicrotask: (self, parent, zone, callback) {",
        "      pending++;",
        "      parent.scheduleMicrotask(zone, ",
        "          () => runFrom(LabQueue.microtask, callback));",
        "    },",
        "    createTimer: (self, parent, zone, duration, callback) {",
        "      pending++;",
        "      return parent.createTimer(zone, duration, ",
        "          () => runFrom(LabQueue.event, callback));",
        "    },",
        "  ),",
        ");"
    ]
    add_code_box(slide8, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/lab/event_lab_runner.dart", code8,
                 "Bẫy Zone chặn microtask và timer để đo đạc chính xác thứ tự thực thi: Call Stack -> Microtask Queue -> Event Queue.")

    set_notes(slide8,
        "Để kết thúc phần Core, em xin trình bày 2 điểm sáng học thuật đặc biệt của dự án: "
        "Thứ nhất là StreamTracker: một cơ chế giám sát giúp đếm chính xác số lượng subscription đang mở và phát log vòng đời. "
        "Nhờ đó chúng em chứng minh được bằng thực nghiệm rằng ứng dụng không hề có rò rỉ bộ nhớ. "
        "Thứ hai là Event Loop Lab: thay vì giải thích lý thuyết suông, nhóm sử dụng kỹ thuật Dart Zone để bẫy và đo đạc thứ tự thực thi thật "
        "của 6 kịch bản bất đồng bộ, chứng minh nguyên lý Call Stack chạy trước, xả sạch Microtask Queue rồi mới tới Event Queue. "
        "Tiếp theo đây, em xin mời bạn [Tên 1] trình bày phần Giao diện và State Management."
    )

    # =========================================================================
    # SLIDE 9: QUẢN LÝ STATE VỚI STOPWATCHSCOPE
    # =========================================================================
    slide9 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide9, "QUẢN LÝ STATE VỚI STOPWATCHSCOPE", "PHẦN 2: UI & STATE MANAGEMENT")

    tb_l = slide9.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts9 = [
        ("Lựa chọn InheritedWidget chuẩn Flutter",
         "• Giữ ứng dụng tinh gọn, không phụ thuộc thư viện quản lý state bên ngoài (như Bloc, Provider hay GetX).\n"
         "• Bám sát chuẩn kiến trúc của Flutter SDK và trọng tâm môn học về luồng dữ liệu."),
        ("StopwatchScope – Phân phối Service tập trung",
         "Cung cấp StopwatchService và StreamTracker xuống toàn bộ cây widget qua context:\n"
         "• StopwatchScope.of(context): Lấy service điều khiển.\n"
         "• StopwatchScope.trackerOf(context): Lấy tracker giám sát."),
        ("Vòng đời quản lý tập trung tại Root Widget",
         "• Khởi tạo duy nhất trong initState() của MultiStopwatchApp.\n"
         "• Giải phóng toàn bộ trong dispose(): Đảm bảo manager và tracker được dispose sạch sẽ khi app đóng.")
    ]
    for h, b in pts9:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=18)

    code9 = [
        "class StopwatchScope extends InheritedWidget {",
        "  const StopwatchScope({",
        "    super.key,",
        "    required this.service,",
        "    this.tracker,",
        "    required super.child,",
        "  });",
        "",
        "  final StopwatchService service;",
        "  final StreamTracker? tracker;",
        "",
        "  static StopwatchService of(BuildContext context) =>",
        "      context.dependOnInheritedWidgetOfExactType<",
        "          StopwatchScope>()!.service;",
        "}"
    ]
    add_code_box(slide9, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/ui/scope/stopwatch_scope.dart", code9,
                 "Phân phối service và tracker xuống toàn bộ widget tree; hỗ trợ Dependency Injection sạch sẽ khi chạy Widget Test.")

    set_notes(slide9,
        "Xin chào Thầy/Cô, em là [Tên 1], em xin tiếp tục trình bày phần 2 về Giao diện và Quản lý State. "
        "Để quản lý trạng thái, nhóm quyết định sử dụng InheritedWidget có sẵn của Flutter thông qua lớp StopwatchScope tự viết. "
        "Việc không dùng thêm thư viện như Bloc hay Provider giúp ứng dụng cực kỳ tinh gọn, bám sát bản chất cây widget của Flutter. "
        "StopwatchScope được đặt ngay tại gốc MultiStopwatchApp, chịu trách nhiệm khởi tạo service khi mở app và tự động dispose "
        "toàn bộ Stream và Timer khi widget gốc bị unmount, ngăn ngừa hoàn toàn các tiến trình chạy ngầm rò rỉ."
    )

    # =========================================================================
    # SLIDE 10: TỐI ƯU RENDER: CÔ LẬP REBUILD VỚI ELAPSEDTEXT
    # =========================================================================
    slide10 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide10, "KỸ THUẬT TỐI ƯU RENDER: CÔ LẬP REBUILD", "HIỆU NĂNG GIAO DIỆN MƯỢT MÀ 60FPS")

    tb_l = slide10.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts10 = [
        ("Thách thức lớn khi nhiều đồng hồ cùng chạy",
         "10 đồng hồ chạy song song ở tần suất 30fps -> Có tới 300 sự kiện phát ra mỗi giây. Nếu đặt StreamBuilder ở thẻ cha TaskCard, cả màn hình sẽ bị vẽ lại 300 lần/giây, gây giật lag và hao pin."),
        ("Giải pháp kiến trúc với ElapsedText",
         "Tách riêng ô hiển thị chữ số thời gian thành component ElapsedText độc lập:\n"
         "• Chỉ duy nhất ô Text này lắng nghe elapsedStream và build lại.\n"
         "• Toàn bộ TaskCard cha, nút bấm, tên đồng hồ giữ nguyên không bị rebuild."),
        ("Quy tắc vòng đời Stream trong Widget",
         "Stream được lấy 1 lần duy nhất trong initState() hoặc didChangeDependencies(). Tuyệt đối không gọi service.elapsedStream() trong hàm build() để tránh rò rỉ."),
        ("Định dạng kiểu chữ Monospace",
         "Sử dụng font chữ monospace giúp các con số có cùng chiều rộng cố định, loại bỏ hiện tượng co giật chữ số khi nhảy giờ.")
    ]
    for h, b in pts10:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code10 = [
        "@override",
        "void didChangeDependencies() {",
        "  super.didChangeDependencies();",
        "  _elapsedStream ??= StopwatchScope.of(context)",
        "      .elapsedStream(widget.taskId);",
        "}",
        "",
        "@override",
        "Widget build(BuildContext context) {",
        "  return StreamBuilder<Duration>(",
        "    stream: _elapsedStream,",
        "    builder: (context, snapshot) => Text(",
        "      formatElapsed(snapshot.data ?? widget.initialElapsed),",
        "      style: const TextStyle(fontFamily: 'monospace'),",
        "    ),",
        "  );",
        "}"
    ]
    add_code_box(slide10, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/ui/widgets/elapsed_text.dart", code10,
                 "Cô lập phạm vi rebuild chỉ trong ô chữ số thời gian; toàn bộ Card cha và danh sách đứng yên, duy trì 60fps mượt mà.")

    set_notes(slide10,
        "Một bài toán kỹ thuật rất quan trọng ở phía UI là: Làm thế nào để ứng dụng vẫn mượt mà 60fps khi có hàng chục đồng hồ cùng chạy? "
        "Nếu đặt StreamBuilder ở thẻ TaskCard, thì mỗi giây toàn bộ thẻ đó sẽ bị build lại 30 lần, gây giật lag dữ dội. "
        "Nhóm giải quyết bài toán này bằng cách cô lập phạm vi rebuild: tách riêng ô hiển thị số giờ thành widget ElapsedText. "
        "Mỗi khi có tick mới, chỉ đúng duy nhất ô Text này được vẽ lại, toàn bộ cấu trúc card, các nút bấm và danh sách bên ngoài hoàn toàn đứng yên. "
        "Ngoài ra chúng em dùng font monospace để các chữ số không bị co giật khi nhảy số."
    )

    # =========================================================================
    # SLIDE 11: MÀN HÌNH CHÍNH: HOMESCREEN & BATCH OPERATIONS
    # =========================================================================
    slide11 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide11, "MÀN HÌNH CHÍNH VÀ THAO TÁC HÀNG LOẠT", "TRẢI NGHIỆM ĐA TÁC VỤ TIỆN LỢI")

    tb_l = slide11.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts11 = [
        ("Thanh công cụ Thao tác hàng loạt (Batch Toolbar)",
         "Cho phép điều khiển toàn bộ danh sách chỉ bằng một cú chạm:\n"
         "• Chạy tất cả (Start All): Bật các đồng hồ đang nghỉ/tạm dừng.\n"
         "• Tạm dừng tất cả (Pause All): Dừng đồng thời mọi đồng hồ đang chạy.\n"
         "• Reset tất cả & Xóa tất cả: Kèm dialog cảnh báo nêu rõ số lượng."),
        ("Trạng thái nút thông minh",
         "Nút tự động enable/disable theo dữ liệu (Ví dụ: Không có đồng hồ nào đang chạy thì nút 'Tạm dừng tất cả' tự động mờ đi)."),
        ("Tìm kiếm Debounced 300ms",
         "Tích hợp trực tiếp DebounceTransformer của tầng Core; thanh tìm kiếm lọc theo tên mượt mà, loại bỏ độ trễ và không giật lag."),
        ("Thiết kế thích ứng (Responsive Layout)",
         "Dùng LayoutBuilder: Màn hình hẹp hiển thị ListView cuộn mượt; màn hình rộng (Tablet/Desktop) tự chuyển sang GridView nhiều cột.")
    ]
    for h, b in pts11:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code11 = [
        "// 1. Tìm kiếm Debounce 300ms từ Stream nguồn:",
        "_searchSubscription = _searchController.stream",
        "    .debounced(const Duration(milliseconds: 300))",
        "    .listen((query) => setState(() => _searchQuery = query));",
        "",
        "// 2. Thao tác hàng loạt an toàn có xác nhận:",
        "Future<void> _handleBatchRun() async => await _service.runAll();",
        "",
        "Future<void> _handleBatchReset() async {",
        "  final ok = await _showConfirmDialog('Reset toàn bộ đồng hồ?');",
        "  if (ok == true) await _service.resetAll();",
        "}"
    ]
    add_code_box(slide11, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/ui/screens/home_screen.dart", code11,
                 "Thanh công cụ Batch Toolbar đồng bộ với service; tìm kiếm Debounce 300ms mượt mà, ngăn ngừa gọi lọc liên tục.")

    set_notes(slide11,
        "Tại màn hình chính HomeScreen, nhóm tập trung tối đa vào trải nghiệm đa tác vụ của người dùng. "
        "Chúng em thiết kế một thanh công cụ Batch Operations Toolbar cho phép Chạy tất cả, Tạm dừng tất cả, Reset hoặc Xóa hàng loạt "
        "chỉ với 1 thao tác. Các nút bấm này rất thông minh: chúng tự động bật hoặc tắt dựa trên dữ liệu hiện tại, ví dụ không có đồng hồ nào "
        "đang chạy thì nút Tạm dừng sẽ tự mờ đi. Khi Reset hoặc Xóa, hệ thống sẽ hiện hộp thoại xác nhận nêu rõ số lượng đồng hồ bị ảnh hưởng. "
        "Ngoài ra giao diện có tính năng Responsive, tự động chuyển từ dạng danh sách trên điện thoại sang dạng lưới GridView trên máy tính bảng."
    )

    # =========================================================================
    # SLIDE 12: MÀN HÌNH CHI TIẾT: TASKDETAILSCREEN & LAP DELTA
    # =========================================================================
    slide12 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide12, "MÀN HÌNH CHI TIẾT VÀ TÍNH NĂNG LAP DELTA", "THEO DÕI TỪNG VÒNG CHẠY CHÍNH XÁC")

    tb_l = slide12.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts12 = [
        ("Màn hình chuyên dụng cho từng đồng hồ",
         "Chuyển từ HomeScreen sang TaskDetailScreen khi bấm vào thẻ; hiển thị đồng hồ số kích thước lớn và vòng tròn trạng thái trực quan."),
        ("Ghi nhận Vòng chạy (Lap Recording)",
         "• Nút Bấm Lap hoạt động ngay cả khi đồng hồ đang chạy.\n"
         "• Mỗi Lap lưu trữ 4 trường: Thứ tự vòng, Thời gian vòng (Lap time), Tổng thời gian tích lũy (Total elapsed), và Chênh lệch (Delta)."),
        ("Trực quan hóa Chênh lệch (Lap Delta)",
         "Tự động so sánh thời gian vòng hiện tại với vòng ngay trước đó:\n"
         "• Màu Xanh lá (-00:01.20): Vòng này chạy NHANH HƠN vòng trước.\n"
         "• Màu Đỏ (+00:02.15): Vòng này chạy CHẬM HƠN vòng trước.\n"
         "• Giúp người dùng phân tích thành tích luyện tập trực quan."),
        ("Đối soát vòng đời khi thoát màn hình",
         "Khi rời TaskDetailScreen về HomeScreen, subscription nghe giờ bị hủy tức thì; activeCount giảm chính xác từ 2 về 0.")
    ]
    for h, b in pts12:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code12 = [
        "// Tính toán Lap Time và độ chênh lệch Delta:",
        "final previousLap = laps.isEmpty ? null : laps.last;",
        "final lapTime = previousLap == null",
        "    ? currentElapsed",
        "    : currentElapsed - previousLap.totalElapsed;",
        "final delta = previousLap == null ",
        "    ? null ",
        "    : lapTime - previousLap.lapTime;",
        "",
        "final lap = Lap(",
        "  lapNumber: laps.length + 1,",
        "  lapTime: lapTime,",
        "  totalElapsed: currentElapsed,",
        "  delta: delta, // Delta < 0: Nhanh hơn, Delta > 0: Chậm hơn",
        ");"
    ]
    add_code_box(slide12, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/services/stopwatch_manager.dart", code12,
                 "Thuật toán tính Lap Time và Delta chuẩn xác; UI tự động tô màu Xanh lá (nhanh hơn) hoặc Đỏ (chậm hơn) trực quan.")

    set_notes(slide12,
        "Khi bấm vào một đồng hồ, ứng dụng chuyển sang màn hình chi tiết TaskDetailScreen. "
        "Màn hình này hiển thị đồng hồ bấm giờ cỡ lớn và hỗ trợ tính năng ghi nhận Lap (vòng chạy). "
        "Điểm nổi bật là hệ thống tự động tính toán chênh lệch Delta so với vòng ngay trước đó: "
        "nếu vòng này chạy nhanh hơn, Delta hiển thị màu xanh lá; nếu chạy chậm hơn, Delta hiển thị màu đỏ. "
        "Và một chi tiết kỹ thuật đắt giá: khi người dùng thoát khỏi màn hình này quay về danh sách, subscription nghe giờ "
        "sẽ được hủy tức thì, số lượng active subscription trên StreamTracker giảm chính xác từ 2 về 0, không để lại bất kỳ rò rỉ nào."
    )

    # =========================================================================
    # SLIDE 13: MÀN HÌNH KIỂM CHỨNG: DEBUG SCREEN & EVENT LAB
    # =========================================================================
    slide13 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide13, "CÔNG CỤ TRỰC QUAN: DEBUG SCREEN & EVENT LAB", "GIAO DIỆN KIỂM CHỨNG TRỰC TIẾP")

    tb_l = slide13.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts13 = [
        ("DebugScreen – Giám sát Subscription trực tiếp",
         "• Hiển thị số lượng subscription đang hoạt động (activeCount) to rõ ở đầu màn hình.\n"
         "• Phân rã chi tiết từng nguồn luồng: tasksStream, elapsedStream:<id>.\n"
         "• Dòng thời gian trực quan hóa các sự kiện: LISTEN (Xanh), CANCEL (Cam), DONE (Tím), DISPOSE (Đỏ).\n"
         "• Bộ lọc sự kiện thông minh giúp giảng viên dễ dàng kiểm chứng việc hủy luồng."),
        ("EventLabScreen – Phòng thí nghiệm Event Loop",
         "• Cho phép chọn từng kịch bản hoặc bấm 'Run All' để chạy toàn bộ 6 kịch bản bất đồng bộ.\n"
         "• Đo thời gian thực tế tính bằng micro-giây (µs) và hiển thị thứ tự thực thi rõ ràng.\n"
         "• Gắn nhãn màu trực quan: SYNC (Ngọc), MICROTASK (Cam), EVENT (Tím).")
    ]
    for h, b in pts13:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=16)

    code13 = [
        "Stream<T> track<T>(String source, Stream<T> stream) {",
        "  return Stream<T>.multi((controller) {",
        "    _record(StreamLogKind.listen, source, delta: 1);",
        "    final sub = stream.listen(",
        "      controller.addSync,",
        "      onError: controller.addErrorSync,",
        "      onDone: () {",
        "        _record(StreamLogKind.done, source, delta: -1);",
        "        controller.closeSync();",
        "      },",
        "    );",
        "    controller.onCancel = () {",
        "      _record(StreamLogKind.cancel, source, delta: -1);",
        "      return sub.cancel();",
        "    };",
        "  });",
        "}"
    ]
    add_code_box(slide13, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "lib/core/debug/stream_tracker.dart", code13,
                 "Bọc stream tự động tăng giảm delta subscription và phát log sự kiện; DebugScreen hiển thị trực quan không góc khuất.")

    set_notes(slide13,
        "Để phục vụ buổi báo cáo và trả lời vấn đáp của Thầy/Cô, nhóm đã xây dựng hẳn hai màn hình công cụ tích hợp sẵn trong app: "
        "Màn hình thứ nhất là DebugScreen, cho phép quan sát trực tiếp số lượng subscription đang hoạt động theo thời gian thực. "
        "Thầy/Cô có thể thấy rõ khi mở một đồng hồ lên thì số subscription tăng, và khi thoát ra thì giảm về 0, chứng minh việc hủy luồng an toàn. "
        "Màn hình thứ hai là EventLabScreen, cho phép chạy thực nghiệm 6 kịch bản bất đồng bộ và trực quan hóa thứ tự chạy giữa Call Stack, "
        "Microtask Queue và Event Queue với các nhãn màu rõ ràng, giúp giải thích cặn kẽ mọi câu hỏi lý thuyết."
    )

    # =========================================================================
    # SLIDE 14: ĐÁNH GIÁ CHẤT LƯỢNG, TỔNG KẾT & Q&A
    # =========================================================================
    slide14 = prs.slides.add_slide(blank_layout)
    add_slide_header(slide14, "ĐÁNH GIÁ CHẤT LƯỢNG, TỔNG KẾT VÀ Q&A", "KẾT QUẢ DỰ ÁN")

    tb_l = slide14.shapes.add_textbox(Inches(0.8), Inches(1.8), Inches(5.5), Inches(5.1))
    tf_l = tb_l.text_frame
    tf_l.word_wrap = True

    pts14 = [
        ("Kiểm thử tự động toàn diện (Automated Testing)",
         "• 221 / 221 Tests Passed (Tỷ lệ đạt: 100%)\n"
         "• Bao phủ Unit Tests (Models, Ticker, Transformers, Storage, Lab, Debug).\n"
         "• Bao phủ Integration Tests (Chống trôi 100 giờ ảo, khôi phục app, rollback).\n"
         "• Bao phủ Widget Tests & Vòng đời subscription (subscription_lifecycle_test)."),
        ("Chất lượng mã nguồn tuyệt đối",
         "Lệnh flutter analyze kết thúc với: 'No issues found!'. Mã nguồn tuân thủ chặt chẽ toàn bộ quy chuẩn flutter_lints."),
        ("Kết luận & Bài học kinh nghiệm",
         "• Nắm vững kiến trúc bất đồng bộ chuyên sâu trong Dart & Flutter.\n"
         "• Xây dựng thành công module Reactive thời gian thực hiệu năng cao, cam kết 0% rò rỉ tài nguyên.")
    ]
    for h, b in pts14:
        add_p(tf_l, h, 18, bold=True, color=COLOR_PRIMARY, space_after=4)
        add_p(tf_l, b, 16, color=COLOR_TEXT, space_after=14)

    code14 = [
        "testWidgets('Pop TaskDetailScreen: subscription về 0',",
        "    (tester) async {",
        "  // 1. Mở màn hình chi tiết đồng hồ",
        "  await tester.pumpWidget(buildDetailScreen(taskId));",
        "  expect(tracker.activeCount, 2); // tasks + elapsed",
        "",
        "  // 2. Thoát (Pop) quay về HomeScreen",
        "  await tester.tap(find.byType(BackButton));",
        "  await tester.pumpAndSettle();",
        "",
        "  // 3. Minh chứng 100% không rò rỉ bộ nhớ",
        "  expect(tracker.activeCount, 0);",
        "});",
        "",
        "// Kết quả thực tế: All 221 tests passed! (100%)"
    ]
    add_code_box(slide14, Inches(6.5), Inches(1.8), Inches(6.0), Inches(5.1),
                 "test/ui/subscription_lifecycle_test.dart", code14,
                 "Bộ test tự động chứng minh subscription được dọn dẹp sạch sẽ; 221/221 test đều vượt qua thành công mỹ mãn.")

    set_notes(slide14,
        "Để kết luận, đồ án của nhóm đã hoàn thành toàn diện cả về mặt logic nghiệp vụ lẫn giao diện người dùng. "
        "Dự án đạt độ tin cậy tuyệt đối với 221 bài kiểm thử tự động vượt qua 100%, và mã nguồn không có bất kỳ cảnh báo lint nào. "
        "Quan trọng nhất, qua đồ án này hai bạn sinh viên đã thực sự làm chủ cơ chế lập trình bất đồng bộ với Future & Stream trong Dart, "
        "xây dựng thành công một module Reactive thời gian thực hiệu năng cao và vững chắc. "
        "Nhóm chúng em xin chân thành cảm ơn Thầy/Cô và các bạn đã chú ý lắng nghe. Nhóm sẵn sàng bước vào phần trả lời câu hỏi vấn đáp."
    )

    # FINAL INTEGRITY CHECK ACROSS ALL SLIDES:
    COLOR_WHITE = RGBColor(255, 255, 255)
    white_fixed_count = 0
    for slide_idx, slide in enumerate(prs.slides, 1):
        for shape in slide.shapes:
            if shape.has_text_frame:
                for paragraph in shape.text_frame.paragraphs:
                    for run in paragraph.runs:
                        if run.font.name != FONT_CODE:
                            run.font.name = FONT_FAMILY
                        try:
                            c = run.font.color.rgb
                        except Exception:
                            c = None
                        if c == COLOR_WHITE or c is None:
                            run.font.color.rgb = COLOR_TEXT
                            white_fixed_count += 1
            elif shape.has_table:
                for row in shape.table.rows:
                    for cell in row.cells:
                        for paragraph in cell.text_frame.paragraphs:
                            for run in paragraph.runs:
                                if run.font.name != FONT_CODE:
                                    run.font.name = FONT_FAMILY
                                try:
                                    c = run.font.color.rgb
                                except Exception:
                                    c = None
                                if c == COLOR_WHITE or c is None:
                                    run.font.color.rgb = COLOR_TEXT
                                    white_fixed_count += 1

    prs.save(output_path)
    print(f"Presentation saved successfully to: {output_path}. Fixed white text runs: {white_fixed_count}")

if __name__ == '__main__':
    out_file = sys.argv[1] if len(sys.argv) > 1 else "Bao_Cao_Multi_Stopwatch.pptx"
    create_deck(out_file)
