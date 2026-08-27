# Anonymous Chat - Native iOS Application (Swift / SwiftUI)
**Phiên bản**: `3.6.6 (Build 366)`  
**Nền tảng**: `iOS 15.0+` (Hỗ trợ iPhone, iPad, iOS 15, 16, 17, 18)

---

## 📱 Tính Năng Trên iOS

- **Giao diện Swift / SwiftUI 100%**: Mượt mà 120Hz ProMotion, Dark Theme cao cấp chuẩn phong cách iOS.
- **Thông Báo Kiểu Messenger (In-App & System Notifications)**:
  - Khi đang dùng app: Banner thả từ trên xuống (Dynamic Island style) kèm âm thanh rung haptic khi có tin nhắn từ **General**.
  - Khi chạy ngầm/khóa màn hình: Thông báo qua `UNUserNotificationCenter`.
- **Định Danh Thiết Bị (Multi-MAC Persistent Identifier)**:
  - Tự động tạo và lưu mã `MAC-XX:XX:XX:XX:XX:XX` chuẩn code gốc, kết nối qua `query.mac` và gửi kèm trong `auth-key` / `create-key`.
- **Explore Feed & Menu 3 Chấm**:
  - Xem bài viết, upvote / downvote, copy link chia sẻ, xóa bài viết và báo cáo.
- **Trình Xem Ảnh / Video / Nhạc Lightbox**:
  - Hỗ trợ phóng to thu nhỏ (Pinch-to-zoom), xoay ngang/dọc, nghe voice note audio.

---

## 🚀 Hướng Dẫn Build File `.ipa`

### Cách 1: Tự Động Build Bằng GitHub Actions (Khuyên Dùng - Không Cần Máy Mac)
1. Đẩy mã nguồn dự án lên kho chứa GitHub của bạn.
2. Vào tab **Actions** trên GitHub và chọn workflow **"Build iOS IPA"** -> Bấm **Run workflow**.
3. Sau khoảng 2-3 phút, tải file **`AnonymousChat-v3.6.6-iOS.ipa`** trực tiếp từ mục **Artifacts** về máy tính hoặc điện thoại.

### Cách 2: Build Trực Tiếp Trên Máy macOS Bằng Xcode
```bash
cd ios-app
brew install xcodegen
xcodegen generate
open AnonymousChat.xcodeproj
```
Chọn thiết bị hoặc **Any iOS Device (arm64)** -> **Product > Archive** -> **Distribute App** để xuất file `.ipa`.

---

## 📲 Hướng Dẫn Cài Đặt File `.ipa` Vào iPhone / iPad

Bạn có thể cài đặt file `.ipa` thông qua các công cụ sideload phổ biến nhất hiện nay:

1. **TrollStore** *(Khuyên dùng cho iOS 14.0 - 17.0)*:
   - Mở file `.ipa` trong TrollStore -> Bấm **Install** (Không bị thu hồi chứng chỉ 7 ngày, dùng vĩnh viễn).
2. **Sideloadly** *(Dùng trên máy tính Windows / Mac)*:
   - Cắm iPhone vào máy tính qua cáp USB.
   - Kéo thả file `AnonymousChat.ipa` vào phần mềm Sideloadly, nhập Apple ID và bấm **Start**.
3. **AltStore / Scarlet / ESign / GBox**:
   - Nhập file `.ipa` vào ứng dụng để ký chứng chỉ và cài đặt trực tiếp trên điện thoại.
