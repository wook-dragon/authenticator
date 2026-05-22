# Authenticator

macOS 메뉴바에서 Google Authenticator 호환 TOTP 코드를 띄우는 작은 앱.

핸드폰을 들었다 놨다 하지 않고, 메뉴바 클릭 한 번으로 2FA 코드를 클립보드에 복사한다.

## 왜 직접 빌드해서 쓰나

2FA secret은 매우 민감한 정보다. 누구도 모르는 사람의 binary로 이 앱을 신뢰할 수 없다.
그래서 이 저장소는 다음을 보장한다.

- **외부 의존성 0개.** 표준 라이브러리 + macOS 내장 프레임워크(CryptoKit, Vision, Security, SwiftUI)만 사용한다.
- **모든 OTP 관련 코드 직접 구현.** TOTP/HOTP, Base32, Google Authenticator 마이그레이션 protobuf — 어떤 외부 OTP 라이브러리도 없다.
- **네트워크 통신 없음.** secret은 어디로도 나가지 않는다.
- **secret 저장은 macOS Keychain.** `kSecAttrAccessibleWhenUnlocked`로 잠금 해제된 동안만 접근 가능.

`Sources/AuthenticatorCore/`를 직접 훑어보고 빌드한 binary만 신뢰하면 된다.

## 요구사항

- macOS 14 이상
- Xcode Command Line Tools — 없으면 `xcode-select --install`

## 설치 (빌드)

```sh
git clone <이 저장소>
cd authenticator
./scripts/build-app.sh release
open build/Authenticator.app
```

빌드 스크립트는 `swift build -c release` 후 ad-hoc 코드 서명까지 한다.

`build/Authenticator.app`을 `/Applications`로 옮기면 시스템 앱처럼 쓸 수 있다.
로그인 시 자동 실행하려면 시스템 설정 > 일반 > 로그인 항목에 추가한다.

## 사용 방법

1. 메뉴바 우상단 **열쇠 아이콘** 클릭
2. **QR 추가** 버튼
3. Google Authenticator 앱에서 우상단 메뉴 → "계정 내보내기" 화면을 핸드폰에서 스크린샷한 뒤, 그 이미지 파일을 맥북으로 전송(AirDrop 등)해서 드롭존에 끌어다 놓거나 클릭해서 선택. 한 번의 export QR로 여러 계정을 일괄 가져올 수 있다.
4. 등록되면 메뉴바 → 코드 클릭 → 클립보드 복사. 우클릭으로 이름 변경/삭제.

## 테스트

```sh
swift test
```

RFC 6238 부록 B의 표준 테스트 벡터(SHA1/SHA256/SHA512 × 6 시각) + RFC 4648 Base32 + 마이그레이션 URL 파싱 — 총 14개 테스트.

## 구조 (DDD / 헥사고날)

```
Sources/
├── AuthenticatorCore/         # 도메인 — OS 독립, 외부 의존성 없음
│   ├── OTPAccount.swift         # 도메인 모델
│   ├── Base32.swift             # RFC 4648
│   ├── TOTP.swift               # RFC 6238 (HMAC-SHA1/256/512)
│   ├── ProtobufReader.swift     # protobuf wire format 디코더
│   ├── MigrationParser.swift    # otpauth-migration / otpauth URL 파서
│   └── AccountStore.swift       # outbound port
├── AuthenticatorPlatform/     # 인프라 어댑터 (macOS)
│   ├── KeychainAccountStore.swift
│   └── QRImageDecoder.swift     # Vision
└── Authenticator/             # AppKit + SwiftUI 메뉴바 앱
    ├── main.swift               # NSApplication 부트스트랩
    ├── AppDelegate.swift        # NSStatusItem + NSPopover
    ├── AppState.swift
    ├── MenuBarContentView.swift
    └── AddAccountView.swift
```

## 알려진 동작

- **메뉴바 아이콘이 안 보일 때** — 메뉴바가 가득 차서 잘렸을 수 있다. 다른 메뉴바 앱을 ⌘+드래그로 정리하거나 화면 너비를 늘려본다.
- **계정을 잃어버렸을 때** — 이 앱의 데이터는 Keychain에만 있다. 백업은 핸드폰의 Google Authenticator 쪽에서 따로 유지하는 것을 권장한다.
