#!/usr/bin/env python3
import sys
import json

def parse_json(content):
    try:
        data = json.loads(content)
        if not isinstance(data, dict):
            print("오류: JSON 객체(dict)만 지원합니다.", file=sys.stderr)
            sys.exit(1)
        return data
    except json.JSONDecodeError as e:
        print(f"JSON 파싱 오류: {e}", file=sys.stderr)
        sys.exit(1)

def to_env(data):
    lines = []
    for key, value in data.items():
        # 값에 공백이나 특수문자가 있으면 따옴표로 감싸기
        if isinstance(value, str) and (' ' in value or '"' in value or "'" in value):
            value = f'"{value}"'
        lines.append(f"{key}={value}")
    return '\n'.join(lines)

if __name__ == '__main__':
    # 터미널에서 직접 실행할 때만 안내 메시지 출력
    if sys.stdin.isatty():
        print("=== JSON to .env 변환기 ===")
        print("JSON 내용을 붙여넣고 Ctrl+D (Mac/Linux) 또는 Ctrl+Z (Windows)로 종료하세요.")
        print("-" * 30)

    content = sys.stdin.read()

    if not content.strip():
        print("입력이 없습니다.", file=sys.stderr)
        sys.exit(1)

    data = parse_json(content)

    if sys.stdin.isatty():
        print("-" * 30)
        print("결과:")

    print(to_env(data))
