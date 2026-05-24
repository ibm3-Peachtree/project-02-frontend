# RUTTU 프론트엔드 인수인계 문서

> 작성일: 2026-05-24  
> 프로젝트: RUTTU — AI 기반 실시간 대중교통 경로 안내 앱  
> 플랫폼: Flutter (Android 우선)

---

## 목차

1. [개발 환경 설정](#1-개발-환경-설정)
2. [프로젝트 구조 설명](#2-프로젝트-구조-설명)
3. [화면별 파일 매핑](#3-화면별-파일-매핑)
4. [현재 구현 상태 (Mock vs 실제)](#4-현재-구현-상태-mock-vs-실제)
5. [자주 하는 작업 가이드](#5-자주-하는-작업-가이드)
6. [알아두면 좋은 것들](#6-알아두면-좋은-것들)

---

## 1. 개발 환경 설정

### 필요한 프로그램

| 프로그램 | 버전 | 다운로드 |
|----------|------|----------|
| Flutter SDK | 3.x 이상 | https://docs.flutter.dev/get-started/install |
| Android Studio | 최신 | https://developer.android.com/studio |
| VS Code (선택) | 최신 | https://code.visualstudio.com |

### Flutter 설치 확인

설치 후 터미널(PowerShell)에서 아래 명령어를 실행하여 이상이 없는지 확인하세요.

```powershell
flutter doctor
```

모든 항목에 체크(✓)가 되어 있어야 합니다. Android toolchain, Connected device 항목을 반드시 확인하세요.

### 프로젝트 열기

```powershell
# 프로젝트 폴더로 이동
cd c:\dev\project-02-frontend\ruttu_app

# 패키지 설치
flutter pub get
```

### 기기 연결 및 빌드

빌드 방법은 두 가지입니다. 상황에 맞게 선택하세요.

---

#### 방법 A — 기기에 직접 설치 (개발 중 수정 확인용)

**언제 사용하나요?**  
코드를 수정한 직후, 변경 사항이 실제 기기에서 잘 동작하는지 바로 확인할 때 사용합니다.  
PC에 기기를 연결한 상태에서만 사용할 수 있습니다.

**준비 사항:**  
Android 기기를 USB로 연결하고 **개발자 옵션 → USB 디버깅**을 활성화해야 합니다.

> **개발자 옵션 켜는 방법**: 설정 → 휴대폰 정보 → 소프트웨어 정보 → 빌드 번호를 7번 연속으로 탭하면 활성화됩니다.

```powershell
# 연결된 기기 목록 확인
flutter devices

# 기기에 빌드 후 바로 설치
flutter run -d [기기ID] --release

# 예시
flutter run -d R3CW60BK92K --release
```

설치가 완료되면 기기에서 앱이 자동으로 실행됩니다.

---

#### 방법 B — APK 파일로 추출 (다른 사람에게 전달하거나 보관할 때)

**언제 사용하나요?**  
- 기기를 PC에 연결하지 않고 앱을 설치하고 싶을 때
- 카카오톡, 이메일 등으로 앱 파일을 다른 사람에게 전달할 때
- 특정 시점의 앱을 파일로 보관해 두고 싶을 때

APK는 Android 앱 설치 파일입니다. 마치 Windows의 `.exe` 설치 파일처럼, 이 파일 하나만 있으면 기기에 앱을 설치할 수 있습니다.

```powershell
# APK 파일 생성
flutter build apk --release
```

빌드가 완료되면 아래 경로에 파일이 생성됩니다.

```
ruttu_app\build\app\outputs\flutter-apk\app-release.apk
```

**APK 파일 설치 방법:**
1. `app-release.apk` 파일을 기기로 전송 (카카오톡, USB, 구글 드라이브 등)
2. 기기에서 파일을 열면 설치 화면이 나타남
3. "출처를 알 수 없는 앱 설치"를 허용해야 설치 가능 (설정 → 보안에서 허용)

---

> **빌드 시간**: 최초 빌드는 2~3분 소요됩니다. 이후에는 1분 내외입니다.

---

## 2. 프로젝트 구조 설명

```
ruttu_app/
└── lib/
    ├── main.dart                  # 앱 진입점
    ├── core/                      # 앱 전체에서 공통으로 사용하는 요소
    │   ├── constants/
    │   │   ├── api_constants.dart         # API 서버 주소
    │   │   ├── app_constants.dart         # 앱 전반 상수
    │   │   └── route_constants.dart       # 화면 경로 이름 모음
    │   ├── theme/
    │   │   ├── app_colors.dart            # 앱 색상 정의
    │   │   └── app_theme.dart             # 앱 테마 (폰트 크기, 버튼 스타일 등)
    │   ├── utils/
    │   │   └── router.dart                # 화면 이동 경로 설정
    │   └── widgets/
    │       ├── kakao_postcode_page.dart   # 주소 검색 (카카오 우편번호)
    │       └── main_scaffold.dart         # 하단 탭바 포함된 기본 틀
    ├── data/                      # 데이터 관련 (모델, 저장소)
    │   ├── models/                        # 데이터 구조 정의
    │   │   ├── address_model.dart
    │   │   ├── post_model.dart
    │   │   ├── route_model.dart
    │   │   ├── routine_model.dart
    │   │   ├── user_model.dart
    │   │   └── weather_model.dart
    │   ├── repositories/                  # 실제 데이터를 가져오는 곳
    │   │   ├── auth_repository.dart       # 로그인/로그아웃
    │   │   ├── briefing_repository.dart   # 브리핑 데이터
    │   │   ├── community_repository.dart  # 커뮤니티 게시글
    │   │   ├── home_repository.dart       # 홈 (루틴, 날씨, 경로)
    │   │   └── routine_repository.dart    # 루틴 CRUD, 주소 관리
    │   └── services/
    │       └── token_storage.dart         # 로그인 토큰 저장
    └── features/                  # 화면별 기능 폴더
        ├── auth/                          # 로그인, 스플래시
        ├── briefing/                      # 브리핑
        ├── community/                     # 커뮤니티
        ├── home/                          # 홈 (실시간 경로)
        ├── mypage/                        # 마이페이지
        └── routine/                       # 루틴 관리
```

### features 폴더 구조 패턴

각 기능 폴더는 동일한 패턴을 따릅니다.

```
features/[기능명]/
├── providers/    # 상태 관리 (데이터를 화면에 연결)
└── screens/      # 실제 화면 UI
```

---

## 3. 화면별 파일 매핑

### 주요 화면

| 화면 이름 | 파일 경로 | 라우트 경로 |
|-----------|-----------|-------------|
| 스플래시 | `features/auth/screens/splash_screen.dart` | `/` |
| 닉네임 설정 | `features/auth/screens/nickname_setup_screen.dart` | `/nickname-setup` |
| **홈 (실시간 경로)** | `features/home/screens/home_screen.dart` | `/home` |
| **브리핑** | `features/briefing/screens/briefing_screen.dart` | `/briefing` |
| **루틴 목록** | `features/routine/screens/routine_list_screen.dart` | `/routine` |
| 루틴 상세 | `features/routine/screens/routine_detail_screen.dart` | `/routine/:id` |
| 루틴 추가/수정 | `features/routine/screens/routine_create_screen.dart` | `/routine/create` |
| **커뮤니티** | `features/community/screens/community_screen.dart` | `/community` |
| 게시글 상세 | `features/community/screens/post_detail_screen.dart` | `/community/:id` |
| 게시글 작성 | `features/community/screens/post_create_screen.dart` | `/community/create` |
| **마이페이지** | `features/mypage/screens/mypage_screen.dart` | `/mypage` |
| 계정 관리 | `features/mypage/screens/account_manage_screen.dart` | `/mypage/account` |
| 주소 관리 | `features/mypage/screens/address_manage_screen.dart` | `/mypage/address` |
| 리포트 | `features/mypage/screens/report_screen.dart` | `/mypage/report` |
| 알림 설정 | `features/mypage/screens/notification_settings_screen.dart` | `/mypage/notifications` |

> **굵게 표시된 화면**이 메인 탭바에 있는 핵심 화면입니다.

### 화면 이동 흐름

```
스플래시
  └─ 로그인 완료 → 홈
       ├─ 하단 탭: 홈 / 루틴 / 브리핑 / 커뮤니티 / 마이페이지
       ├─ 홈 → (경로 시작 버튼) → 실시간 경로 진행 화면
       ├─ 루틴 → 루틴 상세 → 루틴 수정
       └─ 마이페이지 → 계정관리 / 주소관리 / 알림설정 / 리포트
```

---

## 4. 현재 구현 상태 (Mock vs 실제)

> **중요**: 현재 모든 데이터는 앱 내에 하드코딩된 가짜 데이터(Mock)입니다.  
> 실제 서버와 연결되어 있지 않습니다.

### Mock 처리된 부분 (백엔드 연동 필요)

| 파일 | Mock 클래스 | 설명 |
|------|-------------|------|
| `data/repositories/home_repository.dart` | `MockHomeRepository` | 루틴, 날씨, 경로, 실시간 상태 |
| `data/repositories/routine_repository.dart` | `MockRoutineRepository` | 루틴 CRUD, 주소, 경로 검색 |
| `data/repositories/briefing_repository.dart` | — | 브리핑 데이터 |
| `data/repositories/community_repository.dart` | — | 게시글 목록/상세/작성 |

### 실제로 작동하는 부분

| 기능 | 설명 |
|------|------|
| 주소 검색 (카카오 우편번호) | WebView로 실제 카카오 API 호출 — 정상 작동 |
| 화면 전환 | GoRouter 기반 — 정상 작동 |
| 알림 설정 UI | 설정 저장은 메모리에만 — 앱 재시작 시 초기화됨 |

### 백엔드 연동 시 수정해야 할 포인트

1. `MockHomeRepository` → 실제 HTTP 구현체로 교체
2. `MockRoutineRepository` → 실제 HTTP 구현체로 교체
3. `data/services/token_storage.dart` — 실제 토큰 저장 로직 확인
4. `core/constants/api_constants.dart` — 서버 URL 설정

---

## 5. 자주 하는 작업 가이드

---

### 5-1. Claude Code 설치 및 사용 가이드

Claude Code는 AI가 직접 코드를 수정해 주는 도구입니다. 모르는 부분이 생기거나 수정이 필요할 때 가장 먼저 활용해 보세요.

#### 설치 방법

**방법 A — VS Code 확장 (권장)**
1. VS Code 실행
2. 왼쪽 확장 아이콘(네모 4개) 클릭
3. `Claude Code` 검색 후 설치
4. 설치 후 왼쪽 사이드바에 Claude 아이콘이 생깁니다

**방법 B — 데스크톱 앱**
- https://claude.ai/code 에서 다운로드

#### 시작하기

1. VS Code에서 `c:\dev\project-02-frontend` 폴더 열기
   - File → Open Folder → 해당 폴더 선택
2. 왼쪽 사이드바의 Claude 아이콘 클릭
3. 채팅창에 원하는 작업을 한국어로 입력

#### 기본 사용법

Claude Code에 요청할 때는 **어떤 화면인지 + 무엇을 변경하고 싶은지**를 함께 알려주세요.

**좋은 요청 예시:**
```
루틴 목록 화면에서 카드의 배경색을 흰색으로 바꿔줘

홈 화면 하단 버튼 텍스트를 "출발하기"에서 "시작하기"로 바꿔줘

알림 설정 화면에서 새로운 설정 항목을 추가하고 싶어. 
"도착 알림" 토글을 추가해줘.
```

**피해야 할 요청:**
```
코드 고쳐줘  (너무 막연함)
다 바꿔줘    (범위가 불명확)
```

#### 코드 수정 승인 방법

Claude Code가 코드를 수정할 때는 반드시 내용을 확인한 후 승인해야 합니다.

1. Claude가 수정 내용을 설명하면 내용 확인
2. **초록색 체크** 버튼 → 수정 허용
3. **빨간색 X** 버튼 → 수정 거부
4. 수정 후 빌드하여 실제로 정상 동작하는지 확인

#### 절대 하면 안 되는 것

> **백엔드 관련 파일은 절대 수정하지 마세요.**  
> Claude에게 요청할 때도 "백엔드는 건드리지 말고 프론트만 수정해줘"라고 명시해 주세요.

백엔드 관련 파일:
- `data/repositories/auth_repository.dart`
- `data/services/token_storage.dart`
- 서버 API 호출 관련 코드

#### 빌드 오류가 생겼을 때

```
빌드 오류가 생겼어. 아래 오류 메시지를 보고 고쳐줘:
[오류 메시지 붙여넣기]
```

---

### 5-2. 특정 화면의 텍스트/색상 변경

1. [화면별 파일 매핑 표](#3-화면별-파일-매핑)에서 해당 파일 찾기
2. VS Code에서 파일 열기 (`Ctrl+P` → 파일명 검색)
3. `Ctrl+F`로 텍스트를 검색하여 위치 확인
4. 직접 수정하거나 Claude Code에 요청

**색상 변경 위치:**  
`lib/core/theme/app_colors.dart`

```dart
static const primary = Color(0xFFFF6B2E);    // 주황색 (주요 버튼, 강조)
static const secondary = Color(0xFF00BDAA);  // 청록색 (AI, 보조 강조)
static const background = Color(0xFFFAFAFA); // 배경색
static const textSecondary = Color(0xFF616161); // 회색 텍스트
```

---

### 5-3. 새 화면 추가

새 화면을 추가할 때는 Claude Code에 맡기는 것이 가장 안전합니다. 아래와 같이 요청하세요.

```
마이페이지 아래에 "이용약관" 화면을 새로 추가해줘.
화면에는 약관 텍스트만 표시하면 돼.
마이페이지 목록에 메뉴 항목도 추가해줘.
```

직접 추가하려면:
1. `features/[기능]/screens/` 안에 `새화면_screen.dart` 파일 생성
2. `core/constants/route_constants.dart`에 경로 추가
3. `core/utils/router.dart`에 라우트 등록
4. 이동하고 싶은 화면에서 `context.push(RouteConstants.새경로)` 추가

---

### 5-4. 빌드하고 기기에 설치하기

```powershell
# 프로젝트 폴더로 이동
cd c:\dev\project-02-frontend\ruttu_app

# 기기 확인
flutter devices

# 빌드 및 설치
flutter run -d [기기ID] --release
```

오류 없이 설치되면 기기에서 앱이 자동으로 실행됩니다.

---

### 5-5. 오류 확인 방법

```powershell
# 코드 문법 오류 확인 (빌드 전에 먼저 실행)
flutter analyze
```

`No issues found!` 가 출력되면 정상입니다. 오류가 있을 경우 Claude Code에 오류 메시지를 전달하면 수정해 줍니다.

---

## 6. 알아두면 좋은 것들

### 상태 관리 — Riverpod Provider

화면에 데이터를 연결하는 방식입니다. 각 기능 폴더의 `providers/` 안에 있습니다.

```
home_provider.dart     ← 홈 화면의 데이터 (루틴 상태, 날씨 등)
routine_provider.dart  ← 루틴 목록/상세 데이터
briefing_provider.dart ← 브리핑 데이터
```

화면 파일에서 `ref.watch(홈Provider)` 형태로 데이터를 가져와 화면에 표시합니다.  
잘 모르는 부분이 있으면 Claude Code에 "이 데이터를 화면에 어떻게 연결하나요?"라고 질문해 보세요.

### 화면 이동 — GoRouter

화면 이동은 항상 아래 방식을 사용합니다.

```dart
// 다음 화면으로 이동 (뒤로 가기 가능)
context.push(RouteConstants.routineDetail.replaceFirst(':id', '$routineId'));

// 화면 교체 (뒤로 가기 불가)
context.go(RouteConstants.home);

// 뒤로 가기
context.pop();
```

모든 경로 이름은 `lib/core/constants/route_constants.dart`에 정의되어 있습니다.

### 홈 화면의 3가지 상태

홈 화면(`home_screen.dart`)은 상황에 따라 다른 화면을 표시합니다.

| 상태 | 설명 | 표시되는 위젯 |
|------|------|---------------|
| `noRoutine` | 등록된 루틴 없음 | `_NoRoutineView` |
| `preActive` | 루틴 있음, 출발 전 | `_PreActiveView` |
| `active` | 경로 진행 중 | `_ActiveView` |

### 테마 — 공통 스타일

버튼, 카드, 텍스트 필드의 기본 스타일은 `lib/core/theme/app_theme.dart`에서 관리합니다.  
개별 화면에서 직접 스타일을 지정하지 않아도 앱 스타일이 자동으로 적용됩니다.

### 주의: Mock 데이터 위치

현재 앱의 가짜 데이터(Mock)는 아래 두 파일에 있습니다.

- `data/repositories/home_repository.dart` → `MockHomeRepository` 클래스
- `data/repositories/routine_repository.dart` → `MockRoutineRepository` 클래스

화면에 표시되는 루틴 이름, 시간, 주소 등을 변경하고 싶으면 이 파일 안의 데이터를 수정하면 됩니다.

---

## 문의

작업 중 막히는 부분이 생기면:
1. **Claude Code**에 먼저 질문하세요 (가장 빠릅니다)
2. 오류 메시지가 있으면 메시지 전체를 복사하여 Claude에 붙여넣기
3. 어떤 화면에서 문제가 발생했는지 함께 알려주시면 더 정확하게 도와드릴 수 있습니다
